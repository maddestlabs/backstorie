## ================================================================
## Updated Animation Plugin - Uses New Architecture
## ================================================================
## This demonstrates how to properly structure a complex plugin
## with the new architecture. The old animation.nim should be
## updated to follow this pattern.

import plugin_interface
import std/[tables, math]

type
  AnimID* = string

  AnimState* = enum
    asRunning, asFinished

  AnimType* = enum
    atFadeIn, atSlide, atTypewriter

  EasingKind* = enum
    ekLinear, ekEaseInQuad, ekEaseOutQuad

  Animation* = ref object
    id*: AnimID
    animType*: AnimType
    layer*: LayerHandle
    duration*: float
    elapsed*: float
    state*: AnimState
    x*, y*: int
    text*: string
    baseStyle*: Style
    easing*: EasingKind
    speed*: float  # for slide

  AnimationPluginState = object
    ## Type-safe plugin state
    animations: Table[AnimID, Animation]

# ================================================================
# EASING HELPERS
# ================================================================

proc clamp01(x: float): float =
  if x < 0.0: 0.0
  elif x > 1.0: 1.0
  else: x

proc applyEasing(kind: EasingKind, t: float): float =
  let x = clamp01(t)
  case kind
  of ekLinear: x
  of ekEaseInQuad: x * x
  of ekEaseOutQuad: x * (2.0 - x)

proc dimStyle(s: Style, amt: float): Style =
  result = s
  result.fg.r = uint8(float(s.fg.r) * amt)
  result.fg.g = uint8(float(s.fg.g) * amt)
  result.fg.b = uint8(float(s.fg.b) * amt)

# ================================================================
# ANIMATION IMPLEMENTATIONS
# ================================================================

proc updateFadeIn(api: PluginAPI, a: Animation, dt: float) =
  a.elapsed += dt
  if a.duration <= 0.0:
    api.layerClearTransparent(a.layer)
    api.layerWriteText(a.layer, a.x, a.y, a.text, a.baseStyle)
    a.state = asFinished
    return

  let p = applyEasing(a.easing, clamp01(a.elapsed / a.duration))
  if p >= 1.0:
    a.state = asFinished

  api.layerClearTransparent(a.layer)
  let st = dimStyle(a.baseStyle, p)
  api.layerWriteText(a.layer, a.x, a.y, a.text, st)

proc updateSlide(api: PluginAPI, a: Animation, dt: float) =
  a.elapsed += dt
  if a.duration <= 0.0:
    api.layerClearTransparent(a.layer)
    api.layerWriteText(a.layer, a.x, a.y, a.text, a.baseStyle)
    a.state = asFinished
    return

  let p = applyEasing(a.easing, clamp01(a.elapsed / a.duration))
  let offset = int((1.0 - p) * a.speed)
  if p >= 1.0:
    a.state = asFinished

  api.layerClearTransparent(a.layer)
  api.layerWriteText(a.layer, a.x - offset, a.y, a.text, a.baseStyle)

proc updateTypewriter(api: PluginAPI, a: Animation, dt: float) =
  a.elapsed += dt
  let total = a.text.len
  let p = applyEasing(a.easing, clamp01(a.elapsed / a.duration))
  let charsToShow = min(total, int(p * float(total)))

  if charsToShow >= total:
    a.state = asFinished

  api.layerClearTransparent(a.layer)
  if charsToShow > 0:
    let visible = a.text[0 ..< charsToShow]
    api.layerWriteText(a.layer, a.x, a.y, visible, a.baseStyle)

proc updateAnimation(api: PluginAPI, a: Animation, dt: float) =
  if a.state == asFinished:
    api.layerClearTransparent(a.layer)
    return
  
  case a.animType
  of atFadeIn: updateFadeIn(api, a, dt)
  of atSlide: updateSlide(api, a, dt)
  of atTypewriter: updateTypewriter(api, a, dt)

# ================================================================
# PLUGIN IMPLEMENTATION
# ================================================================

proc createAnimationPluginV2*(): PluginModule =
  const pluginName = "animationV2"
  
  PluginModule(
    name: pluginName,
    version: "2.0.0",
    
    initProc: proc(api: PluginAPI) =
      let state = AnimationPluginState(
        animations: initTable[AnimID, Animation]()
      )
      setContext[AnimationPluginState](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      var ctx = getContext[AnimationPluginState](api, pluginName)
      
      # Update all animations
      var toRemove: seq[AnimID] = @[]
      for id, anim in ctx.data.animations:
        updateAnimation(api, anim, dt)
        if anim.state == asFinished:
          toRemove.add(id)
      
      # Remove finished animations
      for id in toRemove:
        ctx.data.animations.del(id)
    ,
    
    renderProc: proc(api: PluginAPI) =
      # Animations render to their own layers
      discard
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      false
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      let ctx = getContext[AnimationPluginState](api, pluginName)
      for id, anim in ctx.data.animations:
        api.removeLayer("anim_" & id)
  )

# ================================================================
# PUBLIC API FOR USERS
# ================================================================

proc addAnimationV2*(api: PluginAPI, anim: Animation) =
  ## Add an animation to the plugin
  const pluginName = "animationV2"
  var ctx = getContext[AnimationPluginState](api, pluginName)
  anim.state = asRunning
  ctx.data.animations[anim.id] = anim

proc newFadeInV2*(api: PluginAPI, id: AnimID, x, y: int, text: string,
                  style: Style, duration: float): Animation =
  let layer = api.addLayer("anim_" & id, 50)
  Animation(
    id: id,
    animType: atFadeIn,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: style,
    easing: ekLinear
  )

proc newSlideV2*(api: PluginAPI, id: AnimID, x, y: int, text: string,
                 style: Style, duration: float, distance: float): Animation =
  let layer = api.addLayer("anim_" & id, 50)
  Animation(
    id: id,
    animType: atSlide,
    layer: layer,
    duration: duration,
    elapsed: 0.0,
    state: asRunning,
    x: x, y: y,
    text: text,
    baseStyle: style,
    easing: ekEaseOutQuad,
    speed: distance
  )
