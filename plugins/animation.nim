# ================================================================
# Backstorie Animation Engine (animation.nim)
# - Easing
# - Chaining
# - Layer-based effects
# ================================================================

import std/[math, tables]
import ../backstorie

type
  AnimID* = string

  AnimState* = enum
    asRunning, asFinished

  AnimType* = enum
    atTypewriter,
    atSlide,
    atFadeIn,
    atFadeOut,
    atWave,
    atRainbow,
    atSprite

  EasingKind* = enum
    ekLinear,
    ekEaseInQuad,
    ekEaseOutQuad,
    ekEaseInOutQuad,
    ekEaseInSine,
    ekEaseOutSine,
    ekEaseInOutSine

  BackstorieAnimation* = ref object
    id*: AnimID
    animType*: AnimType
    layer*: Layer          # target layer to render into
    duration*: float       # effect duration (seconds)
    elapsed*: float        # time since start
    state*: AnimState

    x*, y*: int            # anchor position
    text*: string          # for text-based effects

    spriteFrames*: seq[TermBuffer]  # sprite frames for atSprite
    frameIndex*: int
    speed*: float          # meaning depends on anim type (e.g. slide distance or sprite FPS)
    amplitude*: float      # wave amplitude (for atWave)
    colorOffset*: float    # rainbow phase offset

    baseStyle*: Style      # base style for text
    easing*: EasingKind    # easing mode

    active*: bool          # is currently being updated
    ownedByChain*: string  # chain ID if part of a chain, "" if standalone

  ChainState* = enum
    csRunning,
    csFinished

  AnimationChain* = ref object
    id*: string
    stepIds*: seq[AnimID]  # ordered list of animation ids
    currentIndex*: int
    loop*: bool
    state*: ChainState

  AnimationPluginState* = ref object
    animations*: Table[AnimID, BackstorieAnimation]
    chains*: Table[string, AnimationChain]

# ================================================================
# EASING HELPERS
# ================================================================

proc clamp01(x: float): float =
  if x < 0.0: 0.0
  elif x > 1.0: 1.0
  else: x

proc applyEasing*(kind: EasingKind, t: float): float =
  ## Apply easing to normalized t in [0,1].
  let x = clamp01(t)
  case kind
  of ekLinear:
    x
  of ekEaseInQuad:
    x * x
  of ekEaseOutQuad:
    x * (2.0 - x)
  of ekEaseInOutQuad:
    if x < 0.5:
      2.0 * x * x
    else:
      -1.0 + (4.0 - 2.0 * x) * x
  of ekEaseInSine:
    1.0 - cos((x * PI) / 2.0)
  of ekEaseOutSine:
    sin((x * PI) / 2.0)
  of ekEaseInOutSine:
    -(cos(PI * x) - 1.0) / 2.0

proc dimStyle(s: Style, amt: float): Style =
  ## Fade effect by modulating color brightness
  result = s
  # Modulate foreground color brightness based on fade amount
  result.fg.r = uint8(float(s.fg.r) * amt)
  result.fg.g = uint8(float(s.fg.g) * amt)
  result.fg.b = uint8(float(s.fg.b) * amt)

proc rainbowColor(t: float): Color =
  ## Produces a cycling rainbow color
  let r = sin(t) * 0.5 + 0.5
  let g = sin(t + 2.0944) * 0.5 + 0.5 # +120 degrees
  let b = sin(t + 4.1888) * 0.5 + 0.5 # +240 degrees
  rgb(uint8(int(r * 255)), uint8(int(g * 255)), uint8(int(b * 255)))

# ================================================================
# ANIMATION IMPLEMENTATIONS
# ================================================================

# -- Typewriter ---------------------------------------------------

