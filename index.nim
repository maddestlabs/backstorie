## ================================================================
## Simple Counter Demo - Demonstrates new plugin architecture
## ================================================================
## Run with: nim c -r backstorie.nim

import plugins/simple_counter

var infoText = "Press 'r' to reset counter | Press 'q' to quit"

onInit = proc(state: AppState) =
  # Register the counter plugin
  state.registerPlugin(createCounterPlugin())

onUpdate = proc(state: AppState, dt: float) =
  discard

onRender = proc(state: AppState) =
  # Draw some UI
  let style = Style(fg: cyan(), bg: black())
  let dimStyle = Style(fg: gray(128), bg: black(), dim: true)
  
  state.currentBuffer.writeText(1, 1, "=== Simple Counter Demo ===", style)
  state.currentBuffer.writeText(1, 2, infoText, dimStyle)
  
  # Show FPS
  let fpsText = "FPS: " & $int(state.fps)
  state.currentBuffer.writeText(1, state.termHeight - 2, fpsText, dimStyle)

onInput = proc(state: AppState, event: InputEvent): bool =
  # Handle quit
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == ord('q'):
      state.running = false
      return true
  elif event.kind == TextEvent:
    # Handle regular character input
    if event.text == "q":
      state.running = false
      return true
  return false

onShutdown = proc(state: AppState) =
  discard
