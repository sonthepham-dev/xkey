#!/bin/bash

# Update, Build, and Install XKey Script
#
# Usage: ./update_code.sh [GIT_REVISION]
#   GIT_REVISION  Optional. Set manually for testing version check (e.g. older SHA).
#                 Default: unset (build_release.sh uses merge-base with upstream main).

set -e

if [ -n "$1" ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
    export GIT_REVISION="$1"
    echo "🔧 GIT_REVISION override: $GIT_REVISION"
fi

echo "🚀 Starting XKey update process..."

# 1. Pull code from upstream main
echo "📥 Pulling latest code from upstream/main..."
git pull upstream main

# 2. Run ./build_release.sh
echo "🔨 Running build_release.sh..."
# We use the existing build script. Ensure it's executable.
chmod +x ./build_release.sh
# Disable Sparkle signing and GitHub release for local update
ENABLE_SPARKLE_SIGN=false ENABLE_GITHUB_RELEASE=false ./build_release.sh

# 3. Stop running app
echo "🛑 Stopping running instances of XKey and XKeyIM..."
killall XKey 2>/dev/null || true
killall XKeyIM 2>/dev/null || true
# Wait a moment for processes to exit
sleep 1

# 4. Copy app to application, replace current app
echo "📦 Installing XKey to /Applications..."
if [ -d "/Applications/XKey.app" ]; then
    echo "   Removing existing XKey.app..."
    rm -rf "/Applications/XKey.app"
fi

if [ -d "Release/XKey.app" ]; then
    cp -R "Release/XKey.app" "/Applications/"
    echo "✅ XKey installed successfully."
else
    echo "❌ Error: Release/XKey.app not found. Build may have failed."
    exit 1
fi

# 5. Open app
echo "🚀 Launching XKey..."
open "/Applications/XKey.app"

echo "✅ Update and installation complete!"