proc animTypewriter(a: BackstorieAnimation; dt: float) =
  if a.layer == nil:
    a.state = asFinished
    return
    
  if a.duration <= 0.0:
    # Edge case: instantly show everything
    a.layer.buffer.clearTransparent()
    a.layer.buffer.writeText(a.x, a.y, a.text, a.baseStyle)
    a.state = asFinished
    return

  a.elapsed += dt
  let total = a.text.len
  let pNorm = clamp01(a.elapsed / a.duration)
  let p = applyEasing(a.easing, pNorm)
  let charsToShow = min(total, int(floor(p * float(total))))

  if charsToShow >= total:
    a.state = asFinished

  a.layer.buffer.clearTransparent()
  if charsToShow > 0:
    let visible = a.text[0 ..< charsToShow]
    a.layer.buffer.writeText(a.x, a.y, visible, a.baseStyle)

# -- Slide --------------------------------------------------------

proc animSlide(a: BackstorieAnimation; dt: float) =
  ## Slide text in from the left by 'speed' columns over 'duration'.
  if a.layer == nil:
    a.state = asFinished
    return
    
  a.elapsed += dt
  if a.duration <= 0.0:
    a.layer.buffer.clearTransparent()
    a.layer.buffer.writeText(a.x, a.y, a.text, a.baseStyle)
    a.state = asFinished
    return

  let pNorm = clamp01(a.elapsed / a.duration)
  let p = applyEasing(a.easing, pNorm)
  let offset = int(round((1.0 - p) * a.speed))

  if p >= 1.0:
    a.state = asFinished

  a.layer.buffer.clearTransparent()
  a.layer.buffer.writeText(a.x - offset, a.y, a.text, a.baseStyle)

# -- Fade In / Fade Out ------------------------------------------

proc animFadeIn(a: BackstorieAnimation; dt: float) =
  if a.layer == nil:
    a.state = asFinished
    return
    
  a.elapsed += dt
  if a.duration <= 0.0:
    a.layer.buffer.clearTransparent()
    a.layer.buffer.writeText(a.x, a.y, a.text, a.baseStyle)
    a.state = asFinished
    return

  let pNorm = clamp01(a.elapsed / a.duration)
  let p = applyEasing(a.easing, pNorm)
  if p >= 1.0:
    a.state = asFinished

  a.layer.buffer.clearTransparent()
  let st = dimStyle(a.baseStyle, p)
  a.layer.buffer.writeText(a.x, a.y, a.text, st)

proc animFadeOut(a: BackstorieAnimation; dt: float) =
  if a.layer == nil:
    a.state = asFinished
    return
    
  a.elapsed += dt
  if a.duration <= 0.0:
    # Immediately disappear
    a.layer.buffer.clearTransparent()
    a.state = asFinished
    return

  let pNorm = clamp01(a.elapsed / a.duration)
  let p = applyEasing(a.easing, pNorm)
  let inv = 1.0 - p
  if inv <= 0.0:
    a.state = asFinished

  a.layer.buffer.clearTransparent()
  let st = dimStyle(a.baseStyle, inv)
  a.layer.buffer.writeText(a.x, a.y, a.text, st)

# -- Wave --------------------------------------------------------

proc animWave(a: BackstorieAnimation; dt: float) =
  if a.layer == nil:
    a.state = asFinished
    return
    
  a.elapsed += dt
  a.layer.buffer.clearTransparent()

  let chars = a.text
  for i in 0 ..< chars.len:
    let ch = chars[i]
    let dy = int(sin((a.elapsed * a.speed) + (float(i) * 0.4)) * a.amplitude)
    a.layer.buffer.writeText(a.x + i, a.y + dy, $ch, a.baseStyle)

# -- Rainbow -----------------------------------------------------

proc animRainbow(a: BackstorieAnimation; dt: float) =
  if a.layer == nil:
    a.state = asFinished
    return
    
  a.elapsed += dt
  a.layer.buffer.clearTransparent()

  let chars = a.text
  for i in 0 ..< chars.len:
    let ch = chars[i]
    let color = rainbowColor(a.elapsed * a.colorOffset + float(i) * 0.3)
    let st = Style(fg: color, bg: a.baseStyle.bg, bold: a.baseStyle.bold,
                   underline: a.baseStyle.underline, italic: a.baseStyle.italic,
                   dim: a.baseStyle.dim)
    a.layer.buffer.writeText(a.x + i, a.y, $ch, st)

