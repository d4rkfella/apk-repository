#!/bin/bash

FALLBACK_DIR="/usr/lib/jellyfin-fallback-fonts"
mkdir -p "$FALLBACK_DIR"

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

echo "📥 Downloading Noto Sans font..."

curl -L -o NotoSans-Regular.ttf "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf"

echo "🔄 Converting Noto Sans to .woff2..."
woff2_compress NotoSans-Regular.ttf || echo "❌ Failed to convert NotoSans-Regular.ttf"

echo "📦 Moving fonts to $FALLBACK_DIR"
mv -v *.woff2 "$FALLBACK_DIR" 2>/dev/null || echo "⚠️ No .woff2 files moved."

echo "🧹 Cleaning up..."
cd /
rm -rf "$TMP_DIR"

echo "✅ Done! Installed fonts in: $FALLBACK_DIR"
