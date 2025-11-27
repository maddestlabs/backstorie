## ================================================================
## Boxes Plugin - Box and line drawing utilities with demo
## ================================================================
## This plugin demonstrates drawing utility functions using the
## new plugin architecture. It shows how to:
## - Create reusable drawing utilities through the PluginAPI
## - Render demonstration content to a layer
## - Handle events to change display options

import plugin_interface
import tables, strutils

# ================================================================
# PLUGIN STATE (type-safe)
# ================================================================

type
  Alignment* = enum
    AlignLeft, AlignCenter, AlignRight

  BoxesState = object
    layer: LayerHandle
    showDouble: bool
    styles: Table[string, Style]

# ================================================================
# DRAWING UTILITY FUNCTIONS
# ================================================================

proc drawBox*(api: PluginAPI, layer: LayerHandle, x, y, w, h: int, style: Style, double: bool = false) =
  ## Draw a box using unicode box characters
  if w < 2 or h < 2:
    return
  
  let (tl, tr, bl, br, horiz, vert) = if double:
    ("╔", "╗", "╚", "╝", "═", "║")
  else:
    ("┌", "┐", "└", "┘", "─", "│")
  
  # Corners
  api.layerWrite(layer, x, y, tl, style)
  api.layerWrite(layer, x + w - 1, y, tr, style)
  api.layerWrite(layer, x, y + h - 1, bl, style)
  api.layerWrite(layer, x + w - 1, y + h - 1, br, style)
  
  # Horizontal lines
  for i in 1 ..< w - 1:
    api.layerWrite(layer, x + i, y, horiz, style)
    api.layerWrite(layer, x + i, y + h - 1, horiz, style)
  
  # Vertical lines
  for i in 1 ..< h - 1:
    api.layerWrite(layer, x, y + i, vert, style)
    api.layerWrite(layer, x + w - 1, y + i, vert, style)

proc drawLine*(api: PluginAPI, layer: LayerHandle, x1, y1, x2, y2: int, ch: string, style: Style) =
  ## Draw a line (horizontal or vertical)
  if y1 == y2:
    # Horizontal
    let startX = min(x1, x2)
    let endX = max(x1, x2)
    for x in startX..endX:
      api.layerWrite(layer, x, y1, ch, style)
  elif x1 == x2:
    # Vertical
    let startY = min(y1, y2)
    let endY = max(y1, y2)
    for y in startY..endY:
      api.layerWrite(layer, x1, y, ch, style)

proc wrapText*(text: string, maxWidth: int): seq[string] =
  ## Wrap text to fit within maxWidth
  result = @[]
  if maxWidth <= 0:
    return
  
  var currentLine = ""
  let words = text.split(' ')
  
  for word in words:
    if currentLine.len + word.len + 1 <= maxWidth:
      if currentLine.len > 0:
        currentLine.add(" ")
      currentLine.add(word)
    else:
      if currentLine.len > 0:
        result.add(currentLine)
      currentLine = word
      if currentLine.len > maxWidth:
        result.add(currentLine)
        currentLine = ""
  
  if currentLine.len > 0:
    result.add(currentLine)

proc getAlignedX*(text: string, containerWidth: int, align: Alignment): int =
  ## Calculate X position for aligned text
  case align
  of AlignLeft:
    return 0
  of AlignCenter:
    return max(0, (containerWidth - text.len) div 2)
  of AlignRight:
    return max(0, containerWidth - text.len)

proc getDefaultStyles*(): Table[string, Style] =
  ## Get a table of common style presets
  result = initTable[string, Style]()
  result["default"] = Style(fg: white(), bg: black(), bold: false)
  result["heading"] = Style(fg: yellow(), bg: black(), bold: true)
  result["error"] = Style(fg: red(), bg: black(), bold: true)
  result["success"] = Style(fg: green(), bg: black(), bold: true)
  result["info"] = Style(fg: cyan(), bg: black(), bold: false)
  result["warning"] = Style(fg: yellow(), bg: black(), bold: false)
  result["dim"] = Style(fg: gray(128), bg: black(), dim: true)
  result["highlight"] = Style(fg: black(), bg: yellow(), bold: true)
  result["border"] = Style(fg: cyan(), bg: black(), bold: false)

