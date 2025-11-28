## Windows-specific terminal operations
## This module handles raw terminal mode, input reading, and terminal control
## for Windows systems using the Windows Console API
##
## MINIMAL IMPLEMENTATION - Just enough to get basic rendering working
## This provides a foundation that can be expanded later

import winlean

# Windows Console API types and constants
type
  COORD = object
    x: int16
    y: int16

  SMALL_RECT = object
    left: int16
    top: int16
    right: int16
    bottom: int16

  CONSOLE_SCREEN_BUFFER_INFO = object
    dwSize: COORD
    dwCursorPosition: COORD
    wAttributes: uint16
    srWindow: SMALL_RECT
    dwMaximumWindowSize: COORD

  DWORD = uint32
  WINBOOL = int32

const
  STD_INPUT_HANDLE = -10
  STD_OUTPUT_HANDLE = -11
  
  # Input mode flags
  ENABLE_PROCESSED_INPUT = 0x0001
  ENABLE_LINE_INPUT = 0x0002
  ENABLE_ECHO_INPUT = 0x0004
  ENABLE_WINDOW_INPUT = 0x0008
  ENABLE_MOUSE_INPUT = 0x0010
  ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200
  
  # Output mode flags
  ENABLE_PROCESSED_OUTPUT = 0x0001
  ENABLE_WRAP_AT_EOL_OUTPUT = 0x0002
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

# Windows Console API functions
proc GetStdHandle(nStdHandle: DWORD): Handle {.
  stdcall, dynlib: "kernel32", importc: "GetStdHandle".}

proc GetConsoleMode(hConsoleHandle: Handle, lpMode: ptr DWORD): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "GetConsoleMode".}

proc SetConsoleMode(hConsoleHandle: Handle, dwMode: DWORD): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "SetConsoleMode".}

proc GetConsoleScreenBufferInfo(hConsoleOutput: Handle, 
                                 lpConsoleScreenBufferInfo: ptr CONSOLE_SCREEN_BUFFER_INFO): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "GetConsoleScreenBufferInfo".}

type
  TerminalState* = object
    ## Stores the original terminal state for restoration
    hStdin: Handle
    hStdout: Handle
    oldInputMode: DWORD
    oldOutputMode: DWORD
    isRawMode: bool

var globalTerminalState: TerminalState

proc setupRawMode*(): TerminalState =
  ## Configure terminal for raw mode with ANSI support
  ## Returns the terminal state for later restoration
  result.isRawMode = false
  
  # Get console handles
  result.hStdin = GetStdHandle(STD_INPUT_HANDLE.DWORD)
  result.hStdout = GetStdHandle(STD_OUTPUT_HANDLE.DWORD)
  
  # Save original modes
  discard GetConsoleMode(result.hStdin, addr result.oldInputMode)
  discard GetConsoleMode(result.hStdout, addr result.oldOutputMode)
  
  # Configure input mode:
  # - Enable virtual terminal input for ANSI escape sequences
  # - Enable window input for resize events
  # - Disable line input and echo for raw mode
  var newInputMode = ENABLE_VIRTUAL_TERMINAL_INPUT or ENABLE_WINDOW_INPUT
  discard SetConsoleMode(result.hStdin, newInputMode.DWORD)
  
  # Configure output mode:
  # - Enable virtual terminal processing for ANSI escape sequences
  # - Enable wrap at EOL
  var newOutputMode = ENABLE_VIRTUAL_TERMINAL_PROCESSING or 
                      ENABLE_WRAP_AT_EOL_OUTPUT or
                      ENABLE_PROCESSED_OUTPUT
  discard SetConsoleMode(result.hStdout, newOutputMode.DWORD)
  
  result.isRawMode = true
  globalTerminalState = result

proc restoreTerminal*(state: TerminalState) =
  ## Restore terminal to its original state
  if state.isRawMode:
    discard SetConsoleMode(state.hStdin, state.oldInputMode)
    discard SetConsoleMode(state.hStdout, state.oldOutputMode)

