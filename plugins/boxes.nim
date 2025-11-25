## ================================================================
## boxes.nim - Box and line drawing utilities
## ================================================================

import backstorie

# ================================================================
# DRAWING FUNCTIONS
# ================================================================

proc drawBox*(buffer: var TermBuffer, x, y, w, h: int, style: Style, double: bool = false) =
  ## Draw a box using unicode box characters
  if w < 2 or h < 2:
    return
  
  let (tl, tr, bl, br, horiz, vert) = if double:
    ("╔", "╗", "╚", "╝", "═", "║")
  else:
    ("┌", "┐", "└", "┘", "─", "│")
  
  # Corners
  buffer.write(x, y, tl, style)
  buffer.write(x + w - 1, y, tr, style)
  buffer.write(x, y + h - 1, bl, style)
  buffer.write(x + w - 1, y + h - 1, br, style)
  
  # Horizontal lines
  for i in 1 ..< w - 1:
    buffer.write(x + i, y, horiz, style)
    buffer.write(x + i, y + h - 1, horiz, style)
  
  # Vertical lines
  for i in 1 ..< h - 1:
    buffer.write(x, y + i, vert, style)
    buffer.write(x + w - 1, y + i, vert, style)

proc drawLine*(buffer: var TermBuffer, x1, y1, x2, y2: int, ch: string, style: Style) =
  ## Draw a line (horizontal or vertical)
  if y1 == y2:
    # Horizontal
    let startX = min(x1, x2)
    let endX = max(x1, x2)
    for x in startX..endX:
      buffer.write(x, y1, ch, style)
  elif x1 == x2:
    # Vertical
    let startY = min(y1, y2)
    let endY = max(y1, y2)
    for y in startY..endY:
      buffer.write(x1, y, ch, style)

# ================================================================
# STYLE PRESETS
# ================================================================

proc getDefaultStyles*(): Table[string, Style] =
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
# TEXT LAYOUT UTILITIES
# ================================================================

type
  Alignment* = enum
    AlignLeft, AlignCenter, AlignRight

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

proc writeAligned*(tb: var TermBuffer, y: int, text: string, containerWidth: int, 
                   align: Alignment, style: Style) =
  ## Write text with specified alignment
  let x = getAlignedX(text, containerWidth, align)
  tb.writeText(x, y, text, style)