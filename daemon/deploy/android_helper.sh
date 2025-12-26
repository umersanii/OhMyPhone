#!/bin/bash
# Quick Android deployment checklist and helper

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  OhMyPhone Android Deployment Helper  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check 1: ADB connection
echo -e "${BLUE}[1/8]${NC} Checking ADB connection..."
if command -v adb &> /dev/null; then
    if adb get-state &> /dev/null 2>&1; then
        echo -e "      ${GREEN}✓${NC} Device connected via ADB"
    else
        echo -e "      ${RED}✗${NC} No device connected"
        echo -e "      ${YELLOW}→${NC} Connect Android device via USB and enable USB debugging"
        exit 1
    fi
else
    echo -e "      ${RED}✗${NC} adb not installed"
    echo -e "      ${YELLOW}→${NC} Install android-tools package"
    exit 1
fi

# Check 2: Root access
echo -e "${BLUE}[2/8]${NC} Checking root access..."
if adb shell su -c "id" 2>/dev/null | grep -q "uid=0"; then
    echo -e "      ${GREEN}✓${NC} Root access available"
else
    echo -e "      ${RED}✗${NC} No root access"
    echo -e "      ${YELLOW}→${NC} Device must be rooted with Magisk"
    exit 1
fi

# Check 3: Architecture
echo -e "${BLUE}[3/8]${NC} Detecting device architecture..."
ARCH=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
echo -e "      ${GREEN}✓${NC} Architecture: ${YELLOW}$ARCH${NC}"

# Check 4: Binary exists
echo -e "${BLUE}[4/8]${NC} Checking compiled binary..."
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
        TARGET="aarch64-linux-android"
        ;;
esac

BINARY="../target/$TARGET/release/ohmyphone-daemon"
if [ -f "$BINARY" ]; then
    SIZE=$(du -h "$BINARY" | cut -f1)
    echo -e "      ${GREEN}✓${NC} Binary found (${SIZE})"
else
    echo -e "      ${RED}✗${NC} Binary not found"
    echo -e "      ${YELLOW}→${NC} Run: ./build_android.sh"
    exit 1
fi

# Check 5: Config file
echo -e "${BLUE}[5/8]${NC} Checking configuration..."
if [ -f "config.toml" ]; then
    echo -e "      ${GREEN}✓${NC} config.toml found"

    # Extract secret
    SECRET=$(grep "^secret" config.toml | cut -d'"' -f2)
    if [ "$SECRET" == "changeme123" ]; then
        echo -e "      ${YELLOW}!${NC} Warning: Using default secret!"
        echo -e "      ${YELLOW}→${NC} Change 'secret' in config.toml for production"
    fi
else
    echo -e "      ${RED}✗${NC} config.toml not found"
    echo -e "      ${YELLOW}→${NC} Copy config.toml.example to config.toml and edit it"
    exit 1
fi

# Check 6: WiFi IP
echo -e "${BLUE}[6/8]${NC} Getting device WiFi IP..."
WIFI_IP=$(adb shell ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | tr -d '\r' | head -n1)
if [ -n "$WIFI_IP" ]; then
    echo -e "      ${GREEN}✓${NC} WiFi IP: ${YELLOW}$WIFI_IP${NC}"

    # Check if config uses this IP
    CONFIG_IP=$(grep "^bind_address" config.toml | cut -d'"' -f2)
    if [ "$CONFIG_IP" != "$WIFI_IP" ]; then
        echo -e "      ${YELLOW}!${NC} Config bind_address: $CONFIG_IP"
        echo -e "      ${YELLOW}!${NC} Device WiFi IP:      $WIFI_IP"
        echo -e "      ${YELLOW}→${NC} Update bind_address in config.toml to match WiFi IP"
    fi
else
    echo -e "      ${YELLOW}!${NC} WiFi not connected"
    echo -e "      ${YELLOW}→${NC} Connect device to WiFi for testing"
fi

# Check 7: Tailscale (optional)
echo -e "${BLUE}[7/8]${NC} Checking Tailscale..."
if adb shell pm list packages | grep -q "com.tailscale.ipn"; then
    echo -e "      ${GREEN}✓${NC} Tailscale installed"
    # Try to get Tailscale IP
    TS_IP=$(adb shell ip addr show tailscale0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | tr -d '\r')
    if [ -n "$TS_IP" ]; then
        echo -e "      ${GREEN}✓${NC} Tailscale IP: ${YELLOW}$TS_IP${NC}"
    else
        echo -e "      ${YELLOW}!${NC} Tailscale not connected"
    fi
else
    echo -e "      ${YELLOW}!${NC} Tailscale not installed (optional for testing)"
fi

# Check 8: Deployment readiness
echo -e "${BLUE}[8/8]${NC} Deployment readiness..."
echo -e "      ${GREEN}✓${NC} All checks passed!"

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Ready to deploy!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""

# Offer deployment options
echo "What would you like to do?"
echo ""
echo "  1) Deploy and run manually (foreground)"
echo "  2) Deploy only (no execution)"
echo "  3) Check if daemon is already running"
echo "  4) View daemon logs"
echo "  5) Test endpoints from this machine"
echo "  6) Exit"
echo ""

read -p "Select option (1-6): " OPTION

case $OPTION in
    1)
        echo ""
        echo "Deploying daemon..."
        adb push "$BINARY" /data/local/tmp/ohmyphone-daemon
        adb shell chmod 755 /data/local/tmp/ohmyphone-daemon
        adb push config.toml /data/local/tmp/
        echo ""
        echo -e "${GREEN}✓${NC} Deployed successfully!"
        echo ""
        echo "Starting daemon in foreground..."
        echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
        echo ""
        adb shell su -c "cd /data/local/tmp && exec /data/local/tmp/ohmyphone-daemon"
        ;;
    2)
        echo ""
        echo "Deploying daemon..."
        adb push "$BINARY" /data/local/tmp/ohmyphone-daemon
        adb shell chmod 755 /data/local/tmp/ohmyphone-daemon
        adb push config.toml /data/local/tmp/
        echo ""
        echo -e "${GREEN}✓${NC} Deployed successfully!"
        echo ""
        echo "To run manually:"
        echo "  adb shell"
        echo "  su"
        echo "  cd /data/local/tmp"
        echo "  ./ohmyphone-daemon"
        ;;
    3)
        echo ""
        echo "Checking for running daemon..."
        if adb shell su -c "ps -A | grep ohmyphone-daemon" | grep -q ohmyphone; then
            echo -e "${GREEN}✓${NC} Daemon is running"
            adb shell su -c "ps -A | grep ohmyphone-daemon"
        else
            echo -e "${YELLOW}!${NC} Daemon is not running"
        fi
        ;;
    4)
        echo ""
        echo "Viewing daemon logs..."
        echo ""
        adb shell su -c "cat /data/local/tmp/ohmyphone.log 2>/dev/null || echo 'No logs found'"
        ;;
    5)
        echo ""
        echo "Testing endpoints..."
        echo ""
        if [ -n "$WIFI_IP" ]; then
            export HOST="$WIFI_IP"
            export SECRET=$(grep "^secret" config.toml | cut -d'"' -f2)

            echo "Using HOST=$HOST"
            echo "Using SECRET=$SECRET"
            echo ""

            cd ../test
            ./quick_test.sh
        else
            echo -e "${RED}✗${NC} WiFi IP not available"
        fi
        ;;
    6)
        echo ""
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo ""
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac
