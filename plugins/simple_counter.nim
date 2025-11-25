## ================================================================
## Simple Counter Plugin - Demonstrates new plugin architecture
## ================================================================
## This plugin shows the CORRECT way to write a Backstorie plugin:
## - Import ONLY plugin_interface.nim (no circular dependencies)
## - Use type-safe PluginContext for state storage
## - Access engine through PluginAPI only
## - No direct access to AppState internals

import ../plugin_interface

# ================================================================
# PLUGIN STATE (type-safe)
# ================================================================

type
  CounterState = object
    count: int
    layer: LayerHandle
    x, y: int

# ================================================================
# PLUGIN IMPLEMENTATION
# ================================================================

proc createCounterPlugin*(): PluginModule =
  const pluginName = "simpleCounter"
  const pluginVersion = "1.0.0"
  
  PluginModule(
    name: pluginName,
    version: pluginVersion,
    
    initProc: proc(api: PluginAPI) =
      ## Initialize plugin state
      let layer = api.addLayer("counter_layer", 100)
      let state = CounterState(
        count: 0,
        layer: layer,
        x: 5,
        y: 5
      )
      setContext[CounterState](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      ## Update counter every frame
      var ctx = getContext[CounterState](api, pluginName)
      ctx.data.count += 1
    ,
    
    renderProc: proc(api: PluginAPI) =
      ## Render counter to its layer
      let ctx = getContext[CounterState](api, pluginName)
      let layer = ctx.data.layer
      
      # Clear layer
      api.layerClearTransparent(layer)
      
      # Draw counter
      let style = Style(fg: yellow(), bg: black(), bold: true)
      api.layerWriteText(layer, ctx.data.x, ctx.data.y, 
                         "Frame: " & $ctx.data.count, style)
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      ## Handle input events (reset on 'r' key)
      if event.kind == KeyEvent and event.keyAction == Press:
        if event.keyCode == ord('r'):
          var ctx = getContext[CounterState](api, pluginName)
          ctx.data.count = 0
          return true  # Event consumed
      return false  # Event not handled
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      ## Cleanup
      api.removeLayer("counter_layer")
  )
