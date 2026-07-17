#!/bin/bash
# Builds the DocC documentation site for GitHub Pages.
#
# Both module archives are merged (docc merge) into one site with a shared
# landing page listing SwiftStash and SwiftStashUI. Layout (for
# https://tklocek.github.io/SwiftStash/):
#   <output>/documentation/                landing page (both modules)
#   <output>/documentation/swiftstash/
#   <output>/documentation/swiftstashui/
#
# Usage: Scripts/build-docs.sh [output-dir]
#   output-dir      defaults to .build/docs-site
#   DOCS_BASE_PATH  hosting base path, defaults to the repo name "SwiftStash"
#                   (set to "" when serving from a domain root)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$REPO_ROOT/.build/docs-site}"
BASE_PATH="${DOCS_BASE_PATH-SwiftStash}"
DERIVED_DATA="$REPO_ROOT/.build/docbuild"
PRODUCTS="$DERIVED_DATA/Build/Products/Debug"

rm -rf "$OUTPUT"

echo "▸ Building DocC archives (SwiftStash + SwiftStashUI)…"
xcodebuild docbuild \
    -scheme SwiftStash-Package \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet

for archive in SwiftStash SwiftStashUI; do
    test -d "$PRODUCTS/$archive.doccarchive" || {
        echo "error: $archive.doccarchive not produced by docbuild" >&2
        exit 1
    }
done

echo "▸ Merging archives into one site with a shared landing page…"
MERGED="$DERIVED_DATA/SwiftStash-combined.doccarchive"
rm -rf "$MERGED"
xcrun docc merge \
    "$PRODUCTS/SwiftStash.doccarchive" \
    "$PRODUCTS/SwiftStashUI.doccarchive" \
    --synthesized-landing-page-name SwiftStash \
    --output-path "$MERGED"

echo "▸ Transforming for static hosting…"
xcrun docc process-archive transform-for-static-hosting \
    "$MERGED" \
    --output-path "$OUTPUT" \
    --hosting-base-path "$BASE_PATH"

# DocC-Render fetches theme-settings.json from the site root at runtime; the
# merge step does not carry it over from the catalogue, so copy it explicitly.
# Colours follow Branding/BRANDING.md (Swift Orange accent, Ink/Ivory heroes).
cp "$REPO_ROOT/Sources/SwiftStash/SwiftStash.docc/theme-settings.json" "$OUTPUT/theme-settings.json"

# The DocC renderer's root index.html shows an empty shell; send visitors of
# the site root straight to the synthesized landing page instead.
cat > "$OUTPUT/index.html" <<'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=documentation/">
    <title>SwiftStash Documentation</title>
</head>
<body>
    <p>Redirecting to <a href="documentation/">SwiftStash documentation</a>…</p>
</body>
</html>
HTML

# GitHub Pages must serve DocC's underscore-free assets as-is (no Jekyll).
touch "$OUTPUT/.nojekyll"

echo "▸ Done: $OUTPUT"
echo "  Preview locally (links need an empty base path when served from a root URL):"
echo "    DOCS_BASE_PATH=\"\" Scripts/build-docs.sh"
echo "    python3 -m http.server 8000 --directory $OUTPUT"
echo "    open http://localhost:8000/"
