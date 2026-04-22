#!/bin/bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
APP_NAME="Property Manager"
BUNDLE_NAME="PropertyManager"
BUILD_DIR=".build"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
ICON_SOURCE="AppIcon.png"

# ── Clean previous build ──────────────────────────────────────
echo "Cleaning previous build..."
rm -rf "${APP_BUNDLE}"

# ── Generate .icns from PNG ───────────────────────────────────
if [ -f "${ICON_SOURCE}" ]; then
    echo "Generating app icon from ${ICON_SOURCE}..."
    ICONSET="AppIcon.iconset"
    rm -rf "${ICONSET}"
    mkdir -p "${ICONSET}"

    # macOS requires these exact sizes for a proper .icns
    sips -z 16 16     "${ICON_SOURCE}" --out "${ICONSET}/icon_16x16.png"      > /dev/null 2>&1
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICONSET}/icon_16x16@2x.png"   > /dev/null 2>&1
    sips -z 32 32     "${ICON_SOURCE}" --out "${ICONSET}/icon_32x32.png"      > /dev/null 2>&1
    sips -z 64 64     "${ICON_SOURCE}" --out "${ICONSET}/icon_32x32@2x.png"   > /dev/null 2>&1
    sips -z 128 128   "${ICON_SOURCE}" --out "${ICONSET}/icon_128x128.png"    > /dev/null 2>&1
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICONSET}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   "${ICON_SOURCE}" --out "${ICONSET}/icon_256x256.png"    > /dev/null 2>&1
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICONSET}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   "${ICON_SOURCE}" --out "${ICONSET}/icon_512x512.png"    > /dev/null 2>&1
    sips -z 1024 1024 "${ICON_SOURCE}" --out "${ICONSET}/icon_512x512@2x.png" > /dev/null 2>&1

    iconutil -c icns "${ICONSET}" -o AppIcon.icns
    rm -rf "${ICONSET}"
    echo "App icon generated."
else
    echo "NOTE: No ${ICON_SOURCE} found — building without a custom app icon."
    echo "      Place your logo PNG as '${ICON_SOURCE}' next to this script to add it."
fi

# ── Build with Swift Package Manager ──────────────────────────
echo "Building ${APP_NAME} (Release)..."
swift build -c release 2>&1

BINARY="${BUILD_DIR}/release/${BUNDLE_NAME}"

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: Build failed. Binary not found at ${BINARY}"
    exit 1
fi

echo "Build successful."

# ── Create .app bundle structure ──────────────────────────────
echo "Creating ${APP_BUNDLE}..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${BINARY}" "${MACOS_DIR}/${BUNDLE_NAME}"

# Copy Info.plist
cp "PropertyManager/Info.plist" "${CONTENTS}/Info.plist"

# Copy app icon if generated
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
    echo "App icon added to bundle."
fi

# Copy splash video if present
if [ -f "SplashVideo.mp4" ]; then
    cp "SplashVideo.mp4" "${RESOURCES_DIR}/SplashVideo.mp4"
    echo "Splash video added to bundle."
else
    echo "NOTE: No SplashVideo.mp4 found — building without splash video."
fi

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS}/PkgInfo"

# ── Ad-hoc code sign ─────────────────────────────────────────
echo "Code signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || {
    echo "WARNING: Code signing failed. The app may trigger Gatekeeper warnings."
}

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "============================================="
echo "  BUILD COMPLETE"
echo "  ${APP_BUNDLE} is ready."
echo "============================================="
echo ""
echo "To run:    open \"${APP_BUNDLE}\""
echo "To install: cp -R \"${APP_BUNDLE}\" /Applications/"
echo ""
echo "Default login: admin / admin123"