# -- Sprite ------------------------------------------------------

proc animSprite(a: BackstorieAnimation; dt: float) =
  if a.layer == nil or a.spriteFrames.len == 0:
    a.state = asFinished
    return

  a.elapsed += dt
  if a.speed <= 0.0:
    a.speed = 0.1

  if a.elapsed >= a.speed:
    a.elapsed = 0.0
    a.frameIndex = (a.frameIndex + 1) mod a.spriteFrames.len

  a.layer.buffer.clearTransparent()
  compositeBufferOnto(a.layer.buffer, a.spriteFrames[a.frameIndex])

# ================================================================
# UPDATE A SINGLE ANIMATION
# ================================================================

proc updateAnimation*(a: BackstorieAnimation; dt: float) =
  if a.state == asFinished:
    # Clear the layer when animation finishes
    if a.layer != nil:
      a.layer.buffer.clearTransparent()
    return
  case a.animType
  of atTypewriter: animTypewriter(a, dt)
  of atSlide:      animSlide(a, dt)
  of atFadeIn:     animFadeIn(a, dt)
  of atFadeOut:    animFadeOut(a, dt)
  of atWave:       animWave(a, dt)
  of atRainbow:    animRainbow(a, dt)
  of atSprite:     animSprite(a, dt)

# ================================================================
# PLUGIN: animation manager
# ================================================================

var globalAnimState*: AnimationPluginState = nil

proc ensureAnimState(state: var AppState): AnimationPluginState =
  if globalAnimState == nil:
    globalAnimState = AnimationPluginState(
      animations: initTable[AnimID, BackstorieAnimation](),
      chains: initTable[string, AnimationChain]()
    )
    state.pluginData["animation"] = cast[pointer](globalAnimState)
  result = globalAnimState

proc createAnimationPlugin*(): PluginModule =
  result.name = "animation"
  result.initProc = proc (state: var AppState) =
    discard ensureAnimState(state)

  result.updateProc = proc (state: var AppState, dt: float) =
    let ps = ensureAnimState(state)

    # 1. Advance chains FIRST so all animations are in the right state
    var finishedChains: seq[string] = @[]
    for cid, chain in ps.chains:
      if chain.state == csFinished:
        finishedChains.add(cid)
        continue
      if chain.stepIds.len == 0:
        chain.state = csFinished
        finishedChains.add(cid)
        continue

      let curId = chain.stepIds[chain.currentIndex]
      if not ps.animations.hasKey(curId):
        chain.state = csFinished
        finishedChains.add(cid)
        continue

      let anim = ps.animations[curId]
      if anim.state == asFinished:
        anim.active = false
        # Clear the layer of the finished animation
        if anim.layer != nil:
          anim.layer.buffer.clearTransparent()
        
        if chain.currentIndex + 1 < chain.stepIds.len:
          inc chain.currentIndex
          let nextId = chain.stepIds[chain.currentIndex]
          if ps.animations.hasKey(nextId):
            let nextAnim = ps.animations[nextId]
            nextAnim.elapsed = 0.0
            nextAnim.state = asRunning
            nextAnim.active = true
        else:
          if chain.loop and chain.stepIds.len > 0:
            chain.currentIndex = 0
            let firstId = chain.stepIds[0]
            if ps.animations.hasKey(firstId):
              let firstAnim = ps.animations[firstId]
              firstAnim.elapsed = 0.0
              firstAnim.state = asRunning
              firstAnim.active = true
              if firstAnim.layer != nil:
                firstAnim.layer.buffer.clearTransparent()
          else:
            chain.state = csFinished
            finishedChains.add(cid)

    for cid in finishedChains:
      ps.chains.del(cid)

    # 2. Now update all active animations
    var toRemove: seq[AnimID] = @[]
    for id, anim in ps.animations:
      if anim.active and anim.state == asRunning:
        anim.updateAnimation(dt)
      if anim.state == asFinished and anim.ownedByChain.len == 0:
        # standalone animations can be removed automatically
        toRemove.add(id)
    for id in toRemove:
      ps.animations.del(id)

  result.renderProc = proc (state: var AppState) =
    # Animations draw into their layers; no extra render step here
    discard

  result.handleEventProc = proc (state: var AppState, event: InputEvent): bool {.nimcall.} =
    # Reserved for future interactive effects
    false

  result.shutdownProc = proc (state: var AppState) =
    if state.pluginData.hasKey("animation"):
      let ps = cast[AnimationPluginState](state.pluginData["animation"])
      ps.animations.clear()
      ps.chains.clear()

