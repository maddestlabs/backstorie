#!/bin/bash
# Backstorie WASM compiler script

VERSION="0.1.0"

show_help() {
    cat << EOF
backstorie WASM compiler v$VERSION
Compile Backstorie for web deployment

Usage: ./compile_wasm.sh [OPTIONS] [FILE]

Arguments:
  FILE                   Nim file to compile (default: index.nim)
                        Can be specified with or without .nim extension

Options:
  -h, --help            Show this help message
  -v, --version         Show version information
  -r, --release         Compile in release mode (optimized)
  -s, --serve           Start a local web server after compilation

Examples:
  ./compile_wasm.sh                          # Compile index.nim to WASM
  ./compile_wasm.sh example_boxes            # Compile example_boxes.nim to WASM
  ./compile_wasm.sh -r example_boxes         # Compile optimized
  ./compile_wasm.sh -s                       # Compile and serve

The compiled files will be placed in the web/ directory.

Requirements:
  - Nim compiler with Emscripten support
  - Emscripten SDK (emcc)

Setup Emscripten:
  git clone https://github.com/emscripten-core/emsdk.git
  cd emsdk
  ./emsdk install latest
  ./emsdk activate latest
  source ./emsdk_env.sh

EOF
}

RELEASE_MODE=""
SERVE=false
USER_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "backstorie WASM compiler version $VERSION"
            exit 0
            ;;
        -r|--release)
            RELEASE_MODE="-d:release"
            shift
            ;;
        -s|--serve)
            SERVE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            if [ -z "$USER_FILE" ]; then
                USER_FILE="$1"
            else
                echo "Error: Multiple files specified. Only one file can be compiled at a time."
                exit 1
            fi
            shift
            ;;
    esac
done

# Check for Emscripten
if ! command -v emcc &> /dev/null; then
    echo "Error: Emscripten (emcc) not found!"
    echo ""
    echo "Please install and activate Emscripten:"
    echo "  git clone https://github.com/emscripten-core/emsdk.git"
    echo "  cd emsdk"
    echo "  ./emsdk install latest"
    echo "  ./emsdk activate latest"
    echo "  source ./emsdk_env.sh"
    exit 1
fi

# Determine file to use
if [ -z "$USER_FILE" ]; then
    FILE_BASE="index"
else
    # Remove .nim extension if provided
    FILE_BASE="${USER_FILE%.nim}"
fi

# Check if file exists, try examples/ directory if not found in current location
if [ ! -f "${FILE_BASE}.nim" ]; then
    if [ ! -z "$USER_FILE" ] && [ -f "examples/${FILE_BASE}.nim" ]; then
        FILE_BASE="examples/${FILE_BASE}"
        echo "Found file in examples directory: ${FILE_BASE}.nim"
    else
        echo "Error: File not found: ${FILE_BASE}.nim"
        if [ -z "$USER_FILE" ]; then
            echo "Hint: Create an index.nim file or specify a different file to compile"
        else
            echo "Hint: File not found in current directory or examples/ directory"
        fi
        exit 1
    fi
fi

# Create web directory if it doesn't exist
mkdir -p web

echo "Compiling Backstorie to WASM with ${FILE_BASE}.nim..."
echo ""

# Nim compiler options for Emscripten
NIM_OPTS="c
  --cpu:wasm32
  --os:linux
  --cc:clang
  --clang.exe:emcc
  --clang.linkerexe:emcc
  --clang.cpp.exe:emcc
  --clang.cpp.linkerexe:emcc
  -d:emscripten
  -d:userFile=$FILE_BASE
  $RELEASE_MODE
  --nimcache:nimcache_wasm
  -o:web/backstorie.wasm.js
  backstorie.nim"

# Emscripten flags
export EMCC_CFLAGS="-s ALLOW_MEMORY_GROWTH=1 \
  -s EXPORTED_FUNCTIONS=['_malloc','_free'] \
  -s EXPORTED_RUNTIME_METHODS=['ccall','cwrap','allocateUTF8','UTF8ToString'] \
  -s MODULARIZE=0 \
  -s EXPORT_NAME='Module' \
  -s ENVIRONMENT=web \
  -s INITIAL_MEMORY=16777216"

# Compile
echo "Running Nim compiler..."
nim $NIM_OPTS

if [ $? -ne 0 ]; then
    echo ""
    echo "Compilation failed!"
    exit 1
fi

echo ""
echo "✓ Compilation successful!"
echo ""
echo "Output files:"
echo "  - web/backstorie.wasm.js"
echo "  - web/backstorie.wasm"
echo "  - web/backstorie.js (JavaScript interface)"
echo "  - web/index.html (HTML template)"
echo ""

# Copy supporting files if they don't exist
if [ ! -f "web/backstorie.js" ]; then
    echo "Warning: web/backstorie.js not found. Make sure to create the JavaScript interface."
fi

if [ ! -f "web/index.html" ]; then
    echo "Warning: web/index.html not found. Make sure to create the HTML template."
fi

# Start web server if requested
if [ "$SERVE" = true ]; then
    echo "Starting local web server..."
    echo "Open http://localhost:8000 in your browser"
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Try different server options
    if command -v python3 &> /dev/null; then
        cd web && python3 -m http.server 8000
    elif command -v python &> /dev/null; then
        cd web && python -m SimpleHTTPServer 8000
    elif command -v php &> /dev/null; then
        cd web && php -S localhost:8000
    else
        echo "Error: No web server available (tried python3, python, php)"
        echo "Please install Python or PHP, or serve the web/ directory manually."
        exit 1
    fi
else
    echo "To test the build:"
    echo "  cd web && python3 -m http.server 8000"
    echo "  Then open http://localhost:8000 in your browser"
fi
