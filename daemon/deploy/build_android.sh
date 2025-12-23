#!/bin/bash
# Build OhMyPhone daemon for Android

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== OhMyPhone Android Build Script ===${NC}\n"

# Detect Android architecture
echo "Detecting Android device architecture..."
if command -v adb &> /dev/null && adb get-state &> /dev/null; then
    ARCH=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
    echo -e "${GREEN}✓${NC} Detected architecture: ${YELLOW}$ARCH${NC}"

    # Map Android ABI to Rust target
    case "$ARCH" in
        arm64-v8a)
            TARGET="aarch64-linux-android"
            ;;
        armeabi-v7a)
            TARGET="armv7-linux-androideabi"
            ;;
        x86_64)
            TARGET="x86_64-linux-android"
            ;;
        *)
            echo -e "${RED}✗${NC} Unsupported architecture: $ARCH"
            echo "Defaulting to aarch64-linux-android (arm64-v8a)"
            TARGET="aarch64-linux-android"
            ;;
    esac
else
    echo -e "${YELLOW}!${NC} adb not available or no device connected"
    echo "Defaulting to aarch64-linux-android (arm64-v8a)"
    TARGET="aarch64-linux-android"
fi

echo ""

# Check if target is installed
echo "Checking Rust target: $TARGET"
if rustup target list | grep -q "$TARGET (installed)"; then
    echo -e "${GREEN}✓${NC} Target already installed"
else
    echo -e "${YELLOW}!${NC} Installing target: $TARGET"
    rustup target add "$TARGET"
fi

echo ""

# Check for Android NDK
echo "Checking Android NDK..."
if [ -z "$ANDROID_NDK_HOME" ]; then
    # Try common NDK locations
    if [ -d "$HOME/Android/Sdk/ndk" ]; then
        # Find latest NDK version
        LATEST_NDK=$(ls -1 "$HOME/Android/Sdk/ndk" | sort -V | tail -n 1)
        export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/$LATEST_NDK"
        echo -e "${GREEN}✓${NC} Found NDK: $ANDROID_NDK_HOME"
    elif [ -d "$HOME/android-ndk-r26d" ]; then
        export ANDROID_NDK_HOME="$HOME/android-ndk-r26d"
        echo -e "${GREEN}✓${NC} Found NDK: $ANDROID_NDK_HOME"
    else
        echo -e "${RED}✗${NC} Android NDK not found!"
        echo ""
        echo "Please install Android NDK:"
        echo "  Option 1: Android Studio → SDK Manager → SDK Tools → NDK"
        echo "  Option 2: Download standalone NDK from https://developer.android.com/ndk/downloads"
        echo ""
        echo "Then set ANDROID_NDK_HOME environment variable:"
        echo "  export ANDROID_NDK_HOME=/path/to/ndk"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} NDK found: $ANDROID_NDK_HOME"
fi

echo ""

# Build
echo "Building for target: $TARGET"
echo "This may take a few minutes on first build..."
echo ""

cargo build --release --target "$TARGET"

echo ""
echo -e "${GREEN}✓${NC} Build complete!"
echo ""
echo "Binary location:"
echo "  $(pwd)/target/$TARGET/release/ohmyphone-daemon"
echo ""

# Check binary size
BINARY="target/$TARGET/release/ohmyphone-daemon"
if [ -f "$BINARY" ]; then
    SIZE=$(du -h "$BINARY" | cut -f1)
    echo "Binary size: $SIZE"
    echo ""
fi

# Offer to deploy if device is connected
if command -v adb &> /dev/null && adb get-state &> /dev/null; then
    echo -e "${YELLOW}Device connected. Deploy to Android?${NC}"
    read -p "Deploy now? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Deploying to Android device..."

        # Push binary
        echo "  → Copying binary to /data/local/tmp/"
        adb push "$BINARY" /data/local/tmp/ohmyphone-daemon
        adb shell chmod 755 /data/local/tmp/ohmyphone-daemon

        # Push config if exists
        if [ -f "deploy/config.toml" ]; then
            echo "  → Copying config.toml"
            adb push deploy/config.toml /data/local/tmp/
        else
            echo -e "  ${YELLOW}!${NC} No config.toml found in deploy/"
            echo "    Copy deploy/config.toml.example to deploy/config.toml and edit it"
        fi

        echo ""
        echo -e "${GREEN}✓${NC} Deployment complete!"
        echo ""
        echo "To run the daemon:"
        echo "  adb shell"
        echo "  su"
        echo "  cd /data/local/tmp"
        echo "  ./ohmyphone-daemon"
    fi
else
    echo -e "${YELLOW}To deploy manually:${NC}"
    echo "  adb push $BINARY /data/local/tmp/ohmyphone-daemon"
    echo "  adb shell chmod 755 /data/local/tmp/ohmyphone-daemon"
    echo "  adb push deploy/config.toml /data/local/tmp/"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
