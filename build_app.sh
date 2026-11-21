#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

UNIVERSAL=0
for arg in "$@"; do
    case "$arg" in
        --universal)
            UNIVERSAL=1
            ;;
        *)
            echo "❌ Unknown option: $arg (supported: --universal)" >&2
            exit 2
            ;;
    esac
done

APP_NAME="LangSwap"
APP_BUNDLE="$SCRIPT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

ICON_SOURCE="$SCRIPT_DIR/Resources/AppIcon.icns"
if [ ! -f "$ICON_SOURCE" ]; then
    echo "❌ Missing app icon: $ICON_SOURCE" >&2
    exit 1
fi

ARCH_FLAGS=(--arch arm64)
ARCH_LABEL="Apple Silicon: arm64"
if [ "$UNIVERSAL" -eq 1 ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
    ARCH_LABEL="Universal Binary: arm64 + x86_64"
fi

echo "🔨 Building ${APP_NAME} (Release ${ARCH_LABEL})..."
swift build -c release "${ARCH_FLAGS[@]}"

BIN_PATH="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)/${APP_NAME}"
if [ ! -f "$BIN_PATH" ]; then
    echo "❌ Built binary not found: $BIN_PATH" >&2
    exit 1
fi

ARCH_INFO="$(lipo -info "$BIN_PATH")"
echo "🏗️  Built binary architecture: $ARCH_INFO"
if [[ "$ARCH_INFO" != *"arm64"* ]]; then
    echo "❌ Expected arm64 architecture, got: $ARCH_INFO" >&2
    exit 1
fi
if [ "$UNIVERSAL" -eq 1 ] && [[ "$ARCH_INFO" != *"x86_64"* ]]; then
    echo "❌ Expected Universal Binary (arm64 + x86_64), got: $ARCH_INFO" >&2
    exit 1
fi

echo "📦 Packaging ${APP_BUNDLE}..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"
strip -x "$MACOS_DIR/${APP_NAME}"
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"

SIGN_IDENTITY="${LANGSWAP_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/Developer ID Application:/ {print $2; exit}' || true)"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "✍️  Signing ${APP_NAME}.app with identity: ${SIGN_IDENTITY} (Hardened Runtime + Timestamp)..."
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
    echo "✍️  Signing ${APP_NAME}.app (ad-hoc signature)..."
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "ℹ️  Note: Ad-hoc signing generates a new CDHash on each rebuild."
    echo "   If Input Monitoring was already enabled, remove & re-add LangSwap (or toggle off/on) in System Settings."
fi

codesign --verify --deep --strict "$APP_BUNDLE"
touch "$APP_BUNDLE"
echo "✅ Build complete: $APP_BUNDLE"
