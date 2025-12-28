#!/bin/bash
# OhMyPhone - SIP Testing Guide
# This script helps you test your Asterisk setup with a softphone

echo "=========================================="
echo "OhMyPhone - SIP Testing Guide"
echo "=========================================="
echo ""

# Get credentials
TAILSCALE_IP=$(ip addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
DUMB_PHONE_PASSWORD=$(grep -A 5 "^\[100\]" /etc/asterisk/sip.conf 2>/dev/null | grep "^secret=" | cut -d'=' -f2 || echo "bK0PBdm9Tt2rMOzbsfMtSdiq")
MAIN_PHONE_PASSWORD=$(grep -A 5 "^\[101\]" /etc/asterisk/sip.conf 2>/dev/null | grep "^secret=" | cut -d'=' -f2 || echo "GVUZrIWnNCpkbjLSqvJNk37p")

if [ -z "$TAILSCALE_IP" ]; then
    TAILSCALE_IP="100.122.154.96"
fi

echo "=========================================="
echo "Step 1: Install Linphone Softphone"
echo "=========================================="
echo ""
echo "On your Linux computer, run:"
echo "  sudo apt install linphone"
echo ""
echo "Or download from: https://www.linphone.org/releases/linux/app/"
echo ""
read -p "Press Enter when Linphone is installed..."

echo ""
echo "=========================================="
echo "Step 2: Configure Linphone"
echo "=========================================="
echo ""
echo "In Linphone:"
echo "  1. Click 'Use SIP Account'"
echo "  2. Enter these details:"
echo ""
echo "     Username: 101"
echo "     Password: $MAIN_PHONE_PASSWORD"
echo "     Domain: $TAILSCALE_IP"
echo "     Transport: UDP"
echo ""
echo "  3. Click 'Login'"
echo ""
read -p "Press Enter when Linphone is configured and logged in..."

echo ""
echo "=========================================="
echo "Step 3: Verify Registration"
echo "=========================================="
echo ""
echo "Checking if extension 101 is registered..."
sudo asterisk -rx "pjsip show endpoints" | grep -A 2 "101"

echo ""
echo "If you see 'Available' next to endpoint 101, registration succeeded!"
echo ""
read -p "Press Enter to continue..."

echo ""
echo "=========================================="
echo "Step 4: Test Call from Linphone"
echo "=========================================="
echo ""
echo "In Linphone:"
echo "  1. Dial: 100"
echo "  2. Press Call"
echo ""
echo "Expected result:"
echo "  - Call should ring (even though extension 100 isn't registered yet)"
echo "  - You'll see 'Unavailable' or timeout after 30 seconds"
echo "  - This is NORMAL - extension 100 (dumb phone) isn't implemented yet"
echo ""
read -p "Press Enter after testing the call..."

echo ""
echo "=========================================="
echo "Step 5: Monitor Asterisk Logs"
echo "=========================================="
echo ""
echo "Opening Asterisk logs in real-time..."
echo "Make another call from Linphone to extension 100"
echo "Press Ctrl+C to stop watching logs"
echo ""
sleep 2
sudo tail -f /var/log/asterisk/messages

