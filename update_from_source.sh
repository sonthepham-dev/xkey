#!/bin/bash

# Update from source: clone ~/.xkey from sonthepham-dev/xkey; pull latest tag from xmannv/xkey; build and relaunch.
# Used by the in-app "Cập nhật từ mã nguồn" updater.

set -e

XKEY_REPO="$HOME/.xkey"
CLONE_URL="https://github.com/sonthepham-dev/xkey.git"
UPSTREAM_URL="https://github.com/xmannv/xkey.git"

echo "🚀 Starting XKey update from source..."

if [ ! -d "$XKEY_REPO/.git" ]; then
    echo "📥 Cloning $CLONE_URL into $XKEY_REPO..."
    git clone "$CLONE_URL" "$XKEY_REPO"
fi

cd "$XKEY_REPO"

if ! git remote get-url upstream &>/dev/null; then
    echo "📎 Adding upstream remote $UPSTREAM_URL..."
    git remote add upstream "$UPSTREAM_URL"
fi

echo "📥 Fetching tags from upstream..."
git fetch upstream --tags

LATEST_TAG=$(git tag -l --sort=-v:refname 2>/dev/null | head -1)
if [ -n "$LATEST_TAG" ]; then
    echo "📌 Checking out latest tag: $LATEST_TAG"
    git checkout "$LATEST_TAG"
else
    echo "📥 No tags found, pulling origin main..."
    git pull origin main
fi

echo "🔨 Running build_release.sh..."
chmod +x ./build_release.sh
ENABLE_SPARKLE_SIGN=false ENABLE_GITHUB_RELEASE=false ./build_release.sh

echo "🛑 Stopping running instances of XKey and XKeyIM..."
killall XKey 2>/dev/null || true
killall XKeyIM 2>/dev/null || true
sleep 1

echo "📦 Installing XKey to /Applications..."
if [ -d "/Applications/XKey.app" ]; then
    rm -rf "/Applications/XKey.app"
fi

if [ -d "Release/XKey.app" ]; then
    cp -R "Release/XKey.app" "/Applications/"
    echo "✅ XKey installed successfully."
else
    echo "❌ Error: Release/XKey.app not found. Build may have failed."
    exit 1
fi

echo "🚀 Launching XKey..."
open "/Applications/XKey.app"

echo "✅ Update and installation complete!"
