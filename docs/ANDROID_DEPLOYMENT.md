# Android Deployment Guide

## Prerequisites

### On Development Machine (Linux)
- Rust with Android targets installed
- Android NDK
- `adb` (Android Debug Bridge)

### On Dumb Phone (Rooted Android)
- LineageOS or similar rooted ROM
- Magisk installed
- Root shell access via `adb shell`
- USB debugging enabled

---

## Step 1: Determine Android Architecture

Connect your Android device via USB and run:

```bash
adb shell getprop ro.product.cpu.abi
```

**Common outputs:**
- `arm64-v8a` → Use target `aarch64-linux-android`
- `armeabi-v7a` → Use target `armv7-linux-androideabi`
- `x86_64` → Use target `x86_64-linux-android` (rare, emulators)

Most modern Android phones use **arm64-v8a (aarch64)**.

---

## Step 2: Install Android Toolchain

### Install Android NDK

**Option A: Via Android Studio**
1. Install Android Studio
2. SDK Manager → SDK Tools → NDK
3. Note NDK path (e.g., `~/Android/Sdk/ndk/26.1.10909125`)

**Option B: Standalone NDK**
```bash
wget https://dl.google.com/android/repository/android-ndk-r26d-linux.zip
unzip android-ndk-r26d-linux.zip -d ~/
export ANDROID_NDK_HOME=~/android-ndk-r26d
```

### Install Rust Android Targets

```bash
# For arm64 devices (most common)
rustup target add aarch64-linux-android

# For older 32-bit ARM devices
rustup target add armv7-linux-androideabi

# For x86_64 emulators
rustup target add x86_64-linux-android
```

### Configure Cargo for Cross-Compilation

Create or edit `~/.cargo/config.toml`:

```toml
[target.aarch64-linux-android]
linker = "/path/to/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang"
ar = "/path/to/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"

[target.armv7-linux-androideabi]
linker = "/path/to/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi30-clang"
ar = "/path/to/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
```

**Replace `/path/to/android-ndk` with your actual NDK path.**

**API Level Note**: The `30` in `aarch64-linux-android30-clang` is the Android API level. Use:
- API 30 for Android 11+
- API 29 for Android 10
- API 28 for Android 9

---

## Step 3: Build for Android

### Quick Build Script

Use the provided build script:

```bash
cd daemon
./deploy/build_android.sh
```

### Manual Build (if script doesn't work)

```bash
cd daemon

# For arm64 devices
cargo build --release --target aarch64-linux-android

# Output will be at:
# target/aarch64-linux-android/release/ohmyphone-daemon
```

**Expected binary size**: ~3-5 MB (after stripping)

---

## Step 4: Configure Daemon for Android

### Edit `daemon/deploy/config.toml`

```toml
[server]
# Use WiFi IP for initial testing
bind_address = "192.168.1.100"  # Your phone's WiFi IP (check with: adb shell ip addr)
port = 8080

[security]
secret = "your-secure-secret-here-change-this"  # CHANGE THIS!
timestamp_window = 30  # seconds

[logging]
level = "info"
file = "/data/local/tmp/ohmyphone.log"
```

**To find WiFi IP on phone:**
```bash
adb shell ip addr show wlan0 | grep inet
```

---

## Step 5: Deploy to Android

### Copy Files to Phone

```bash
# Push daemon binary
adb push target/aarch64-linux-android/release/ohmyphone-daemon /data/local/tmp/
adb shell chmod 755 /data/local/tmp/ohmyphone-daemon

# Push configuration
adb push daemon/deploy/config.toml /data/local/tmp/

# Verify
adb shell ls -lh /data/local/tmp/ohmyphone*
```

---

## Step 6: Test Manual Execution

### Run Daemon Manually (Foreground)

```bash
# Start interactive shell
adb shell

# Switch to root
su

# Navigate to daemon directory
cd /data/local/tmp

# Run daemon
./ohmyphone-daemon
```

**Expected output:**
```
OhMyPhone daemon starting...
Binding to 192.168.1.100:8080
Server running on http://192.168.1.100:8080
```

**Keep this terminal open** - the daemon is running.

---

## Step 7: Test from Another Device

### From Your Development Machine (Same WiFi)

Use the existing test script with your phone's IP:

```bash
# Set environment variables
export HOST=192.168.1.100  # Your phone's WiFi IP
export SECRET=your-secure-secret-here-change-this  # Match config.toml

# Test status endpoint
cd test
./quick_test.sh

# Test radio/data endpoint
./radio_data_test.sh
```

