# backstorie
Core Nim-based engine for building terminal apps and games.

## Quick Start

### Using the Run Script (Recommended)

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

### Direct Compilation

You can also compile directly with nim:

```bash
# Compile and run with default index.nim
nim c -r backstorie.nim

# Compile and run with a specific file
nim c -r -d:userFile=example_boxes backstorie.nim

# Show help
nim c -r backstorie.nim --help
```

## Creating Your Own App

1. Create a `.nim` file (e.g., `myapp.nim`)
2. Import plugins and define callbacks:

```nim
import plugins/simple_counter

onInit = proc(state: AppState) =
  state.registerPlugin(createCounterPlugin())

onUpdate = proc(state: AppState, dt: float) =
  discard

onRender = proc(state: AppState) =
  # Your rendering code here
  discard

onInput = proc(state: AppState, event: InputEvent): bool =
  # Handle input events
  return false

onShutdown = proc(state: AppState) =
  discard
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

- `index.nim` - Default simple counter demo
- `example_boxes.nim` - Border box that auto-resizes with terminal (demonstrates terminal resize handling)
- `example_simple_counter.nim` - Basic frame counter
- `example_fadein.nim` - Fade-in animation example
- `example_events_plugin.nim` - Event system demo
- `example_core_events.nim` - Core event handling demo

## Features

- **Automatic Terminal Resize Handling** - All layers automatically resize when the terminal size changes
- **Plugin Architecture** - Modular design with type-safe plugin system
- **Layer System** - Z-ordered layers with transparency support
- **Input Handling** - Comprehensive keyboard, mouse, and special key support
- **Color Support** - True color (24-bit), 256-color, and 8-color terminal support