# ================================================================
# PLUGIN IMPLEMENTATION
# ================================================================

proc createBoxesPlugin*(): PluginModule =
  const pluginName = "boxes"
  const pluginVersion = "1.0.0"
  
  PluginModule(
    name: pluginName,
    version: pluginVersion,
    
    initProc: proc(api: PluginAPI) =
      ## Initialize plugin state
      let layer = api.addLayer("boxes_layer", 50)
      let state = BoxesState(
        layer: layer,
        showDouble: false,
        styles: getDefaultStyles()
      )
      setContext[BoxesState](api, pluginName, state)
    ,
    
    updateProc: proc(api: PluginAPI, dt: float) =
      ## Update plugin (nothing to do per frame)
      discard
    ,
    
    renderProc: proc(api: PluginAPI) =
      ## Render demonstration boxes and lines
      let ctx = getContext[BoxesState](api, pluginName)
      let layer = ctx.data.layer
      let (termW, termH) = api.getTermSize()
      
      # Clear layer
      api.layerClearTransparent(layer)
      
      # Title
      let titleStyle = ctx.data.styles["heading"]
      api.layerWriteText(layer, 2, 2, "=== Boxes Plugin Demo ===", titleStyle)
      
      # Instructions
      let dimStyle = ctx.data.styles["dim"]
      api.layerWriteText(layer, 2, 3, "Press 'd' to toggle double-line mode", dimStyle)
      
      # Draw demonstration boxes
      let borderStyle = ctx.data.styles["border"]
      
      # Box 1 - Normal or double
      drawBox(api, layer, 5, 6, 30, 10, borderStyle, ctx.data.showDouble)
      let boxLabel = if ctx.data.showDouble: "Double-line box" else: "Single-line box"
      api.layerWriteText(layer, 7, 7, boxLabel, ctx.data.styles["info"])
      
      # Box 2 - Success style
      drawBox(api, layer, 40, 6, 25, 8, ctx.data.styles["success"], false)
      api.layerWriteText(layer, 42, 7, "Success box", ctx.data.styles["success"])
      
      # Box 3 - Error style
      drawBox(api, layer, 5, 18, 28, 6, ctx.data.styles["error"], false)
      api.layerWriteText(layer, 7, 19, "Error box", ctx.data.styles["error"])
      
      # Draw some decorative lines
      let lineStyle = ctx.data.styles["info"]
      drawLine(api, layer, 2, 26, termW - 3, 26, "─", lineStyle)
      
      # Text wrapping demo
      if termW > 50:
        let longText = "This is a demonstration of text wrapping. The text will be wrapped to fit within the specified width."
        let wrapped = wrapText(longText, 40)
        var lineY = 28
        for line in wrapped:
          api.layerWriteText(layer, 2, lineY, line, ctx.data.styles["default"])
          lineY += 1
    ,
    
    handleEventProc: proc(api: PluginAPI, event: InputEvent): bool =
      ## Handle input events (toggle double-line mode with 'd' key)
      if event.kind == KeyEvent and event.keyAction == Press:
        if event.keyCode == ord('d') or event.keyCode == ord('D'):
          var ctx = getContext[BoxesState](api, pluginName)
          ctx.data.showDouble = not ctx.data.showDouble
          return true  # Event consumed
      elif event.kind == TextEvent:
        # Handle regular character input
        if event.text == "d" or event.text == "D":
          var ctx = getContext[BoxesState](api, pluginName)
          ctx.data.showDouble = not ctx.data.showDouble
          return true  # Event consumed
      return false  # Event not handled
    ,
    
    shutdownProc: proc(api: PluginAPI) =
      ## Cleanup
      api.removeLayer("boxes_layer")
  )