**Expected results:**
- GET `/status` should return battery level, signal strength, etc.
- POST `/radio/data` should toggle mobile data (requires root)

---

## Step 8: Setup as Magisk Service (Auto-start)

Once manual testing works, set up the daemon to start automatically on boot.

### Install Magisk Module

```bash
# Create Magisk module directory structure
adb shell su -c "mkdir -p /data/adb/modules/ohmyphone/system/bin"

# Copy daemon to module
adb shell su -c "cp /data/local/tmp/ohmyphone-daemon /data/adb/modules/ohmyphone/system/bin/"

# Copy config
adb shell su -c "mkdir -p /data/adb/modules/ohmyphone/config"
adb shell su -c "cp /data/local/tmp/config.toml /data/adb/modules/ohmyphone/config/"

# Create module.prop
adb shell su -c "cat > /data/adb/modules/ohmyphone/module.prop << 'EOF'
id=ohmyphone
name=OhMyPhone Daemon
version=0.1.0
versionCode=1
author=YourName
description=Remote control daemon for OhMyPhone project
EOF"

# Copy service script
adb push daemon/deploy/daemon.sh /data/adb/modules/ohmyphone/service.sh
adb shell su -c "chmod 755 /data/adb/modules/ohmyphone/service.sh"
```

### Reboot and Verify

```bash
# Reboot phone
adb reboot

# Wait for phone to boot (~1 minute)
# Check if daemon is running
adb shell su -c "ps -A | grep ohmyphone"

# Check logs
adb shell su -c "cat /data/local/tmp/ohmyphone.log"
```

---

## Step 9: Setup Tailscale (Production)

### Install Tailscale on Android

1. Install Tailscale from F-Droid or Google Play
2. Authenticate to your tailnet
3. Note assigned Tailscale IP (e.g., `100.64.0.5`)

### Update Config for Tailscale

```bash
# Edit config on phone
adb shell su -c "nano /data/adb/modules/ohmyphone/config/config.toml"

# Change bind_address to Tailscale IP
[server]
bind_address = "100.64.0.5"  # Your Tailscale IP
port = 8080
```

### Restart Daemon

```bash
adb shell su -c "killall ohmyphone-daemon"
# Daemon will auto-restart via Magisk service
```

---

## Troubleshooting

### Daemon Won't Start

**Check logs:**
```bash
adb shell su -c "cat /data/local/tmp/ohmyphone.log"
```

**Common issues:**
- **Permission denied**: Binary not executable (`chmod 755`)
- **Config not found**: Ensure `config.toml` is in correct path
- **Port already in use**: Another service using port 8080
- **SELinux blocking**: `adb shell su -c "setenforce 0"` (temporary)

### Commands Not Working

**Test shell commands manually:**
```bash
adb shell su -c "svc data enable"
adb shell su -c "settings get global mobile_data"
adb shell su -c "dumpsys battery"
```

### Authentication Failing

**Verify secret matches:**
```bash
# On phone
adb shell su -c "grep secret /data/local/tmp/config.toml"

# On development machine
echo $SECRET
```

**Check timestamp sync:**
```bash
# Phone time
adb shell date +%s

# Your machine time
date +%s

# Should be within ~30 seconds
```

---

## Security Checklist

- [ ] Changed default secret in `config.toml`
- [ ] Daemon binds to Tailscale IP (not 0.0.0.0)
- [ ] Firewall blocks port 8080 from internet
- [ ] Tailscale authentication enabled on both devices
- [ ] Root access limited (no public ADB)
- [ ] Logs don't contain sensitive data

---

## ✅ Deployment Verified (Dec 23, 2025)

**Successfully deployed on rooted Android device:**
- Device: arm64-v8a architecture
- Daemon: Running as root, listening on `0.0.0.0:8080`
- Access: ADB port forwarding working (`adb forward tcp:8080 tcp:8080`)
- Tested endpoints: GET `/status` ✅ | POST `/radio/data` ✅

**Known Issues:**
- Direct WiFi access blocked by Android network policy (use ADB forward or Tailscale)
- Battery/signal values may show as `-1`/`2147483647` (needs permission investigation)
- Config must use `bind_address = "0.0.0.0"` for non-localhost access

---

## Next Steps

Once Android deployment works:
1. ✅ Test all endpoints (status ✅, radio/data ✅, radio/airplane)
2. Setup Tailscale for remote access (bypass ADB requirement)
3. Implement Flutter app
4. Test end-to-end over Tailscale
5. Monitor battery drain over 24 hours
6. Investigate shell command permissions for accurate battery/signal readings