# ================================================================
# PUBLIC API: adding animations & chains
# ================================================================

proc addAnimation*(state: var AppState, anim: BackstorieAnimation) =
  let ps = ensureAnimState(state)
  anim.state = asRunning
  anim.active = true
  ps.animations[anim.id] = anim

proc createChain*(state: var AppState, id: string,
                  anims: seq[BackstorieAnimation],
                  loop = false) =
  let ps = ensureAnimState(state)
  var chain = AnimationChain(
    id: id,
    stepIds: @[],
    currentIndex: 0,
    loop: loop,
    state: csRunning
  )

  for i, anim in anims:
    anim.ownedByChain = id
    anim.state = asRunning
    anim.elapsed = 0.0
    if i == 0:
      anim.active = true  # First animation starts immediately
    else:
      anim.active = false  # Others wait
    ps.animations[anim.id] = anim
    chain.stepIds.add(anim.id)

  ps.chains[id] = chain

# ================================================================
# CONSTRUCTORS FOR COMMON ANIMATIONS (with easing)
# ================================================================

proc newTypewriter*(id: AnimID, layer: Layer,
                    x, y: int, text: string,
                    baseStyle: Style,
                    duration: float,
                    easing: EasingKind = ekLinear): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atTypewriter,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: baseStyle,
    easing: easing,
    active: false,
    ownedByChain: ""
  )

proc newSlideIn*(id: AnimID, layer: Layer,
                 x, y: int, text: string,
                 baseStyle: Style,
                 duration: float,
                 distance: float,
                 easing: EasingKind = ekEaseOutQuad): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atSlide,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: baseStyle,
    speed: distance,
    easing: easing,
    active: false,
    ownedByChain: ""
  )

proc newFadeIn*(id: AnimID, layer: Layer,
                x, y: int, text: string,
                baseStyle: Style,
                duration: float,
                easing: EasingKind = ekEaseInSine): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atFadeIn,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: baseStyle,
    easing: easing,
    active: false,
    ownedByChain: ""
  )

proc newFadeOut*(id: AnimID, layer: Layer,
                 x, y: int, text: string,
                 baseStyle: Style,
                 duration: float,
                 easing: EasingKind = ekEaseOutSine): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atFadeOut,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: baseStyle,
    easing: easing,
    active: false,
    ownedByChain: ""
  )

proc newWave*(id: AnimID, layer: Layer,
              x, y: int, text: string,
              baseStyle: Style,
              speed: float = 4.0,
              amplitude: float = 1.0,
              duration: float = 9999.0): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atWave,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: baseStyle,
    speed: speed,
    amplitude: amplitude,
    easing: ekLinear,
    active: false,
    ownedByChain: ""
  )

proc newRainbow*(id: AnimID, layer: Layer,
                 x, y: int, text: string,
                 baseStyle: Style,
                 colorOffset: float = 2.0,
                 duration: float = 9999.0): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atRainbow,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: baseStyle,
    colorOffset: colorOffset,
    easing: ekLinear,
    active: false,
    ownedByChain: ""
  )

proc newSprite*(id: AnimID, layer: Layer,
                frames: seq[TermBuffer],
                frameTime: float = 0.1): BackstorieAnimation =
  BackstorieAnimation(
    id: id,
    animType: atSprite,
    layer: layer,
    duration: 9999.0,
    elapsed: 0.0,
    state: asRunning,
    spriteFrames: frames,
    frameIndex: 0,
    speed: frameTime,
    baseStyle: Style(fg: white(), bg: black()),
    easing: ekLinear,
    active: false,
    ownedByChain: ""
  )