## ================================================================
## Example: Simple Counter Plugin Demo
## ================================================================
## Demonstrates the NEW plugin architecture
##
## Run with: nim c -r -d:release example_simple_counter.nim

import backstorie
import plugins/simple_counter

var infoText = "Press 'r' to reset counter | Press 'q' to quit"

onInit = proc(state: var AppState) =
  # Register the counter plugin
  state.registerPlugin(createCounterPlugin())

onUpdate = proc(state: var AppState, dt: float) =
  discard

onRender = proc(state: var AppState) =
  # Draw some UI
  let style = Style(fg: cyan(), bg: black())
  let dimStyle = Style(fg: gray(128), bg: black(), dim: true)
  
  state.currentBuffer.writeText(1, 1, "=== Plugin Architecture Demo ===", style)
  state.currentBuffer.writeText(1, 2, infoText, dimStyle)
  
  # Show FPS
  let fpsText = "FPS: " & $int(state.fps)
  state.currentBuffer.writeText(1, state.termHeight - 2, fpsText, dimStyle)

onInput = proc(state: var AppState, event: InputEvent): bool =
  # Handle quit
  if event.kind == KeyEvent and event.keyAction == Press:
    if event.keyCode == ord('q'):
      state.running = false
      return true
  return false

onShutdown = proc(state: var AppState) =
  discard
