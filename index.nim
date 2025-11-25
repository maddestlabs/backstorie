# ================================================================
# index.nim - User code for Backstorie
# 
# This file is automatically included by backstorie.nim at compile time.
# Assign functions to userInitProc, userUpdateProc, and userRenderProc
# to customize the app, or define your own procs and assign them.
# ================================================================

import plugins/animation
import plugins/styles

var uiLayer: Layer

# Define your init function
proc setupExample(state: var AppState) =
  # Register the animation plugin
  let animPlugin = createAnimationPlugin()
  state.registerPlugin(animPlugin)
  
  # Create a UI layer for animations
  uiLayer = state.addLayer("ui", 100)
  
  # Create a chain of animations to demonstrate features
  let anims = @[
    newTypewriter("intro", uiLayer, 2, 2,
                  "Welcome to Backstorie!", 
                  state.styles["heading"], 2.0, ekEaseOutQuad),
    
    newSlideIn("subtitle", uiLayer, 2, 4,
               "An animation engine for terminal stories",
               state.styles["info"], 1.5, 30.0, ekEaseOutQuad),
    
    newFadeIn("features", uiLayer, 2, 6,
              "• Typewriter effects",
              state.styles["default"], 1.0, ekEaseInSine),
    
    newTypewriter("feat2", uiLayer, 2, 7,
                  "• Slide-in text",
                  state.styles["default"], 1.0, ekLinear),
    
    newTypewriter("feat3", uiLayer, 2, 8,
                  "• Fade effects",
                  state.styles["default"], 1.0, ekLinear),
    
    newWave("wave", uiLayer, 2, 10,
            "~ ~ ~ W A V E ~ ~ ~",
            state.styles["highlight"], 3.0, 2.0),
    
    newRainbow("rainbow", uiLayer, 2, 12,
               "Rainbow Colors!",
               state.styles["default"], 1.5),
  ]
  
  state.createChain("demo", anims, loop=true)

# Define your update function
proc updateExample(state: var AppState, dt: float) =
  # Your custom update logic here
  # Animations are handled by the plugin
  discard

# Define your render function
proc renderExample(state: var AppState) =
  # Add custom rendering here if needed
  # Optional: add instructions at the bottom
  let y = state.termHeight - 2
  state.currentBuffer.writeText(1, y, "Press Ctrl+C to exit", state.styles["dim"])

# Assign the callbacks to the engine
userInitProc = setupExample
userUpdateProc = updateExample
userRenderProc = renderExample