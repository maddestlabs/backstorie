# Backstorie Plugin Architecture Design

## Overview

This document describes the revamped plugin architecture for Backstorie, designed to eliminate circular dependencies, provide type safety, and enable efficient plugin development.

## Architecture Layers

```
┌─────────────────────────────────────┐
│   User Application (index.nim)      │
├─────────────────────────────────────┤
│   Plugins (animation, events, etc)  │
│   ↓ imports only                    │
├─────────────────────────────────────┤
│   plugin_interface.nim              │
│   - All shared types                │
│   - Plugin API functions            │
│   - No implementation               │
├─────────────────────────────────────┤
│   backstorie.nim                    │
│   - Core engine                     │
│   - Includes plugin_interface       │
│   - Implements plugin system        │
└─────────────────────────────────────┘
```

## Key Design Principles

### 1. **Single Source of Truth**
- `plugin_interface.nim` is the ONLY place where shared types are defined
- `backstorie.nim` includes and extends these types
- Plugins import ONLY `plugin_interface.nim`

### 2. **Type-Safe Plugin Data**
- Each plugin gets a typed context object
- No raw pointer casting needed
- Automatic lifetime management

### 3. **API-Based Access**
- Plugins use accessor functions instead of direct field access
- Core can change internals without breaking plugins
- Better encapsulation and safety

### 4. **Zero Circular Dependencies**
```
plugin_interface.nim  →  No dependencies
                         ↑
backstorie.nim       →  Imports plugin_interface
                         ↑
plugins/*.nim        →  Import plugin_interface ONLY
                         ↑
index.nim            →  Imports everything
```

## Core Types (in plugin_interface.nim)

### InputEvent
Complete input event system with keyboard, mouse, text, and resize events.

### PluginContext[T]
Type-safe plugin data storage:
```nim
type PluginContext*[T] = ref object
  data*: T
  pluginName*: string
```

### PluginAPI
Collection of functions plugins can call:
```nim
type PluginAPI* = object
  # Layer management
  addLayer*: proc(id: string, z: int): Layer
  getLayer*: proc(id: string): Layer
  removeLayer*: proc(id: string)
  
  # Drawing (to current buffer)
  write*: proc(x, y: int, ch: string, style: Style)
  writeText*: proc(x, y: int, text: string, style: Style)
  fillRect*: proc(x, y, w, h: int, ch: string, style: Style)
  
  # State queries
  getTermSize*: proc(): (int, int)
  getFrameCount*: proc(): int
  getTotalTime*: proc(): float
  getFPS*: proc(): float
  
  # Plugin data
  getPluginContext*: proc(T: typedesc, name: string): PluginContext[T]
  setPluginContext*: proc(T: typedesc, name: string, data: T)
```

### PluginModule
```nim
type PluginModule* = object
  name*: string
  version*: string
  initProc*: proc(api: PluginAPI)
  updateProc*: proc(api: PluginAPI, dt: float)
  renderProc*: proc(api: PluginAPI)
  handleEventProc*: proc(api: PluginAPI, event: InputEvent): bool
  shutdownProc*: proc(api: PluginAPI)
```

## Plugin Development Pattern

### 1. Define Plugin State Type
```nim
type MyPluginState = object
  counter: int
  items: seq[string]
```

### 2. Create Plugin with Typed Context
```nim
proc createMyPlugin*(): PluginModule =
  const pluginName = "myPlugin"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    
    initProc: proc(api: PluginAPI) =
      let state = MyPluginState(counter: 0, items: @[])
      api.setPluginContext(MyPluginState, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      var ctx = api.getPluginContext(MyPluginState, pluginName)
      ctx.data.counter += 1
    ,
    
    renderProc: proc(api: PluginAPI) =
      let ctx = api.getPluginContext(MyPluginState, pluginName)
      api.writeText(0, 0, $ctx.data.counter, defaultStyle())
  )
```

### 3. Register Plugin
```nim
onInit = proc(state: var AppState) =
  state.registerPlugin(createMyPlugin())
```

## Benefits

### For Plugin Developers
- ✅ Import only `plugin_interface.nim` - no circular dependencies
- ✅ Type-safe state management - no pointer casting
- ✅ Clear API - know exactly what's available
- ✅ No direct buffer access - safer, more maintainable
- ✅ Version tracking - plugins can declare compatibility

### For Core Engine
- ✅ Clean separation of concerns
- ✅ Can change internals without breaking plugins
- ✅ Better encapsulation
- ✅ Easier testing (can mock PluginAPI)

### For Users
- ✅ More reliable plugins
- ✅ Better error messages
- ✅ Plugins can't corrupt engine state

## Migration Guide

### Old Pattern (Broken)
```nim
import ../backstorie  # Circular dependency!

var myGlobalState: Table[string, int]

proc createPlugin*(): PluginModule =
  PluginModule(
    updateProc: proc(state: var AppState, dt: float) =
      state.currentBuffer.write(0, 0, "X", defaultStyle())
      # Direct access to internals
  )
```

### New Pattern (Fixed)
```nim
import plugin_interface  # Clean import!

type MyState = object
  values: Table[string, int]

proc createPlugin*(): PluginModule =
  const name = "myPlugin"
  PluginModule(
    name: name,
    initProc: proc(api: PluginAPI) =
      api.setPluginContext(MyState, name, MyState())
    ,
    updateProc: proc(api: PluginAPI, dt: float) =
      api.write(0, 0, "X", defaultStyle())
      # Use API functions
  )
```

## Performance Considerations

1. **PluginAPI proc pointers**: Minimal overhead (~1 indirect call)
2. **Type-safe contexts**: Zero-cost abstraction (ref object)
3. **Layer compositing**: Same as before
4. **Event dispatch**: Same as before

## Future Extensions

Possible additions without breaking compatibility:
- Plugin dependencies (load order)
- Hot reload support
- Plugin sandboxing (resource limits)
- Inter-plugin communication
- Plugin marketplace metadata
- Debug/profiling hooks
