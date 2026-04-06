#!/bin/bash
set -euo pipefail

APP_NAME="Property Manager"
APP_BUNDLE="${APP_NAME}.app"

# Check if built
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "App not built yet. Building now..."
    bash build.sh
fi

# Install to /Applications
echo "Installing ${APP_NAME} to /Applications..."
if [ -d "/Applications/${APP_BUNDLE}" ]; then
    echo "Removing previous installation..."
    rm -rf "/Applications/${APP_BUNDLE}"
fi

cp -R "${APP_BUNDLE}" "/Applications/${APP_BUNDLE}"

echo ""
echo "============================================="
echo "  INSTALLED"
echo "  ${APP_NAME} is now in /Applications."
echo "============================================="
echo ""
echo "You can launch it from Spotlight, Launchpad,"
echo "or the Applications folder."
echo ""
echo "Default login: admin / admin123"
