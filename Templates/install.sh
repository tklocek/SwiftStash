#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/File Templates/SwiftStash"
DESTINATION_DIR="$HOME/Library/Developer/Xcode/Templates/File Templates/SwiftStash"

TEMPLATE_NAMES=(
    "SwiftStash Settings"
    "SwiftStash Credentials Store"
    "SwiftStash Settings View"
)

mkdir -p "$DESTINATION_DIR"

for template_name in "${TEMPLATE_NAMES[@]}"; do
    source_path="$SOURCE_DIR/$template_name.xctemplate"
    destination_path="$DESTINATION_DIR/$template_name.xctemplate"

    if [[ ! -d "$source_path" ]]; then
        echo "Missing template: $source_path" >&2
        exit 1
    fi

    rm -rf "$destination_path"
    cp -R "$source_path" "$destination_path"
done

echo "Installed SwiftStash Xcode file templates in:"
echo "$DESTINATION_DIR"
echo "Restart Xcode, then choose File > New > File and open the SwiftStash section."
