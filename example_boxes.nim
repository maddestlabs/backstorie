## ================================================================
## Border Box Demo - Draws a box at the terminal edges
## ================================================================
## Run with: ./run.sh example_boxes
## This example demonstrates:
## - Drawing a border box that follows terminal dimensions
## - Handling terminal resize events
## - Creating a custom plugin for border drawing

import plugins/boxes

type
  BorderBoxState = object
    layer: LayerHandle
    useDouble: bool

proc createBorderBoxPlugin(): PluginModule =
  const pluginName = "borderBox"
  
  PluginModule(
    name: pluginName,
    version: "1.0.0",
    
    initProc: proc(api: PluginAPI) =
      let layer = api.addLayer("border_layer", 10)
      let state = BorderBoxState(
        layer: layer,
        useDouble: false
      )
      setContext[BorderBoxState](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      discard
    ,
    
    renderProc: proc(api: PluginAPI) =
      let ctx = getContext[BorderBoxState](api, pluginName)
      let layer = ctx.data.layer
      let (termW, termH) = api.getTermSize()
      
      # Clear the layer
      api.layerClearTransparent(layer)
      
      # Draw border box at the edges of the terminal
      let borderStyle = Style(fg: cyan(), bg: black(), bold: true)
      drawBox(api, layer, 0, 0, termW, termH, borderStyle, ctx.data.useDouble)
      
      # Draw title at the top
      let titleStyle = Style(fg: yellow(), bg: black(), bold: true)
      let title = " Border Box Demo "
      let titleX = (termW - title.len) div 2
      api.layerWriteText(layer, titleX, 0, title, titleStyle)
      
      # Draw instructions at the bottom
      let dimStyle = Style(fg: gray(128), bg: black(), dim: true)
      let info = " Press 'd' to toggle double-line | Press 'q' to quit "
      let infoX = (info.len + 2) div 2  # Account for spaces
      let adjustedX = max(1, (termW - info.len) div 2)
      if termH > 1:
        api.layerWriteText(layer, adjustedX, termH - 1, info, dimStyle)
      
      # Show terminal size and FPS inside the box
      let infoStyle = Style(fg: white(), bg: black())
      let sizeText = "Terminal: " & $termW & "x" & $termH
      let fpsText = "FPS: " & $int(api.getFPS())
      
      if termW > 20 and termH > 5:
        api.layerWriteText(layer, 2, 2, sizeText, infoStyle)
        api.layerWriteText(layer, 2, 3, fpsText, infoStyle)
        
        # Show box type
        let boxType = if ctx.data.useDouble: "Box style: Double-line" else: "Box style: Single-line"
        api.layerWriteText(layer, 2, 4, boxType, infoStyle)
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      if event.kind == KeyEvent and event.keyAction == Press:
        if event.keyCode == ord('d') or event.keyCode == ord('D'):
          var ctx = getContext[BorderBoxState](api, pluginName)
          ctx.data.useDouble = not ctx.data.useDouble
          return true
      elif event.kind == TextEvent:
        if event.text == "d" or event.text == "D":
          var ctx = getContext[BorderBoxState](api, pluginName)
          ctx.data.useDouble = not ctx.data.useDouble
          return true
      return false
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      api.removeLayer("border_layer")
  )

onInit = proc(state: AppState) =
  # Register the border box plugin
  state.registerPlugin(createBorderBoxPlugin())

onUpdate = proc(state: AppState, dt: float) =
  discard

onRender = proc(state: AppState) =
  discard

onInput = proc(state: AppState, event: InputEvent): bool =
  # Handle quit
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == ord('q') or event.keyCode == ord('Q'):
      state.running = false
      return true
  elif event.kind == TextEvent:
    if event.text == "q" or event.text == "Q":
      state.running = false
      return true
  return false

onShutdown = proc(state: AppState) =
  discard
