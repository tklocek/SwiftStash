#!/bin/bash

set -euo pipefail

DESTINATION_DIR="$HOME/Library/Developer/Xcode/Templates/File Templates/SwiftStash"

TEMPLATE_NAMES=(
    "SwiftStash Settings"
    "SwiftStash Credentials Store"
    "SwiftStash Settings View"
)

for template_name in "${TEMPLATE_NAMES[@]}"; do
    rm -rf "$DESTINATION_DIR/$template_name.xctemplate"
done

rmdir "$DESTINATION_DIR" 2>/dev/null || true

echo "Uninstalled SwiftStash Xcode file templates."
echo "Restart Xcode if it is currently running."
