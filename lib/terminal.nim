## Platform-agnostic terminal operations interface
## This module provides a unified API for terminal operations
## that works across different platforms (POSIX, Windows, WASM)

when not defined(emscripten):
  when defined(windows):
    # TODO: import lib/terminal_windows
    {.error: "Windows support not yet implemented. Use WSL or compile for WASM target.".}
  else:
    # POSIX systems (Linux, macOS, BSD, etc.)
    import terminal_posix
    export terminal_posix
else:
  # WebAssembly target - no terminal operations needed
  type
    TerminalState* = object
      dummy: int
  
  proc setupRawMode*(): TerminalState =
    discard
  
  proc restoreTerminal*(state: TerminalState) =
    discard
  
  proc restoreTerminal*() =
    discard
  
  proc hideCursor*() =
    discard
  
  proc showCursor*() =
    discard
  
  proc clearScreen*() =
    discard
  
  proc enableMouseReporting*() =
    discard
  
  proc disableMouseReporting*() =
    discard
  
  proc enableKeyboardProtocol*() =
    discard
  
  proc disableKeyboardProtocol*() =
    discard
  
  proc getTermSize*(): (int, int) =
    return (80, 24)
  
  proc readInputRaw*(buffer: var openArray[char]): int =
    return 0
  
  proc setupSignalHandlers*(handler: proc(sig: cint) {.noconv.}) =
    discard
