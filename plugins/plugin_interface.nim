## ================================================================
## Backstorie Plugin Interface
## ================================================================
## This file defines ALL types and APIs shared between the core
## engine and plugins. NO IMPLEMENTATION should be in this file.
##
## Plugins should ONLY import this file, never backstorie.nim
## This eliminates circular dependencies completely.
## ================================================================

import tables

# ================================================================
# INPUT CONSTANTS
# ================================================================

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

const
  ModShift* = 0'u8
  ModAlt* = 1'u8
  ModCtrl* = 2'u8
  ModSuper* = 3'u8

# ================================================================
# INPUT EVENT TYPES
# ================================================================

type
  InputAction* = enum
    Press
    Release
    Repeat

  MouseButton* = enum
    Left
    Middle
    Right
    Unknown
    ScrollUp
    ScrollDown

  InputEventKind* = enum
    KeyEvent
    TextEvent
    MouseEvent
    MouseMoveEvent
    ResizeEvent

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

# ================================================================
# COLOR AND STYLE SYSTEM
# ================================================================

type
  Color* = object
    r*, g*, b*: uint8

  Style* = object
    fg*: Color
    bg*: Color
    bold*: bool
    underline*: bool
    italic*: bool
    dim*: bool

# Color constructor helpers
proc rgb*(r, g, b: uint8): Color =
  Color(r: r, g: g, b: b)

proc gray*(level: uint8): Color =
  rgb(level, level, level)

proc black*(): Color = rgb(0, 0, 0)
proc red*(): Color = rgb(255, 0, 0)
proc green*(): Color = rgb(0, 255, 0)
proc yellow*(): Color = rgb(255, 255, 0)
proc blue*(): Color = rgb(0, 0, 255)
proc magenta*(): Color = rgb(255, 0, 255)
proc cyan*(): Color = rgb(0, 255, 255)
proc white*(): Color = rgb(255, 255, 255)

proc defaultStyle*(): Style =
  Style(fg: white(), bg: black(), bold: false, underline: false, italic: false, dim: false)

# ================================================================
# LAYER SYSTEM (OPAQUE HANDLE)
# ================================================================

type
  LayerHandle* = distinct int
    ## Opaque handle to a layer - plugins don't need internal details

# ================================================================
# PLUGIN CONTEXT (TYPE-SAFE STATE STORAGE)
# ================================================================

type
  PluginContextBase* = ref object of RootObj
    ## Base type for all plugin contexts (enables polymorphic storage)
    pluginName*: string
  
  PluginContext*[T] = ref object of PluginContextBase
    ## Type-safe plugin state storage
    ## Each plugin gets its own typed context
    data*: T

# ================================================================
# PLUGIN API
# ================================================================
## This is the interface that plugins use to interact with the engine.
## All operations are done through this API, not by directly accessing
## engine internals. This provides encapsulation and future flexibility.

type
  PluginAPI* = object
    ## Complete API surface for plugins
    
    # === LAYER MANAGEMENT ===
    addLayer*: proc(id: string, z: int): LayerHandle
    getLayer*: proc(id: string): LayerHandle
    removeLayer*: proc(id: string)
    setLayerVisible*: proc(layer: LayerHandle, visible: bool)
    
    # === DRAWING TO LAYER ===
    layerWrite*: proc(layer: LayerHandle, x, y: int, ch: string, style: Style)
    layerWriteText*: proc(layer: LayerHandle, x, y: int, text: string, style: Style)
    layerFillRect*: proc(layer: LayerHandle, x, y, w, h: int, ch: string, style: Style)
    layerClear*: proc(layer: LayerHandle)
    layerClearTransparent*: proc(layer: LayerHandle)
    layerSetClip*: proc(layer: LayerHandle, x, y, w, h: int)
    layerClearClip*: proc(layer: LayerHandle)
    layerSetOffset*: proc(layer: LayerHandle, x, y: int)
    
    # === DRAWING TO CURRENT BUFFER (direct) ===
    write*: proc(x, y: int, ch: string, style: Style)
    writeText*: proc(x, y: int, text: string, style: Style)
    fillRect*: proc(x, y, w, h: int, ch: string, style: Style)
    
    # === STATE QUERIES ===
    getTermSize*: proc(): (int, int)
    getFrameCount*: proc(): int
    getTotalTime*: proc(): float
    getFPS*: proc(): float
    isRunning*: proc(): bool
    requestShutdown*: proc()
    
    # === PLUGIN DATA STORAGE (type-safe) ===
    ## Store and retrieve plugin-specific state in a type-safe manner
    getPluginData*: proc(name: string): PluginContextBase
    setPluginData*: proc(name: string, data: PluginContextBase)

# Helper procs for typed plugin contexts
proc getContext*[T](api: PluginAPI, pluginName: string): PluginContext[T] =
  ## Retrieve typed plugin context
  let base = api.getPluginData(pluginName)
  if base.isNil:
    result = PluginContext[T](pluginName: pluginName, data: default(T))
    api.setPluginData(pluginName, result)
  else:
    result = PluginContext[T](base)

proc setContext*[T](api: PluginAPI, pluginName: string, data: T) =
  ## Store typed plugin context
  let ctx = PluginContext[T](pluginName: pluginName, data: data)
  api.setPluginData(pluginName, ctx)

# ================================================================
# PLUGIN MODULE DEFINITION
# ================================================================

type
  PluginModule* = object
    ## A plugin module that can be registered with the engine
    name*: string
    version*: string
    
    ## Lifecycle callbacks - all optional (can be nil)
    initProc*: proc(api: PluginAPI)
    updateProc*: proc(api: PluginAPI, dt: float)
    renderProc*: proc(api: PluginAPI)
    handleEventProc*: proc(api: PluginAPI, event: InputEvent): bool
    shutdownProc*: proc(api: PluginAPI)