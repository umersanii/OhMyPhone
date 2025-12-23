# Manual Testing Guide for OhMyPhone Daemon

## Prerequisites

- Daemon compiled and configuration ready
- `jq` for JSON parsing: `sudo apt install jq`
- `openssl` for HMAC generation (usually pre-installed)

---

## 1. Local Development Testing

### Start Daemon

```bash
cd daemon
cp deploy/config.toml.example deploy/config.toml

# Edit deploy/config.toml:
# - Set bind_address to "127.0.0.1"
# - Generate secret: openssl rand -hex 32
# - Set port to 8080

# Run daemon
RUST_LOG=info cargo run
```

You should see:
```
OhMyPhone daemon starting...
Binding to 127.0.0.1:8080
```

### Run Automated Tests

In another terminal:

```bash
# Set your secret (same as in config.toml)
export DAEMON_SECRET="your-secret-from-config"

# Run test suite
chmod +x test/api_test.sh
./test/api_test.sh
```

---

## 2. Manual API Testing

### Generate HMAC Manually

```bash
# Set variables
SECRET="your-secret-key-here"
TIMESTAMP=$(date +%s%3N)
BODY=""  # Empty for GET requests

# Generate HMAC
MESSAGE="${BODY}${TIMESTAMP}"
HMAC=$(echo -n "$MESSAGE" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

echo "Timestamp: $TIMESTAMP"
echo "HMAC: $HMAC"
```

### Test GET /status

```bash
curl -v \
  -H "X-Auth: $HMAC" \
  -H "X-Time: $TIMESTAMP" \
  http://127.0.0.1:8080/status | jq
```

Expected response:
```json
{
  "battery": 82,
  "charging": false,
  "signal_dbm": -93,
  "data": true,
  "airplane": false,
  "call_forwarding": false,
  "uptime": 93422
}
```

### Test Authentication Failure

```bash
# Invalid HMAC
curl -v \
  -H "X-Auth: invalid_hmac_here" \
  -H "X-Time: $(date +%s%3N)" \
  http://127.0.0.1:8080/status
```

Expected: `HTTP 401 Unauthorized`

### Test Timestamp Expiry

```bash
# Timestamp from 60 seconds ago
OLD_TIMESTAMP=$(($(date +%s%3N) - 60000))
OLD_HMAC=$(echo -n "$OLD_TIMESTAMP" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

curl -v \
  -H "X-Auth: $OLD_HMAC" \
  -H "X-Time: $OLD_TIMESTAMP" \
  http://127.0.0.1:8080/status
```

Expected: `HTTP 401 Unauthorized` with "Request expired"

---

## 3. On-Device Testing (Android)

### Deploy Daemon to Android

```bash
# Build for ARM64
cd daemon
cargo build --release --target aarch64-linux-android

# Or cross-compile (install target first)
rustup target add aarch64-linux-android
cargo build --release --target aarch64-linux-android

# Push to device
adb push target/aarch64-linux-android/release/ohmyphone-daemon /data/local/tmp/
adb push deploy/config.toml /data/local/tmp/ohmyphone/config.toml
adb shell chmod 755 /data/local/tmp/ohmyphone-daemon
```

### Run Daemon on Device

```bash
# Connect via ADB shell
adb shell

# Run daemon (as root)
su
cd /data/local/tmp
./ohmyphone-daemon &

# Check logs
tail -f /data/local/tmp/ohmyphone.log
```

### Test from Computer

```bash
# Get device IP (if on same WiFi)
adb shell ip addr show wlan0 | grep inet

# Set host to device IP
export DAEMON_HOST="192.168.1.xxx"
export DAEMON_PORT="8080"
export DAEMON_SECRET="your-secret"

# Run tests
./test/api_test.sh
```

---

## 4. Shell Command Verification

### Test Individual Shell Commands

On the Android device:

```bash
adb shell

# Test battery query
dumpsys battery

# Test signal strength
dumpsys telephony.registry | grep -i signal

# Test data state
settings get global mobile_data

# Test airplane mode
settings get global airplane_mode_on

# Test uptime
cat /proc/uptime
```

Compare outputs with daemon's parsed values.

---

## 5. Unit Tests

```bash
cd daemon

# Run all unit tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test test_valid_hmac

# Run auth module tests
cargo test auth::
```

---

## 6. Performance Testing

### Measure Response Time

```bash
# Install Apache Bench
sudo apt install apache2-utils

# Generate auth headers (manual for now)
SECRET="your-secret"
TIMESTAMP=$(date +%s%3N)
HMAC=$(echo -n "$TIMESTAMP" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

# Note: ab doesn't support custom headers easily, use wrk instead
```

### Using wrk for Load Testing

```bash
# Install wrk
sudo apt install wrk

# Create Lua script for auth headers
cat > auth.lua << 'EOF'
timestamp = os.time() * 1000
-- Note: HMAC calculation needs to be done externally
wrk.headers["X-Time"] = timestamp
wrk.headers["X-Auth"] = "calculated_hmac_here"
EOF

# Run load test
wrk -t4 -c100 -d30s -s auth.lua http://127.0.0.1:8080/status
```

---

## 7. Security Testing

### Test Rate Limiting (When Implemented)

```bash
# Rapid fire requests
for i in {1..100}; do
  TIMESTAMP=$(date +%s%3N)
  HMAC=$(echo -n "$TIMESTAMP" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    http://127.0.0.1:8080/status
done
```

### Test Nonce Storage Limits

```bash
# Send 1500 requests (should trigger nonce cleanup at 1000)
for i in {1..1500}; do
  TIMESTAMP=$(date +%s%3N)
  HMAC=$(echo -n "$TIMESTAMP" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')
  curl -s -o /dev/null \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    http://127.0.0.1:8080/status
  sleep 0.1
done
```

---

## 8. Troubleshooting

### Daemon Won't Start

```bash
# Check if port is in use
lsof -i :8080
netstat -tuln | grep 8080

# Check config file syntax
cat deploy/config.toml

# Run with verbose logging
RUST_LOG=debug cargo run
```

### Authentication Always Fails

```bash
# Verify secret matches
grep secret deploy/config.toml

# Check timestamp generation
date +%s%3N

# Verify HMAC calculation
echo -n "test$(date +%s%3N)" | openssl dgst -sha256 -hmac "your-secret"
```

### On Android: Permission Denied

```bash
# Ensure daemon has execute permissions
adb shell chmod 755 /data/local/tmp/ohmyphone-daemon

# Check SELinux context
adb shell ls -Z /data/local/tmp/ohmyphone-daemon

# Try running as root
adb shell
su
./ohmyphone-daemon
```

### Shell Commands Return Empty

```bash
# Check if running as root
adb shell whoami

# Test commands manually
adb shell dumpsys battery
adb shell settings get global mobile_data
```

---

## 9. Continuous Testing

Add to your development workflow:

```bash
# Pre-commit hook (.git/hooks/pre-commit)
#!/bin/bash
cd daemon
cargo test
cargo clippy -- -D warnings
```

---

## Next Steps

Once basic tests pass:
1. Implement POST `/radio/data` endpoint
2. Add tests for data toggle
3. Implement POST `/radio/airplane` endpoint
4. Add integration tests for all endpoints
5. Test on actual device with Tailscale
