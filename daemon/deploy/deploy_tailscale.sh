#!/bin/bash
# Deploy daemon with Tailscale configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== OhMyPhone Daemon - Tailscale Deployment ==="
echo ""

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ No Android device connected via ADB"
    echo "   Connect device and enable USB debugging"
    exit 1
fi

echo "✅ Device connected"
echo ""

# Build daemon for Android
echo "📦 Building daemon for Android (aarch64)..."
cd "$DAEMON_DIR"
export PATH="$HOME/.cargo/bin:$HOME/Android/Sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
cargo build --release --target aarch64-linux-android

if [ ! -f "target/aarch64-linux-android/release/ohmyphone-daemon" ]; then
    echo "❌ Build failed - binary not found"
    exit 1
fi

echo "✅ Build complete"
echo ""

# Stop existing daemon
echo "🛑 Stopping existing daemon..."
adb shell "su -c 'pkill -f ohmyphone-daemon'" 2>/dev/null || true
sleep 2
echo ""

# Push files to device
echo "📤 Pushing files to device..."
adb push target/aarch64-linux-android/release/ohmyphone-daemon /data/local/tmp/ohmyphone-daemon
adb push deploy/config.toml /data/local/tmp/config.toml
adb shell "su -c 'chmod 755 /data/local/tmp/ohmyphone-daemon'"
echo "✅ Files pushed"
echo ""

# Start daemon
echo "🚀 Starting daemon on Tailscale network..."
adb shell "su -c 'cd /data/local/tmp && RUST_LOG=info ./ohmyphone-daemon > daemon.log 2>&1 &'"
sleep 2
echo ""

# Verify daemon is running
echo "🔍 Verifying daemon..."
if adb shell "su -c 'ps | grep ohmyphone-daemon | grep -v grep'" | grep -q ohmyphone; then
    echo "✅ Daemon is running"
else
    echo "❌ Daemon is not running"
    echo ""
    echo "📋 Daemon logs:"
    adb shell "su -c 'cat /data/local/tmp/daemon.log'"
    exit 1
fi

# Check listening port
echo ""
echo "🌐 Checking network bindings..."
adb shell "su -c 'netstat -tuln | grep 8080'" || echo "⚠️  Port 8080 not visible in netstat (may be normal)"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Daemon Details:"
echo "   - Binding: 100.99.172.92:8080"
echo "   - Config: /data/local/tmp/config.toml"
echo "   - Binary: /data/local/tmp/ohmyphone-daemon"
echo "   - Logs: /data/local/tmp/daemon.log"
echo "   - Logs: /data/local/tmp/ohmyphone.log"
echo ""
echo "🧪 Test from Tailscale network:"
echo "   curl http://100.99.172.92:8080/status"
echo ""
echo "📱 Next step: Configure Flutter app with:"
echo "   - Server URL: http://100.99.172.92:8080"
echo "   - Secret: fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188"
