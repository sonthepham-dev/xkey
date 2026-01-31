#!/bin/bash

# Update, Build, and Install XKey Script

set -e # Exit on error

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
