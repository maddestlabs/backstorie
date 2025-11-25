# Terminal Event Handler Plugin
## Robust event handling for backstorie terminal engine
## Covers all InputEvent types with flexible callback support

import std/[tables, sets, sequtils, hashes, strformat, times]
import ../plugin_interface

# ================================================================
# EVENT HANDLER CONFIGURATION AND STATE
# ================================================================

type
  EventHandlerConfig* = object
    ## Configuration for event handler behavior
    consumeEvents*: bool  ## Whether handled events prevent other handlers
    enableLogging*: bool  ## Debug logging of all events
    enableRepeatTracking*: bool  ## Track key repeat state
    enableMouseTracking*: bool  ## Enable mouse event processing
    enableResizeTracking*: bool  ## Enable resize event processing
    maxCallbackDepth*: int  ## Prevent callback recursion issues

  KeyState* = object
    ## Track key press/release state
    code*: int
    mods*: set[uint8]
    isPressed*: bool
    repeatCount*: int
    lastEventTime*: float

  MouseState* = object
    ## Track mouse position and button state
    x*, y*: int
    leftPressed*: bool
    middlePressed*: bool
    rightPressed*: bool
    lastX*, lastY*: int
    dragStartX*, dragStartY*: int
    isDragging*: bool

  TerminalEventHandler* = ref object
    ## Main event handler with flexible callback system
    config*: EventHandlerConfig
    
    # Callbacks
    onText*: proc(text: string): bool {.nimcall.}
    onKey*: proc(code: int, mods: set[uint8], action: InputAction): bool {.nimcall.}
    onKeyDown*: proc(code: int, mods: set[uint8]): bool {.nimcall.}
    onKeyUp*: proc(code: int, mods: set[uint8]): bool {.nimcall.}
    onKeyRepeat*: proc(code: int, mods: set[uint8], count: int): bool {.nimcall.}
    
    onMouse*: proc(button: MouseButton, x, y: int, action: InputAction, mods: set[uint8]): bool {.nimcall.}
    onMouseDown*: proc(button: MouseButton, x, y: int, mods: set[uint8]): bool {.nimcall.}
    onMouseUp*: proc(button: MouseButton, x, y: int, mods: set[uint8]): bool {.nimcall.}
    onMouseMove*: proc(x, y: int, mods: set[uint8]): bool {.nimcall.}
    onMouseDrag*: proc(button: MouseButton, x, y: int, mods: set[uint8]): bool {.nimcall.}
    onMouseScroll*: proc(delta: int, x, y: int, mods: set[uint8]): bool {.nimcall.}
    
    onResize*: proc(w, h: int): bool {.nimcall.}
    
    # Internal state tracking
    keyStates*: Table[int, KeyState]
    mouseState*: MouseState
    lastEventTime*: float
    callbackDepth*: int
    
    # Filter support
    capturedKeys*: HashSet[int]  ## Keys that trigger handlers even in text context
    ignoreKeys*: HashSet[int]    ## Keys that are completely ignored
    
    # Statistics
    eventCount*: int
    droppedEvents*: int

var globalHandler* {.threadvar.}: TerminalEventHandler

# ================================================================
# FORWARD DECLARATIONS
# ================================================================
# Forward declarations for helper functions used in other procs
proc isIgnored*(handler: TerminalEventHandler, code: int): bool
proc isCaptured*(handler: TerminalEventHandler, code: int): bool

# ================================================================
# CONSTRUCTOR AND UTILITY FUNCTIONS
# ================================================================

proc newTerminalEventHandler*(config: EventHandlerConfig = EventHandlerConfig()): TerminalEventHandler =
  result = TerminalEventHandler()
  result.config = config
  result.config.maxCallbackDepth = max(1, config.maxCallbackDepth)
  result.mouseState = MouseState()
  result.keyStates = initTable[int, KeyState]()
  result.capturedKeys = initHashSet[int]()
  result.ignoreKeys = initHashSet[int]()
  result.eventCount = 0
  result.droppedEvents = 0

proc debugLog*(handler: TerminalEventHandler, msg: string) =
  if handler.config.enableLogging:
    stderr.writeLine("[EventHandler] " & msg)

proc shouldConsume*(handler: TerminalEventHandler, handled: bool): bool =
  result = handled and handler.config.consumeEvents

# ================================================================
# KEY STATE MANAGEMENT
# ================================================================

