#!/bin/bash

# Build Release version of XKey for local run (no signing)
# Output will be copied to ./Release/XKey.app and optionally ./Release/XKey.dmg

set -e  # Exit on error

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "📄 Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuration
ENABLE_DMG=${ENABLE_DMG:-true}  # Set to false to skip DMG creation
ENABLE_XKEYIM=${ENABLE_XKEYIM:-true}  # Set to false to skip XKeyIM build
ENABLE_XKEYIM_BUNDLE=${ENABLE_XKEYIM_BUNDLE:-true}  # Set to false to skip bundling XKeyIM inside XKey.app

BUNDLE_ID="com.codetay.XKey"
XKEYIM_BUNDLE_ID="com.codetay.inputmethod.XKey"
APP_NAME="XKey"
DMG_NAME="XKey.dmg"
DMG_VOLUME_NAME="XKey"
REPO_URL="https://github.com/xmannv/xkey"
ORIGIN_REPO_URL="https://github.com/sonthepham-dev/xkey"

# Read version from Version.xcconfig (centralized version management)
XCCONFIG_FILE="$(pwd)/Version.xcconfig"
if [ -f "$XCCONFIG_FILE" ]; then
    CURRENT_VERSION=$(grep "^MARKETING_VERSION" "$XCCONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    BUILD_NUMBER=$(grep "^CURRENT_PROJECT_VERSION" "$XCCONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    echo "📋 Version: $CURRENT_VERSION ($BUILD_NUMBER)"
    GIT_REV=""
    if [ -n "$GIT_REVISION" ]; then
        GIT_REV="$GIT_REVISION"
    else
        git fetch "$REPO_URL" main 2>/dev/null || true
        REMOTE_SHA=$(git rev-parse FETCH_HEAD 2>/dev/null) || true
        if [ -n "$REMOTE_SHA" ]; then
            GIT_REV=$(git merge-base HEAD "$REMOTE_SHA" 2>/dev/null) || true
        fi
        if [ -z "$GIT_REV" ]; then
            GIT_REV=$(git rev-parse HEAD 2>/dev/null) || true
        fi
    fi
    if [ -n "$GIT_REV" ]; then
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "s/^GIT_REVISION =.*/GIT_REVISION = $GIT_REV/" "$XCCONFIG_FILE"
        else
            sed -i '' "s/^GIT_REVISION =.*/GIT_REVISION = $GIT_REV/" "$XCCONFIG_FILE"
        fi
        [ -n "$GIT_REVISION" ] && echo "   GIT_REVISION = ${GIT_REV:0:7} (manual)" || echo "   GIT_REVISION = ${GIT_REV:0:7}"
    else
        echo "   GIT_REVISION = (not in git repo or HEAD unavailable)"
    fi
    GIT_REV_ORIGIN=""
    if git fetch "$ORIGIN_REPO_URL" main:refs/temp/origin_main 2>/dev/null; then
        REMOTE_ORIGIN_SHA=$(git rev-parse refs/temp/origin_main 2>/dev/null) || true
        git update-ref -d refs/temp/origin_main 2>/dev/null || true
        if [ -n "$REMOTE_ORIGIN_SHA" ]; then
            GIT_REV_ORIGIN=$(git merge-base HEAD "$REMOTE_ORIGIN_SHA" 2>/dev/null) || true
        fi
        if [ -z "$GIT_REV_ORIGIN" ]; then
            GIT_REV_ORIGIN=$(git rev-parse HEAD 2>/dev/null) || true
        fi
    fi
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "s/^GIT_REVISION_ORIGIN =.*/GIT_REVISION_ORIGIN = $GIT_REV_ORIGIN/" "$XCCONFIG_FILE"
    else
        sed -i '' "s/^GIT_REVISION_ORIGIN =.*/GIT_REVISION_ORIGIN = $GIT_REV_ORIGIN/" "$XCCONFIG_FILE"
    fi
    [ -n "$GIT_REV_ORIGIN" ] && echo "   GIT_REVISION_ORIGIN = ${GIT_REV_ORIGIN:0:7}" || echo "   GIT_REVISION_ORIGIN = (empty)"
else
    echo "❌ Error: Version.xcconfig not found"
    exit 1
fi
echo ""

echo "🚀 Building XKey (Release configuration)..."

echo "🔨 Local build (no signing)"
[ "$ENABLE_XKEYIM_BUNDLE" = true ] && echo "   XKeyIM bundled in XKey.app" || echo "   XKeyIM separate build"
[ "$ENABLE_DMG" = true ] && echo "   DMG will be created"
echo ""

# Create Release directory
mkdir -p Release

# Clean previous build
echo "🧹 Cleaning previous build..."
xcodebuild -project XKey.xcodeproj -scheme XKey -configuration Release -derivedDataPath ./build clean

if [ "$BUILD_UNIVERSAL" = true ]; then
    echo "🔨 Building Universal Binary (x86_64 + arm64)"
    xcodebuild -project XKey.xcodeproj \
      -scheme XKey \
      -configuration Release \
      -derivedDataPath ./build \
      -arch x86_64 -arch arm64 \
      ONLY_ACTIVE_ARCH=NO \
      PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      build
else
    echo "🔨 Building native architecture only (set BUILD_UNIVERSAL=true for x86_64+arm64)"
    echo "   Using incremental Swift compilation to avoid frontend crash (WMO)"
    xcodebuild -project XKey.xcodeproj \
      -scheme XKey \
      -configuration Release \
      -derivedDataPath ./build \
      ONLY_ACTIVE_ARCH=YES \
      SWIFT_COMPILATION_MODE=incremental \
      PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY="-" \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGNING_ALLOWED=NO \
      build
fi

# Copy to Release directory
echo "📦 Copying to ./Release/XKey.app..."
rm -rf Release/XKey.app
cp -R "./build/Build/Products/Release/XKey.app" Release/

# ============================================
# Build XKeyIM (Input Method Kit)
# ============================================
if [ "$ENABLE_XKEYIM" = true ]; then
    echo ""
    echo "🔨 Building XKeyIM (Input Method)..."
    
    # Check if XKeyIM scheme exists
    if xcodebuild -project XKey.xcodeproj -list 2>/dev/null | grep -q "XKeyIM"; then
        
        xcodebuild -project XKey.xcodeproj \
          -scheme XKeyIM \
          -configuration Release \
          -derivedDataPath ./build \
          -arch x86_64 -arch arm64 \
          ONLY_ACTIVE_ARCH=NO \
          PRODUCT_BUNDLE_IDENTIFIER="$XKEYIM_BUNDLE_ID" \
          CODE_SIGN_STYLE=Manual \
          CODE_SIGN_IDENTITY="-" \
          CODE_SIGNING_REQUIRED=NO \
          CODE_SIGNING_ALLOWED=NO \
          CODE_SIGN_ENTITLEMENTS="XKeyIM/XKeyIMRelease.entitlements" \
          PROVISIONING_PROFILE_SPECIFIER="" \
          build
        
        # Kill running XKeyIM process if it exists
        echo "🔍 Checking for running XKeyIM process..."
        if pgrep -x "XKeyIM" > /dev/null; then
            echo "⚠️  XKeyIM is currently running, killing process..."
            killall XKeyIM 2>/dev/null || true
            echo "✅ XKeyIM process killed"
            # Wait a bit to ensure process is fully terminated
            sleep 1
        else
            echo "✅ No running XKeyIM process found"
        fi
        
        # Copy XKeyIM to Release directory
        echo "📦 Copying XKeyIM.app to Release..."
        rm -rf Release/XKeyIM.app
        cp -R "./build/Build/Products/Release/XKeyIM.app" Release/

        # Ensure menu icon is present
        if [ -f "XKeyIM/MenuIcon.pdf" ]; then
            echo "📎 Adding MenuIcon.pdf to XKeyIM..."
            cp "XKeyIM/MenuIcon.pdf" "Release/XKeyIM.app/Contents/Resources/"
        fi

        # Update display name to "XKey"
        echo "📝 Updating XKeyIM display name..."
        /usr/libexec/PlistBuddy -c "Set :CFBundleName XKey" "Release/XKeyIM.app/Contents/Info.plist" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName XKey" "Release/XKeyIM.app/Contents/Info.plist" 2>/dev/null || true

        echo "✅ XKeyIM built successfully"
        
        # Embed XKeyIM inside XKey.app for easy installation (optional)
        if [ "$ENABLE_XKEYIM_BUNDLE" = true ]; then
            echo "📦 Embedding XKeyIM.app inside XKey.app/Contents/Resources..."
            mkdir -p "Release/XKey.app/Contents/Resources"
            rm -rf "Release/XKey.app/Contents/Resources/XKeyIM.app"
            cp -R "Release/XKeyIM.app" "Release/XKey.app/Contents/Resources/"
            echo "✅ XKeyIM embedded in XKey.app"
        else
            echo "⏭️  Skipping XKeyIM embedding (ENABLE_XKEYIM_BUNDLE=false)"
        fi

        
        # Auto-install XKeyIM to user's Input Methods
        echo ""
        echo "📲 Installing XKeyIM to ~/Library/Input Methods/..."
        mkdir -p ~/Library/Input\ Methods/
        
        # Kill XKeyIM process again before installing (in case it was restarted)
        if pgrep -x "XKeyIM" > /dev/null; then
            echo "🔄 Killing XKeyIM process before installation..."
            killall XKeyIM 2>/dev/null || true
            sleep 1
        fi
        
        # Copy to Input Methods
        rm -rf ~/Library/Input\ Methods/XKeyIM.app
        cp -R "Release/XKeyIM.app" ~/Library/Input\ Methods/
        echo "✅ XKeyIM installed to ~/Library/Input Methods/"
        echo "   New version will load automatically on next use"

    else
        echo "⚠️  XKeyIM target not found in Xcode project, skipping..."
    fi
fi

# ============================================
# Cleanup build folder
# ============================================
# IMPORTANT: Remove built apps from build folder to prevent LaunchServices
# from finding duplicate versions when opening XKey from XKeyIM menu
echo ""
echo "🧹 Cleaning up build folder..."
rm -rf "./build/Build/Products/Release/XKey.app"
rm -rf "./build/Build/Products/Release/XKeyIM.app"
echo "✅ Build folder cleaned (prevents duplicate app versions)"


# ============================================
# Create DMG with Applications folder symlink
# ============================================
if [ "$ENABLE_DMG" = true ]; then
    echo ""
    echo "💿 Creating DMG installer..."
    
    # Create temporary directory for DMG contents
    DMG_TEMP_DIR=$(mktemp -d)
    DMG_SOURCE_DIR="$DMG_TEMP_DIR/$DMG_VOLUME_NAME"
    mkdir -p "$DMG_SOURCE_DIR"
    
    # Copy app to temp directory
    cp -R "Release/XKey.app" "$DMG_SOURCE_DIR/"
    
    # Create symbolic link to Applications folder
    ln -s /Applications "$DMG_SOURCE_DIR/Applications"
    
    # Remove old DMG if exists
    rm -f "Release/$DMG_NAME"
    
    # Create DMG
    echo "📀 Creating DMG file..."
    hdiutil create \
        -volname "$DMG_VOLUME_NAME" \
        -srcfolder "$DMG_SOURCE_DIR" \
        -ov \
        -format UDZO \
        "Release/$DMG_NAME"
    
    # Cleanup temp directory
    rm -rf "$DMG_TEMP_DIR"
    
    echo "✅ DMG created: Release/$DMG_NAME"
fi

# ============================================
# Cleanup XKeyIM.app after bundling
# ============================================
if [ "$ENABLE_XKEYIM" = true ] && [ "$ENABLE_XKEYIM_BUNDLE" = true ] && [ -d "Release/XKeyIM.app" ]; then
    echo ""
    echo "🧹 Cleaning up XKeyIM.app (already bundled in XKey.app)..."
    rm -rf "Release/XKeyIM.app"
    echo "✅ XKeyIM.app removed"
fi

# Clear macOS launch services cache
echo ""
echo "🧹 Clearing macOS cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user

echo ""
echo "✅ Build successful!"

echo ""
echo "✅ Done! Release build is ready at:"
echo "   $(pwd)/Release/XKey.app"
if [ "$ENABLE_XKEYIM" = true ]; then
    if [ "$ENABLE_XKEYIM_BUNDLE" = true ]; then
        echo "   └── XKeyIM.app embedded in XKey.app/Contents/Resources/"
    elif [ -f "Release/XKeyIM.app" ]; then
        echo "   $(pwd)/Release/XKeyIM.app"
    fi
fi
if [ "$ENABLE_DMG" = true ]; then
    echo "   $(pwd)/Release/$DMG_NAME"
fi

echo ""
echo "📊 App size:"
du -sh Release/XKey.app
if [ "$ENABLE_XKEYIM" = true ] && [ "$ENABLE_XKEYIM_BUNDLE" = false ] && [ -f "Release/XKeyIM.app" ]; then
    du -sh Release/XKeyIM.app
fi
if [ "$ENABLE_DMG" = true ] && [ -f "Release/$DMG_NAME" ]; then
    echo ""
    echo "📀 DMG size:"
    du -sh "Release/$DMG_NAME"
fi

echo ""
echo "🏗️  Architecture:"
lipo -info Release/XKey.app/Contents/MacOS/XKey
echo ""
echo "💡 Usage:"
echo "   ./build_release.sh"
echo "   ENABLE_DMG=false              - skip DMG creation"
echo "   ENABLE_XKEYIM=false           - skip XKeyIM build"
echo "   ENABLE_XKEYIM_BUNDLE=false    - build XKeyIM separately (do not embed in XKey.app)"
echo "   BUILD_UNIVERSAL=true          - build for x86_64 + arm64 (default: native only)"


