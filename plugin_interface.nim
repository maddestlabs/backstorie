## Plugin Interface for Backstorie
## This file defines ALL types shared between backstorie and plugins

type
  ## Input event types
  InputAction* = enum
    Press
    Release
    Repeat

  MouseButton* = enum
    Left
    Middle
    Right
    ScrollUp
    ScrollDown
    Unknown

  InputEventKind* = enum
    KeyEvent
    TextEvent
    MouseEvent
    MouseMoveEvent
    ResizeEvent

  ## Main input event type - used throughout the system
  InputEvent* = object
    case kind*: InputEventKind
    of KeyEvent:
      keyCode*: int
      keyMods*: set[uint8]
      keyAction*: InputAction
    of TextEvent:
      text*: string
    of MouseEvent:
      button*: MouseButton
      mouseX*: int
      mouseY*: int
      mods*: set[uint8]
      action*: InputAction
    of MouseMoveEvent:
      moveX*: int
      moveY*: int
      moveMods*: set[uint8]
    of ResizeEvent:
      newWidth*: int
      newHeight*: int

  ## Minimal AppState interface for plugins
  ## Plugins should only use what they need
  AppState* = object
    running*: bool
    termWidth*: int
    termHeight*: int
    frameCount*: int
    totalTime*: float

  ## Plugin module interface
  ## All plugins must conform to this shape
  PluginModule* = object
    name*: string
    initProc*: proc(state: var AppState) {.nimcall.}
    updateProc*: proc(state: var AppState, dt: float) {.nimcall.}
    renderProc*: proc(state: var AppState) {.nimcall.}
    handleEventProc*: proc(state: var AppState, event: InputEvent): bool {.nimcall.}
    shutdownProc*: proc(state: var AppState) {.nimcall.}

## Optional: Constants that plugins might use
const
  INPUT_ESCAPE* = 27
  INPUT_BACKSPACE* = 127
  INPUT_SPACE* = 32
  INPUT_TAB* = 9
  INPUT_ENTER* = 13
  INPUT_DELETE* = 46

  INPUT_UP* = 1000
  INPUT_DOWN* = 1001
  INPUT_LEFT* = 1002
  INPUT_RIGHT* = 1003

  INPUT_HOME* = 1004
  INPUT_END* = 1005
  INPUT_PAGE_UP* = 1006
  INPUT_PAGE_DOWN* = 1007

  INPUT_F1* = 1008
  INPUT_F2* = 1009
  INPUT_F3* = 1010
  INPUT_F4* = 1011
  INPUT_F5* = 1012
  INPUT_F6* = 1013
  INPUT_F7* = 1014
  INPUT_F8* = 1015
  INPUT_F9* = 1016
  INPUT_F10* = 1017
  INPUT_F11* = 1018
  INPUT_F12* = 1019

## Modifier constants
const
  ModShift* = 0'u8
  ModAlt* = 1'u8
  ModCtrl* = 2'u8
  ModSuper* = 3'u8