proc updateKeyState*(handler: TerminalEventHandler, code: int, mods: set[uint8], action: InputAction, time: float) =
  if not handler.config.enableRepeatTracking:
    return
  
  var state = handler.keyStates.getOrDefault(code, KeyState(code: code, isPressed: false, repeatCount: 0))
  state.mods = mods
  state.lastEventTime = time
  
  case action
  of Press:
    state.isPressed = true
    state.repeatCount = 0
  of Repeat:
    if state.isPressed:
      inc state.repeatCount
  of Release:
    state.isPressed = false
    state.repeatCount = 0
  
  handler.keyStates[code] = state

# ================================================================
# EVENT HANDLERS
# ================================================================

proc handleText*(handler: TerminalEventHandler, text: string): bool =
  handler.debugLog("Text: " & text)
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  inc handler.callbackDepth
  defer: dec handler.callbackDepth
  
  result = false
  if not handler.onText.isNil:
    result = handler.onText(text)

proc handleKey*(handler: TerminalEventHandler, code: int, mods: set[uint8], action: InputAction): bool =
  # Check filters
  if handler.isIgnored(code):
    return false
  
  handler.debugLog(&"Key: code={code}, mods={mods}, action={action}")
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  inc handler.callbackDepth
  defer: dec handler.callbackDepth
  
  handler.updateKeyState(code, mods, action, handler.lastEventTime)
  
  result = false
  
  # Call general key handler first
  if not handler.onKey.isNil:
    result = handler.onKey(code, mods, action) or result
  
  # Call action-specific handlers
  case action
  of Press:
    if not handler.onKeyDown.isNil:
      result = handler.onKeyDown(code, mods) or result
  of Release:
    if not handler.onKeyUp.isNil:
      result = handler.onKeyUp(code, mods) or result
  of Repeat:
    if handler.config.enableRepeatTracking and not handler.onKeyRepeat.isNil:
      let state = handler.keyStates.getOrDefault(code, KeyState())
      result = handler.onKeyRepeat(code, mods, state.repeatCount) or result

proc handleMouse*(handler: TerminalEventHandler, button: MouseButton, x, y: int, action: InputAction, mods: set[uint8]): bool =
  if not handler.config.enableMouseTracking:
    return false
  
  handler.debugLog(&"Mouse: button={button}, pos=({x},{y}), action={action}, mods={mods}")
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  inc handler.callbackDepth
  defer: dec handler.callbackDepth
  
  handler.mouseState.x = x
  handler.mouseState.y = y
  
  result = false
  
  # Call general mouse handler
  if not handler.onMouse.isNil:
    result = handler.onMouse(button, x, y, action, mods) or result
  
  # Track button state
  case action
  of Press:
    case button
    of Left: handler.mouseState.leftPressed = true
    of Middle: handler.mouseState.middlePressed = true
    of Right: handler.mouseState.rightPressed = true
    else: discard
    
    handler.mouseState.dragStartX = x
    handler.mouseState.dragStartY = y
    
    if not handler.onMouseDown.isNil:
      result = handler.onMouseDown(button, x, y, mods) or result
  
  of Release:
    case button
    of Left: handler.mouseState.leftPressed = false
    of Middle: handler.mouseState.middlePressed = false
    of Right: handler.mouseState.rightPressed = false
    else: discard
    
    handler.mouseState.isDragging = false
    
    if not handler.onMouseUp.isNil:
      result = handler.onMouseUp(button, x, y, mods) or result
  
  of Repeat:
    discard  # Mouse doesn't typically repeat

proc handleMouseMove*(handler: TerminalEventHandler, x, y: int, mods: set[uint8]): bool =
  if not handler.config.enableMouseTracking:
    return false
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  # Detect drag
  let isDragCandidate = (handler.mouseState.leftPressed or 
                         handler.mouseState.middlePressed or 
                         handler.mouseState.rightPressed)
  
  if isDragCandidate and (x != handler.mouseState.x or y != handler.mouseState.y):
    handler.mouseState.isDragging = true
  
  handler.mouseState.lastX = handler.mouseState.x
  handler.mouseState.lastY = handler.mouseState.y
  handler.mouseState.x = x
  handler.mouseState.y = y
  
  result = false
  
  if handler.mouseState.isDragging:
    let dragButton = if handler.mouseState.leftPressed: MouseButton.Left
                     elif handler.mouseState.middlePressed: MouseButton.Middle
                     elif handler.mouseState.rightPressed: MouseButton.Right
                     else: MouseButton.Unknown
    
    if not handler.onMouseDrag.isNil:
      result = handler.onMouseDrag(dragButton, x, y, mods)
  else:
    if not handler.onMouseMove.isNil:
      result = handler.onMouseMove(x, y, mods)
  
  if result:
    handler.debugLog(&"MouseMove: pos=({x},{y}), drag={handler.mouseState.isDragging}")