proc restoreTerminal*() =
  ## Restore terminal using the global state
  restoreTerminal(globalTerminalState)

proc hideCursor*() =
  ## Hide the terminal cursor using ANSI escape sequence
  ## Works on Windows 10+ with virtual terminal processing enabled
  stdout.write("\e[?25l")
  stdout.flushFile()

proc showCursor*() =
  ## Show the terminal cursor using ANSI escape sequence
  stdout.write("\e[?25h")
  stdout.flushFile()

proc clearScreen*() =
  ## Clear the entire screen and move cursor to home using ANSI
  stdout.write("\e[2J\e[H")
  stdout.flushFile()

proc enableMouseReporting*() =
  ## Enable SGR mouse reporting mode (1006)
  ## Note: Mouse input on Windows may require additional work
  stdout.write("\e[?1006h\e[?1000h")
  stdout.flushFile()

proc disableMouseReporting*() =
  ## Disable mouse reporting
  stdout.write("\e[?1006l\e[?1000l")
  stdout.flushFile()

proc enableKeyboardProtocol*() =
  ## Enable enhanced keyboard protocol (CSI u mode)
  ## Note: This may not work perfectly on all Windows terminals
  stdout.write("\e[>1u")
  stdout.flushFile()

proc disableKeyboardProtocol*() =
  ## Disable enhanced keyboard protocol
  stdout.write("\e[<u")
  stdout.flushFile()

proc getTermSize*(): (int, int) =
  ## Get the current terminal size (width, height)
  ## Returns (80, 24) as fallback if detection fails
  var info: CONSOLE_SCREEN_BUFFER_INFO
  let hStdout = GetStdHandle(STD_OUTPUT_HANDLE.DWORD)
  
  if GetConsoleScreenBufferInfo(hStdout, addr info) != 0:
    let width = info.srWindow.right - info.srWindow.left + 1
    let height = info.srWindow.bottom - info.srWindow.top + 1
    return (width.int, height.int)
  
  return (80, 24)

proc PeekConsoleInputW(hConsoleInput: Handle,
                       lpBuffer: pointer,
                       nLength: DWORD,
                       lpNumberOfEventsRead: ptr DWORD): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "PeekConsoleInputW".}

proc ReadFile(hFile: Handle,
              lpBuffer: pointer,
              nNumberOfBytesToRead: DWORD,
              lpNumberOfBytesRead: ptr DWORD,
              lpOverlapped: pointer): WINBOOL {.
  stdcall, dynlib: "kernel32", importc: "ReadFile".}

proc readInputRaw*(buffer: var openArray[char]): int =
  ## Read raw input from stdin without blocking
  ## Returns the number of bytes read, or 0 if no input available
  ## 
  ## MINIMAL IMPLEMENTATION: Uses PeekConsoleInput to check for input
  ## then ReadFile to read it without blocking indefinitely
  
  let hStdin = GetStdHandle(STD_INPUT_HANDLE.DWORD)
  var eventsRead: DWORD = 0
  
  # Peek to see if there's input available
  if PeekConsoleInputW(hStdin, nil, 0, addr eventsRead) != 0:
    if eventsRead > 0:
      # There's input available, try to read it
      var bytesRead: DWORD = 0
      if ReadFile(hStdin, addr buffer[0], DWORD(buffer.len), addr bytesRead, nil) != 0:
        return int(bytesRead)
  
  return 0

proc setupSignalHandlers*(handler: proc(sig: cint) {.noconv.}) =
  ## Set up signal handlers for graceful shutdown
  ## 
  ## MINIMAL IMPLEMENTATION: Windows signal handling is different
  ## For now, this is a stub. A full implementation would use
  ## SetConsoleCtrlHandler to handle CTRL_C_EVENT, etc.
  
  # TODO: Implement Windows-specific signal handling
  # For now, Ctrl+C will still work via default handler
  discard
