#!/bin/bash
# Quick test of deployed daemon on Android device

set -e

# Use secret from config
SECRET="fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188"

# Test /status endpoint with HMAC auth
echo "Testing daemon on Android device..."
echo ""

# Get current timestamp
TIMESTAMP=$(date +%s%3N)

# Create signature (body is empty for GET requests)
SIGNATURE=$(echo -n "$TIMESTAMP" | openssl dgst -sha256 -hmac "$SECRET" -hex | cut -d' ' -f2)

echo "Sending authenticated request to /status..."
adb shell "curl -s -H 'X-Auth: $SIGNATURE' -H 'X-Time: $TIMESTAMP' http://127.0.0.1:8080/status" | jq .

echo ""
echo "✓ Daemon is running and responding!"