proc handleScroll*(handler: TerminalEventHandler, delta: int, x, y: int, mods: set[uint8]): bool =
  if not handler.config.enableMouseTracking:
    return false
  
  handler.debugLog(&"Scroll: delta={delta}, pos=({x},{y})")
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  inc handler.callbackDepth
  defer: dec handler.callbackDepth
  
  result = false
  if not handler.onMouseScroll.isNil:
    result = handler.onMouseScroll(delta, x, y, mods)

proc handleResize*(handler: TerminalEventHandler, w, h: int): bool =
  if not handler.config.enableResizeTracking:
    return false
  
  handler.debugLog(&"Resize: {w}x{h}")
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  inc handler.callbackDepth
  defer: dec handler.callbackDepth
  
  result = false
  if not handler.onResize.isNil:
    result = handler.onResize(w, h)

proc handleMouseDrag*(handler: TerminalEventHandler, button: MouseButton, x, y: int, mods: set[uint8]): bool =
  handler.debugLog(&"MouseDrag: button={button}, pos=({x},{y})")
  
  if handler.callbackDepth >= handler.config.maxCallbackDepth:
    inc handler.droppedEvents
    return false
  
  inc handler.callbackDepth
  defer: dec handler.callbackDepth
  
  result = false
  if not handler.onMouseDrag.isNil:
    result = handler.onMouseDrag(button, x, y, mods)

# ================================================================
# MAIN EVENT DISPATCHER
# ================================================================

proc dispatchEvent*(handler: TerminalEventHandler, event: InputEvent): bool =
  ## Main event dispatcher - routes to appropriate handlers
  inc handler.eventCount
  handler.lastEventTime = epochTime()
  
  case event.kind
  of TextEvent:
    return handler.handleText(event.text)
  
  of KeyEvent:
    return handler.handleKey(event.keyCode, event.keyMods, event.keyAction)
  
  of MouseEvent:
    return handler.handleMouse(event.button, event.mouseX, event.mouseY, event.action, event.mods)
  
  of MouseMoveEvent:
    return handler.handleMouseMove(event.moveX, event.moveY, event.moveMods)
  
  of ResizeEvent:
    return handler.handleResize(event.newWidth, event.newHeight)

# ================================================================
# PLUGIN INTEGRATION
# ================================================================

proc createEventHandlerPlugin*(handler: TerminalEventHandler): PluginModule =
  ## Create a plugin module that integrates the event handler with backstorie
  
  globalHandler = handler
  
  PluginModule(
    name: "terminalEventHandler",
    
    initProc: proc(state: var AppState) {.nimcall.} =
      globalHandler.debugLog("Event handler initialized"),
    
    updateProc: proc(state: var AppState, dt: float) {.nimcall.} =
      # Update could track key repeat timeouts, double-click detection, etc.
      discard,
    
    renderProc: proc(state: var AppState) {.nimcall.} =
      discard,
    
    handleEventProc: proc(state: var AppState, event: InputEvent): bool {.nimcall.} =
      return dispatchEvent(globalHandler, event),
    
    shutdownProc: proc(state: var AppState) {.nimcall.} =
      globalHandler.debugLog("Event handler shutdown")
  )

# ================================================================
# CONVENIENCE HELPERS
# ================================================================

proc captureKey*(handler: TerminalEventHandler, code: int) =
  ## Mark a key as "captured" - will trigger even during text input
  handler.capturedKeys.incl code

proc ignoreKey*(handler: TerminalEventHandler, code: int) =
  ## Ignore a specific key code completely
  handler.ignoreKeys.incl code

proc isCaptured*(handler: TerminalEventHandler, code: int): bool =
  ## Check if a key is captured
  code in handler.capturedKeys

proc isIgnored*(handler: TerminalEventHandler, code: int): bool =
  ## Check if a key is ignored
  code in handler.ignoreKeys

proc isKeyPressed*(handler: TerminalEventHandler, code: int): bool =
  let state = handler.keyStates.getOrDefault(code, KeyState())
  result = state.isPressed

proc getMouseX*(handler: TerminalEventHandler): int = handler.mouseState.x
proc getMouseY*(handler: TerminalEventHandler): int = handler.mouseState.y
proc isMouseDragging*(handler: TerminalEventHandler): bool = handler.mouseState.isDragging

proc resetState*(handler: TerminalEventHandler) =
  ## Reset all tracked state (useful on focus loss or explicit reset)
  handler.keyStates.clear()
  handler.mouseState = MouseState()
  handler.callbackDepth = 0

proc getStats*(handler: TerminalEventHandler): tuple[events: int, dropped: int] =
  result = (handler.eventCount, handler.droppedEvents)

proc resetStats*(handler: TerminalEventHandler) =
  handler.eventCount = 0
  handler.droppedEvents = 0