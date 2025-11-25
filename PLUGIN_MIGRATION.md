# Plugin Migration Guide

## Overview

The Backstorie plugin architecture has been completely redesigned to eliminate circular dependencies and provide a clean, type-safe API for plugin development.

## What Changed?

### Before (Broken)
```nim
import ../backstorie  # ❌ Circular dependency!

var myGlobalVar: int  # ❌ Global state

proc createPlugin*(): PluginModule =
  PluginModule(
    name: "myPlugin",
    initProc: proc(state: var AppState) =  # ❌ Direct AppState access
      discard
    ,
    updateProc: proc(state: var AppState, dt: float) =
      state.currentBuffer.write(0, 0, "X", defaultStyle())  # ❌ Direct buffer access
      myGlobalVar += 1  # ❌ Unsafe global state
  )
```

### After (Fixed)
```nim
import plugin_interface  # ✅ Clean import, no circular deps!

type MyPluginState = object  # ✅ Typed state
  counter: int

proc createPlugin*(): PluginModule =
  const pluginName = "myPlugin"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    initProc: proc(api: PluginAPI) =  # ✅ API-based access
      setContext[???](api, pluginName, MyPluginState(counter: 0))
    ,
    updateProc: proc(api: PluginAPI, dt: float) =
      var ctx = getContext[MyPluginState](api, pluginName)
      api.write(0, 0, "X", defaultStyle())  # ✅ API calls
      ctx.data.counter += 1  # ✅ Type-safe state
  )
```

## Step-by-Step Migration

### 1. Update Imports

**Before:**
```nim
import ../backstorie
```

**After:**
```nim
import plugin_interface
```

### 2. Define Plugin State Type

**Before:**
```nim
var animationTable: Table[string, Animation]
var counter = 0
```

**After:**
```nim
type MyPluginState = object
  animationTable: Table[string, Animation]
  counter: int
```

### 3. Update Plugin Creation

**Before:**
```nim
proc createMyPlugin*(): PluginModule =
  PluginModule(
    name: "myPlugin",
    initProc: proc(state: var AppState) =
      state.pluginData["myPlugin"] = cast[pointer](someData)
    ,
    updateProc: proc(state: var AppState, dt: float) =
      let data = cast[MyData](state.pluginData["myPlugin"])
      state.currentBuffer.write(0, 0, "X", defaultStyle())
  )
```

**After:**
```nim
proc createMyPlugin*(): PluginModule =
  const pluginName = "myPlugin"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    
    initProc: proc(api: PluginAPI) =
      let state = MyPluginState()
      setContext[???](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      var ctx = getContext[MyPluginState](api, pluginName)
      api.write(0, 0, "X", defaultStyle())
  )
```

### 4. Use Layers Through API

**Before:**
```nim
let layer = state.addLayer("myLayer", 100)
layer.buffer.write(0, 0, "X", style)
```

**After:**
```nim
let layer = api.addLayer("myLayer", 100)
api.layerWrite(layer, 0, 0, "X", style)
```

## Complete Example: Counter Plugin

```nim
import plugin_interface

type CounterState = object
  count: int
  layer: LayerHandle

proc createCounterPlugin*(): PluginModule =
  const pluginName = "counter"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    
    initProc: proc(api: PluginAPI) =
      let layer = api.addLayer("counter_layer", 100)
      api.setContext(pluginName, CounterState(
        count: 0,
        layer: layer
      ))
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      var ctx = getContext[CounterState](api, pluginName)
      ctx.data.count += 1
    ,
    
    renderProc: proc(api: PluginAPI) =
      let ctx = getContext[CounterState](api, pluginName)
      api.layerClearTransparent(ctx.data.layer)
      api.layerWriteText(ctx.data.layer, 0, 0, 
                         "Count: " & $ctx.data.count,
                         defaultStyle())
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      if event.kind == KeyEvent and event.keyCode == ord('r'):
        var ctx = getContext[CounterState](api, pluginName)
        ctx.data.count = 0
        return true
      return false
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      api.removeLayer("counter_layer")
  )
```

## Plugin API Reference

### Layer Management
- `addLayer(id: string, z: int): LayerHandle` - Create a new layer
- `getLayer(id: string): LayerHandle` - Get layer by ID
- `removeLayer(id: string)` - Remove layer
- `setLayerVisible(layer, visible)` - Show/hide layer

