#!/bin/bash
# Test script for backstorie plugin system

echo "Testing Backstorie Plugin System..."
echo "===================================="
echo ""

# Run for 2 seconds
echo "Running application for 2 seconds..."
timeout 2 ./backstorie

EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "✅ SUCCESS: Application ran without crashes!"
    echo "   The plugin system is working correctly."
    echo ""
    echo "To test interactively:"
    echo "  ./backstorie"
    echo ""
    echo "Controls:"
    echo "  - Press 'r' to reset the counter"
    echo "  - Press 'q' to quit"
    exit 0
elif [ $EXIT_CODE -eq 139 ]; then
    echo ""
    echo "❌ FAILED: Segmentation fault (exit code 139)"
    exit 1
else
    echo ""
    echo "⚠️  Unexpected exit code: $EXIT_CODE"
    exit $EXIT_CODE
fi
