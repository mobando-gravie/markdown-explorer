#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: scripts/release.sh <version>  (e.g. 0.1.0)}"
TAG="v${VERSION}"
NOTES="docs/releases/${TAG}.md"
DMG_NAME="MarkdownExplorer-${TAG}.dmg"
OUT_DIR="build/release"

cd "$(git rev-parse --show-toplevel)"

# Pre-flight
[ -z "$(git status --porcelain)" ] || { echo "✗ git tree not clean — commit or stash first"; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "✗ tag $TAG already exists"; exit 1; }
[ -f "$NOTES" ] || { echo "✗ missing release notes at $NOTES"; exit 1; }
for bin in gh hdiutil xcodebuild xcodegen; do
  command -v "$bin" >/dev/null || { echo "✗ missing required tool: $bin"; exit 1; }
done

# Build
echo "→ regenerating project file"
mkdir -p "$OUT_DIR"
xcodegen generate >/dev/null

echo "→ building Release configuration"
xcodebuild -project MarkdownExplorer.xcodeproj \
  -scheme MarkdownExplorer \
  -configuration Release \
  -derivedDataPath "$OUT_DIR/derived" \
  -destination 'generic/platform=macOS' \
  build 2>&1 | tail -3

APP="$OUT_DIR/derived/Build/Products/Release/MarkdownExplorer.app"
[ -d "$APP" ] || { echo "✗ build failed: $APP not found"; exit 1; }

# Package DMG
echo "→ packaging DMG"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG_PATH="$OUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Markdown Explorer ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_PATH" >/dev/null

echo "📦 Built $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"

# Tag and push
echo "→ tagging $TAG"
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

# Create release
echo "→ creating GitHub release"
gh release create "$TAG" \
  --title "Markdown Explorer ${TAG}" \
  --notes-file "$NOTES" \
  "$DMG_PATH"

URL=$(gh release view "$TAG" --json url -q .url)
echo
echo "✅ Released $TAG"
echo "🔗 $URL"
