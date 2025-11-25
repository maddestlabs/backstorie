# Backstorie Plugin System - Quick Start Guide

## Current Status: ✅ WORKING

The plugin architecture has been fixed and is now stable! You can create and use plugins without crashes.

## Running the Demo

```bash
# Run the simple counter demo
./backstorie

# Controls:
# - Press 'r' to reset the counter
# - Press 'q' to quit
```

## Project Structure

```
backstorie/
├── backstorie.nim           # Core engine (import this for all features)
├── plugin_interface.nim     # Shared types (plugins import this ONLY)
├── plugins/
│   ├── simple_counter.nim  # ✅ Working example plugin
│   ├── animation.nim       # ⚠️  Needs migration to new architecture
│   ├── boxes.nim           # ⚠️  Needs migration
│   ├── events.nim          # ⚠️  Needs migration
│   └── styles.nim          # ⚠️  Needs migration
├── index.nim               # User application/callbacks
└── example_*.nim           # Example applications
```

## Creating a Plugin

**Step 1: Import only `plugin_interface`**
```nim
import ../plugin_interface  # Only this - no backstorie.nim!
```

**Step 2: Define your plugin state**
```nim
type
  MyPluginState = object
    # Your plugin's data
    count: int
    layer: LayerHandle
    x, y: int
```

**Step 3: Create the plugin module**
```nim
proc createMyPlugin*(): PluginModule =
  const pluginName = "myPlugin"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    
    initProc: proc(api: PluginAPI) =
      # Initialize state
      let layer = api.addLayer("my_layer", 100)
      let state = MyPluginState(count: 0, layer: layer, x: 5, y: 5)
      setContext[MyPluginState](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      # Update logic (called every frame)
      var ctx = getContext[MyPluginState](api, pluginName)
      ctx.data.count += 1
    ,
    
    renderProc: proc(api: PluginAPI) =
      # Render to layer
      let ctx = getContext[MyPluginState](api, pluginName)
      api.layerClearTransparent(ctx.data.layer)
      
      let style = Style(fg: yellow(), bg: black())
      api.layerWriteText(ctx.data.layer, ctx.data.x, ctx.data.y, 
                         "Count: " & $ctx.data.count, style)
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      # Handle input (optional)
      if event.kind == KeyEvent and event.keyAction == Press:
        if event.keyCode == ord('r'):
          var ctx = getContext[MyPluginState](api, pluginName)
          ctx.data.count = 0
          return true  # Event consumed
      return false
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      # Cleanup
      api.removeLayer("my_layer")
  )
```

**Step 4: Register in your application**
```nim
# In index.nim or your main file
import plugins/my_plugin

onInit = proc(state: AppState) =
  state.registerPlugin(createMyPlugin())
```

## Plugin API Reference

### Context Management
- `getContext[T](api, pluginName)` - Retrieve typed plugin state
- `setContext[T](api, pluginName, data)` - Store typed plugin state

### Layer Management
- `api.addLayer(name, zIndex)` - Create a new layer
- `api.removeLayer(name)` - Remove layer by name
- `api.getLayerByName(name)` - Get layer handle
- `api.setLayerVisible(layer, visible)` - Show/hide layer

### Drawing (on layers)
- `api.layerWrite(layer, x, y, ch, style)` - Draw character
- `api.layerWriteText(layer, x, y, text, style)` - Draw text
- `api.layerFillRect(layer, x, y, w, h, ch, style)` - Fill rectangle
- `api.layerClear(layer)` - Clear layer (make black)
- `api.layerClearTransparent(layer)` - Clear layer (make transparent)

### Layer Effects
- `api.layerSetClip(layer, x, y, w, h)` - Set clipping region
- `api.layerClearClip(layer)` - Remove clipping
- `api.layerSetOffset(layer, x, y)` - Set layer offset

### Drawing (direct - no layer)
- `api.write(x, y, ch, style)` - Draw to current buffer
- `api.writeText(x, y, text, style)` - Draw text to current buffer
- `api.fillRect(x, y, w, h, ch, style)` - Fill rectangle

### Queries
- `api.getTermSize()` - Returns `(width, height)`
- `api.getFrameCount()` - Current frame number
- `api.getTotalTime()` - Total elapsed time
- `api.getFPS()` - Current frames per second
- `api.isRunning()` - Is engine running?
- `api.requestShutdown()` - Request graceful shutdown

## Style Creation

```nim
# Colors
let fg = rgb(255, 100, 50)     # True color
let bg = color256(196)         # 256-color palette
let text = cyan()              # Named colors
let dim = gray(128)            # Grayscale

# Style with attributes
let style = Style(
  fg: yellow(),
  bg: black(),
  bold: true,
  italic: false,
  underline: false,
  dim: false
)
```

## Input Events

```nim
handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
  case event.kind
  of KeyEvent:
    if event.keyAction == Press:
      case event.keyCode
      of ord('q'): 
        # Handle 'q' key
        return true
      of ord('r'):
        # Handle 'r' key
        return true
  of MouseEvent:
    # Handle mouse input
    echo event.mouseX, " ", event.mouseY
  of ResizeEvent:
    # Terminal was resized
    discard
  
  return false  # Not handled
```

## Architecture Rules

### ✅ DO:
- Import only `plugin_interface.nim` in plugins
- Use `getContext`/`setContext` for state management
- Access engine through `PluginAPI` only
- Return `true` from event handlers when consuming events
- Clean up resources in `shutdownProc`

### ❌ DON'T:
- Import `backstorie.nim` from plugins (circular dependency!)
- Access `AppState` directly from plugins
- Store raw pointers to engine internals
- Forget to create/remove layers in init/shutdown
- Block the main thread in callbacks

## Troubleshooting

### Plugin state not persisting?
Make sure you're modifying `ctx.data`, not creating a new object:
```nim
var ctx = getContext[MyState](api, pluginName)
ctx.data.count += 1  # ✅ Modifies existing state
```

### Segmentation fault?
- Check if you're using the right plugin name string in `getContext`
- Ensure you called `setContext` in `initProc` before accessing in other callbacks
- Verify layer handles are valid before drawing

### Plugin not rendering?
- Check layer Z-index (higher = on top)
- Verify layer is visible: `api.setLayerVisible(layer, true)`
- Make sure you're clearing the layer before drawing
- Check if clipping is cutting off your content

## Next Steps

1. **Run the working demo**: `./backstorie`
2. **Study the example**: `plugins/simple_counter.nim`
3. **Create your plugin**: Follow the structure above
4. **Migrate old plugins**: See `PLUGIN_MIGRATION.md`

## Need Help?

- See `PLUGIN_ARCHITECTURE.md` for detailed architecture overview
- See `API_QUICK_REFERENCE.md` for complete API documentation
- See `BUG_FIX_SUMMARY.md` for technical details on the memory safety fix
- Study `plugins/simple_counter.nim` for a complete working example
