# Test FadeIn standalone
import plugins/animation
import plugins/styles

var uiLayer: Layer

proc setupExample(state: var AppState) =
  let animPlugin = createAnimationPlugin()
  state.registerPlugin(animPlugin)
  
  uiLayer = state.addLayer("ui", 100)
  
  let fade = newFadeIn("fade1", uiLayer, 5, 5,
                      "FADE IN TEST",
                      getStyle("default"), 2.0, ekEaseInSine)
  state.addAnimation(fade)

proc updateExample(state: var AppState, dt: float) =
  discard

proc renderExample(state: var AppState) =
  state.currentBuffer.writeText(1, 1, "Fade test", getStyle("default"))
  let y = state.termHeight - 2
  state.currentBuffer.writeText(1, y, "Ctrl+C", getStyle("dim"))

onInit = setupExample
onUpdate = updateExample
onRender = renderExample