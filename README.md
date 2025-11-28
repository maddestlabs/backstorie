# backstorie
Core Nim-based engine for building terminal apps and games, with support for both native and WebAssembly targets.

**Platform Support:** Linux ✅ | macOS ✅ | BSD ✅ | Windows (via WSL) ✅ | Browser (WASM) ✅ | Windows Native ⏳

## Quick Start

### Native Terminal Apps

#### Using the Run Script (Recommended)

The easiest way to run backstorie with different example files:

```bash
# Run the default index.nim
./run.sh

# Run a specific example
./run.sh example_boxes
./run.sh example_simple_counter

# Compile in release mode (optimized)
./run.sh -r example_boxes

# Compile only (don't run)
./run.sh -c example_boxes

# Show help
./run.sh --help
```

#### Direct Compilation

You can also compile directly with nim:

```bash
# Compile and run with default index.nim
nim c -r backstorie.nim

# Compile and run with a specific file
nim c -r -d:userFile=example_boxes backstorie.nim

# Show help
nim c -r backstorie.nim --help
```

### WebAssembly (Browser)

Compile your Backstorie apps to run in the browser:

```bash
# Compile to WASM
./compile_wasm.sh example_boxes

# Compile and serve locally
./compile_wasm.sh -s example_boxes

# Deploy to GitHub Pages
./compile_wasm.sh -o docs -r example_boxes
```

See detailed guides:
- [WASM_GUIDE.md](WASM_GUIDE.md) - Compilation and deployment
- [GITHUB_PAGES.md](GITHUB_PAGES.md) - Deploy to GitHub Pages

## Creating Your Own App

1. Create a `.nim` file (e.g., `myapp.nim`)
2. Optionally import helper libraries and define callbacks:

```nim
# Import helper libraries (optional)
import lib/events
import lib/ui_components
import lib/animation

# Create your app state
var myText = "Hello, World!"
var myAnimation = newAnimation(2.0, loop = true)

onInit = proc(state: AppState) =
  # Initialize your app
  echo "App started!"

onUpdate = proc(state: AppState, dt: float) =
  # Update animations, game logic, etc.
  myAnimation.update(dt)

onRender = proc(state: AppState) =
  # Draw using helper functions or directly
  drawBox(state, 10, 5, 40, 10, defaultStyle(), "My App")
  state.currentBuffer.writeText(12, 7, myText, defaultStyle())

onInput = proc(state: AppState, event: InputEvent): bool =
  # Handle input events
  if event.kind == KeyEvent and event.keyCode == ord('q'):
    state.running = false
    return true
  return false

onShutdown = proc(state: AppState) =
  echo "App shutting down"
```

3. Run it:

```bash
./run.sh myapp
```

or compile directly:

```bash
nim c -r -d:userFile=myapp backstorie.nim
```

## Available Examples

- `index.nim` - Default simple demo
- `example_boxes.nim` - Animated bouncing boxes with layers
- `example_counter.nim` - Basic frame counter
- `example_fadein.nim` - Fade-in animation example
- `example_particles.nim` - Particle system demo
- `example_core_events.nim` - Core event handling demo
- `example_advanced_events.nim` - Advanced event system usage
- `example_wasm_test.nim` - WASM/browser compatibility test

## Helper Libraries

- `lib/events.nim` - Robust event handling with callbacks
- `lib/animation.nim` - Easing functions, interpolation, particles
- `lib/ui_components.nim` - Reusable UI elements (boxes, buttons, progress bars)
- `lib/terminal.nim` - Platform-agnostic terminal operations
- `lib/terminal_posix.nim` - POSIX implementation (Linux, macOS, BSD)

See [LIBRARY_GUIDE.md](LIBRARY_GUIDE.md) for detailed usage instructions and examples.

## Features

- **Cross-Platform** - Runs natively in terminals and in web browsers via WebAssembly
- **Modular Architecture** - Platform-specific code cleanly separated for easy maintenance
- **Automatic Terminal Resize Handling** - All layers automatically resize when the terminal or browser window changes size
- **Direct Callback Architecture** - Simple onInit/onUpdate/onRender callback system
- **Reusable Libraries** - Helper modules for events, animations, and UI components
- **Layer System** - Z-ordered layers with transparency support
- **Input Handling** - Comprehensive keyboard, mouse, and special key support
- **Color Support** - True color (24-bit), 256-color, and 8-color terminal support
- **Canvas Rendering** - Hardware-accelerated rendering in browser via HTML5 canvas

## Platform Notes

- **Linux/macOS/BSD**: Native POSIX support with optimized terminal operations
- **Windows**: Use WSL for best experience, or see [WINDOWS_SUPPORT.md](docs/WINDOWS_SUPPORT.md) for native Windows implementation guide
- **Browser**: Full WebAssembly support with canvas rendering (works on all platforms)
