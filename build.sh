#!/bin/bash
# Build script for focus-display-on-cursor

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/focus-display-on-cursor.swift"
OUTPUT_FILE="$SCRIPT_DIR/focus-display-on-cursor"

echo "Building focus-display-on-cursor..."
echo "Source: $SOURCE_FILE"
echo "Output: $OUTPUT_FILE"
echo

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file not found: $SOURCE_FILE"
    exit 1
fi

# Check if Swift compiler is available
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found. Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Compile the Swift script
swiftc -O -o "$OUTPUT_FILE" "$SOURCE_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    echo "Binary: $OUTPUT_FILE"
    chmod +x "$OUTPUT_FILE"
else
    echo "✗ Build failed!"
    exit 1
fi