### Drawing to Layers
- `layerWrite(layer, x, y, ch, style)` - Write single character
- `layerWriteText(layer, x, y, text, style)` - Write text string
- `layerFillRect(layer, x, y, w, h, ch, style)` - Fill rectangle
- `layerClear(layer)` - Clear layer (opaque)
- `layerClearTransparent(layer)` - Clear layer (transparent)
- `layerSetClip(layer, x, y, w, h)` - Set clipping region
- `layerClearClip(layer)` - Clear clipping
- `layerSetOffset(layer, x, y)` - Set render offset

### Drawing to Current Buffer
- `write(x, y, ch, style)` - Write single character
- `writeText(x, y, text, style)` - Write text string
- `fillRect(x, y, w, h, ch, style)` - Fill rectangle

### State Queries
- `getTermSize(): (int, int)` - Get terminal dimensions
- `getFrameCount(): int` - Get current frame number
- `getTotalTime(): float` - Get elapsed time in seconds
- `getFPS(): float` - Get current FPS
- `isRunning(): bool` - Check if engine is running
- `requestShutdown()` - Request engine shutdown

### Plugin Data (Type-Safe)
- `getContext[T](name): PluginContext[T]` - Get typed plugin state
- `setContext[T](name, data: T)` - Set typed plugin state

## Benefits of New Architecture

### For Plugin Developers
✅ **No Circular Dependencies** - Import only `plugin_interface.nim`  
✅ **Type Safety** - No more pointer casting  
✅ **Clear API** - Know exactly what's available  
✅ **Better IDE Support** - Autocomplete and type checking  
✅ **Easier Testing** - Can mock PluginAPI  

### For Core Engine
✅ **Encapsulation** - Plugins can't corrupt engine state  
✅ **Flexibility** - Can change internals without breaking plugins  
✅ **Maintainability** - Clear separation of concerns  

### For Users
✅ **More Reliable** - Less crashes from plugin bugs  
✅ **Better Errors** - Clear error messages  
✅ **Hot Reload Ready** - Architecture supports future hot reload  

## Common Patterns

### Storing Complex State
```nim
type MyState = object
  entities: seq[Entity]
  config: Config
  layers: array[3, LayerHandle]

proc createPlugin(): PluginModule =
  const name = "myPlugin"
  PluginModule(
    initProc: proc(api: PluginAPI) =
      var state = MyState()
      state.layers[0] = api.addLayer("bg", 0)
      state.layers[1] = api.addLayer("mid", 50)
      state.layers[2] = api.addLayer("fg", 100)
      setContext[???](api, name, state)
  )
```

### Accessing State in Multiple Callbacks
```nim
updateProc: proc(api: PluginAPI, dt: float) =
  var ctx = getContext[MyState](api, pluginName)
  # Modify state
  ctx.data.counter += 1
,

renderProc: proc(api: PluginAPI) =
  let ctx = getContext[MyState](api, pluginName)
  # Read state (note: let, not var)
  api.writeText(0, 0, $ctx.data.counter, defaultStyle())
```

### Event Handling
```nim
handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
  case event.kind
  of KeyEvent:
    if event.keyAction == Press and event.keyCode == INPUT_SPACE:
      var ctx = getContext[MyState](api, pluginName)
      ctx.data.something = true
      return true  # Event consumed
  of MouseEvent:
    if event.button == Left and event.action == Press:
      # Handle mouse click at (event.mouseX, event.mouseY)
      return true
  else:
    discard
  return false  # Event not handled
```

## Troubleshooting

### "Cannot import backstorie"
**Problem:** Old code trying to import the core engine  
**Solution:** Change `import ../backstorie` to `import plugin_interface`

### "Type mismatch: got AppState"
**Problem:** Old callback signatures  
**Solution:** Change `proc(state: var AppState)` to `proc(api: PluginAPI)`

### "Undeclared identifier: currentBuffer"
**Problem:** Trying to access internal state  
**Solution:** Use API calls like `api.write()` instead

### "Cannot cast pointer"
**Problem:** Old pointer-based state storage  
**Solution:** Use typed contexts: `getContext[MyState](api, pluginName)`

## See Also

- `example_simple_counter.nim` - Basic plugin example
- `PLUGIN_ARCHITECTURE.md` - Detailed architecture documentation
- `plugin_interface.nim` - Complete API reference
