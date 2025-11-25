# Quick Reference: Plugin API Usage

## Correct Syntax for Type-Safe Context Functions

### Storing Plugin State

```nim
# Define your state type
type MyPluginState = object
  counter: int
  data: Table[string, string]

# In initProc - store initial state
initProc: proc(api: PluginAPI) =
  let state = MyPluginState(counter: 0)
  setContext[MyPluginState](api, pluginName, state)
```

### Retrieving Plugin State (Mutable)

```nim
# Use getContext[T] with type parameter in brackets
updateProc: proc(api: PluginAPI, dt: float) =
  var ctx = getContext[MyPluginState](api, pluginName)
  ctx.data.counter += 1  # Can modify
```

### Retrieving Plugin State (Read-only)

```nim
# Use let for read-only access
renderProc: proc(api: PluginAPI) =
  let ctx = getContext[MyPluginState](api, pluginName)
  api.writeText(0, 0, $ctx.data.counter, defaultStyle())
```

## Complete Plugin Template

```nim
import plugin_interface

type MyPluginState = object
  myData: int
  myLayer: LayerHandle

proc createMyPlugin*(): PluginModule =
  const pluginName = "myPlugin"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    
    initProc: proc(api: PluginAPI) =
      let layer = api.addLayer("my_layer", 50)
      let state = MyPluginState(
        myData: 0,
        myLayer: layer
      )
      setContext[MyPluginState](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      var ctx = getContext[MyPluginState](api, pluginName)
      ctx.data.myData += 1
    ,
    
    renderProc: proc(api: PluginAPI) =
      let ctx = getContext[MyPluginState](api, pluginName)
      api.layerClearTransparent(ctx.data.myLayer)
      api.layerWriteText(ctx.data.myLayer, 0, 0,
                         "Value: " & $ctx.data.myData,
                         defaultStyle())
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      if event.kind == KeyEvent and event.keyCode == ord('r'):
        var ctx = getContext[MyPluginState](api, pluginName)
        ctx.data.myData = 0
        return true
      return false
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      api.removeLayer("my_layer")
  )
```

## Common Mistakes

### ❌ Wrong - Old method syntax
```nim
var ctx = api.getContext(MyState, pluginName)  # WRONG!
```

### ✅ Correct - Generic function syntax
```nim
var ctx = getContext[MyState](api, pluginName)  # CORRECT!
```

### ❌ Wrong - setContext without type
```nim
api.setContext(pluginName, state)  # WRONG!
```

### ✅ Correct - setContext with type parameter
```nim
setContext[MyPluginState](api, pluginName, state)  # CORRECT!
```

## Why This Syntax?

The helpers `getContext` and `setContext` are generic procs defined in `plugin_interface.nim`:

```nim
proc getContext*[T](api: PluginAPI, pluginName: string): PluginContext[T]
proc setContext*[T](api: PluginAPI, pluginName: string, data: T)
```

They're generic functions, not methods on PluginAPI, so:
- Type parameter goes in square brackets: `[T]`
- Called as regular function: `getContext[Type](api, ...)`
- NOT as method: `api.getContext(Type, ...)` ❌

## Plugin API Methods Reference

All these ARE methods on PluginAPI (use `api.method()` syntax):

```nim
# Layer management
let layer = api.addLayer("id", z)
let layer = api.getLayer("id")
api.removeLayer("id")
api.setLayerVisible(layer, true)

# Drawing to layers
api.layerWrite(layer, x, y, "X", style)
api.layerWriteText(layer, x, y, "text", style)
api.layerFillRect(layer, x, y, w, h, " ", style)
api.layerClear(layer)
api.layerClearTransparent(layer)

# Drawing to current buffer
api.write(x, y, "X", style)
api.writeText(x, y, "text", style)
api.fillRect(x, y, w, h, " ", style)

# Queries
let (w, h) = api.getTermSize()
let frame = api.getFrameCount()
let fps = api.getFPS()
let running = api.isRunning()
api.requestShutdown()
```

## Remember

- `getContext` and `setContext` are **generic functions** (not methods)
- Type parameter goes in **square brackets**: `[TypeName]`
- api parameter comes **first**: `getContext[T](api, name)`
- All other API operations are **methods**: `api.method(...)`
