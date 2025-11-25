import tables
import ../backstorie

type
  StylePreset* = object
    name*: string
    style*: Style

var globalStyles*: Table[string, Style]

proc initStyles*() =
  globalStyles = initTable[string, Style]()
  globalStyles["default"] = Style(fg: white(), bg: black(), bold: false)
  globalStyles["heading"] = Style(fg: yellow(), bg: black(), bold: true)
  globalStyles["error"] = Style(fg: red(), bg: black(), bold: true)
  globalStyles["success"] = Style(fg: green(), bg: black(), bold: true)
  globalStyles["info"] = Style(fg: cyan(), bg: black(), bold: false)
  globalStyles["warning"] = Style(fg: yellow(), bg: black(), bold: false)
  globalStyles["dim"] = Style(fg: gray(128), bg: black(), dim: true)
  globalStyles["highlight"] = Style(fg: black(), bg: yellow(), bold: true)
  globalStyles["border"] = Style(fg: cyan(), bg: black(), bold: false)

proc getStyle*(name: string): Style =
  if name in globalStyles:
    return globalStyles[name]
  return Style(fg: white(), bg: black())

proc setStyle*(name: string, style: Style) =
  globalStyles[name] = style