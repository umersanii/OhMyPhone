# Quick Start: Android Testing

## 🚀 One-Command Deployment

```bash
cd daemon/deploy
./android_helper.sh
```

This interactive script will:
- ✓ Check all prerequisites
- ✓ Detect device architecture
- ✓ Verify root access
- ✓ Guide you through deployment

---

## 📋 Manual Steps (if needed)

### 1. Connect Device
```bash
# Enable USB debugging on Android device
# Connect via USB cable

# Verify connection
adb devices
```

### 2. Build for Android
```bash
cd daemon/deploy
./build_android.sh
```

### 3. Configure
```bash
# Copy example config
cp config.toml.example config.toml

# Edit config.toml:
# - Set bind_address to device WiFi IP (get from android_helper.sh)
# - Change secret to something secure
nano config.toml
```

### 4. Deploy
```bash
# Option A: Use helper script (recommended)
./android_helper.sh

# Option B: Manual deployment
adb push ../target/aarch64-linux-android/release/ohmyphone-daemon /data/local/tmp/
adb shell chmod 755 /data/local/tmp/ohmyphone-daemon
adb push config.toml /data/local/tmp/
```

### 5. Run Daemon
```bash
# Start in foreground (for testing)
adb shell
su
cd /data/local/tmp
./ohmyphone-daemon
```

### 6. Test from Development Machine
```bash
# In another terminal
cd test

# Set your Android device's WiFi IP
export HOST=192.168.1.XXX  # From android_helper.sh
export SECRET=your-secret-from-config

# Run tests
./quick_test.sh
./radio_data_test.sh
```

---

## 🔍 Troubleshooting

### Device Not Found
```bash
# Check USB connection
adb devices

# Restart ADB server
adb kill-server
adb start-server
```

### No Root Access
```bash
# Verify Magisk is installed
adb shell su -c "id"

# Should output: uid=0(root) gid=0(root)
```

### Can't Build for Android
```bash
# Install target
rustup target add aarch64-linux-android

# Check Android NDK
echo $ANDROID_NDK_HOME

# If empty, install NDK:
# Option 1: Android Studio → SDK Manager → NDK
# Option 2: https://developer.android.com/ndk/downloads
```

### Daemon Won't Start
```bash
# Check logs
adb shell su -c "cat /data/local/tmp/ohmyphone.log"

# Test binary manually
adb shell su -c "/data/local/tmp/ohmyphone-daemon --help"

# Check SELinux (may block execution)
adb shell getenforce
# If Enforcing, temporarily disable:
adb shell su -c "setenforce 0"
```

### Authentication Fails
```bash
# Verify secret matches
adb shell su -c "grep secret /data/local/tmp/config.toml"
echo $SECRET  # Should match

# Check time sync
adb shell date +%s
date +%s
# Should be within 30 seconds
```

### Commands Not Working
```bash
# Test Android commands manually
adb shell su -c "svc data enable"
adb shell su -c "settings get global mobile_data"
adb shell su -c "dumpsys battery"
```

---

## ✅ Expected Results

### GET /status
```json
{
  "battery": 85,
  "charging": false,
  "signal_dbm": -75,
  "data": true,
  "airplane": false,
  "call_forwarding": false,
  "uptime": 123456
}
```

**Note:** Some values may show as `-1` or `2147483647` if shell commands need additional permissions.

### POST /radio/data (enable)
```json
{
  "success": true,
  "enabled": true,
  "message": "Mobile data enabled"
}
```

### POST /radio/data (disable)
```json
{
  "success": true,
  "enabled": false,
  "message": "Mobile data disabled"
}
```

---

## 🎉 Verified Working (Dec 23, 2025)

✅ **Successfully deployed and tested on rooted Android device (arm64-v8a)**

- Daemon binary: 3.9 MB (stripped)
- Network: Listening on `0.0.0.0:8080`
- Access: ADB port forwarding (`adb forward tcp:8080 tcp:8080`)
- Authentication: HMAC-SHA256 ✅
- Endpoints: `/status` ✅ | `/radio/data` ✅

---

## 📱 Next Steps After Testing

Once basic testing works:

1. **Setup Tailscale** (for remote access)
   - Install Tailscale on both phones
   - Update config.toml bind_address to Tailscale IP

2. **Install as Magisk Service** (auto-start on boot)
   - See docs/ANDROID_DEPLOYMENT.md Step 8

3. **Implement remaining endpoints**
   - POST /radio/airplane
   - POST /call/forward
   - POST /call/dial

4. **Build Flutter app**
   - Test from main phone over Tailscale

5. **Monitor battery usage**
   - Check drain over 24 hours
   - Optimize polling interval

---

## 🆘 Need Help?

- **Full guide**: `docs/ANDROID_DEPLOYMENT.md`
- **Architecture**: `README.md`
- **Setup**: `docs/guide.md`
