# Flutter App Setup for Tailscale

Status: connection verified over Tailscale (main phone `100.111.10.92` ↔ dumb phone `100.99.172.92`). If your tailnet IPs rotate, update the Server URL in Settings.

## Configuration

The Flutter app is pre-configured with your Tailscale settings:

- **Server URL**: `http://100.99.172.92:8080` (Dumb phone Tailscale IP)
- **Shared Secret**: `fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188`
- **Poll Interval**: 15 seconds (adjustable in app settings)

These defaults are set in `lib/config/app_config.dart` but can be changed via the app's Settings page.

## Building APK for Main Phone

### Option 1: Build APK (Recommended for testing)
```bash
cd /mnt/work/Coding/OhMyPhone/flutter_app

# Build debug APK (faster, includes debug info)
flutter build apk --debug

# Or build release APK (optimized, smaller size)
flutter build apk --release
```

APK location:
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

### Option 2: Install directly via ADB (if main phone connected)
```bash
cd /mnt/work/Coding/OhMyPhone/flutter_app

# Install to connected device
flutter install
```

### Option 3: Build split APKs (smaller downloads)
```bash
cd /mnt/work/Coding/OhMyPhone/flutter_app

# Build per-architecture APKs
flutter build apk --split-per-abi
```

Generated APKs (in `build/app/outputs/flutter-apk/`):
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM - most modern phones)
- `app-x86_64-release.apk` (x86 64-bit)

## Transfer APK to Main Phone

### Method 1: USB Transfer
```bash
# Copy APK to connected main phone
adb -s <main_phone_serial> push build/app/outputs/flutter-apk/app-release.apk /sdcard/Download/ohmyphone.apk
```

### Method 2: HTTP Server
```bash
# Serve APK over local network
cd /mnt/work/Coding/OhMyPhone/flutter_app/build/app/outputs/flutter-apk
python3 -m http.server 8000

# Then download from main phone:
# http://<your-dev-machine-ip>:8000/app-release.apk
```

### Method 3: Cloud/Email
Upload APK to Google Drive, Dropbox, or email it to yourself.

## Installation on Main Phone

1. **Enable Unknown Sources** (if needed):
   - Settings → Security → Install unknown apps
   - Enable for your file manager or browser

2. **Install APK**:
   - Open file manager
   - Navigate to Downloads
   - Tap `ohmyphone.apk`
   - Tap "Install"

3. **Grant Permissions**:
   - Storage access (for saving settings)
   - Network access (automatically granted)

## First Launch Configuration

The app comes pre-configured, but you can verify/change settings:

1. Open OhMyPhone app
2. Tap ⚙️ Settings (bottom navigation)
3. Verify:
   - **Server URL**: `http://100.99.172.92:8080`
   - **Shared Secret**: `fe0b...9188` (should be pre-filled)
   - **Poll Interval**: 15 seconds
4. Tap **Test Connection**
5. Should show "Connection successful!" ✅

## Testing Over Tailscale

### Prerequisites
- ✅ Dumb phone has Tailscale running (IP: 100.99.172.92)
- ✅ Main phone has Tailscale running (IP: 100.111.10.92)
- ✅ Daemon running on dumb phone
- ✅ Both devices on same Tailscale network

### Test Connectivity
1. Open OhMyPhone app on main phone
2. Dashboard should show:
   - 🟢 **Connected** status
   - Battery level
   - Signal strength
   - Current states (Data, Airplane, Forwarding)

3. Test controls:
   - Toggle **Mobile Data** switch
   - Toggle **Airplane Mode** switch
   - Configure **Call Forwarding**

### Troubleshooting

#### "Connection failed" error
- Ensure Tailscale is running on both devices
- Check daemon is running: `adb shell "su -c 'ps | grep ohmyphone'"`
- Verify Tailscale IPs haven't changed
- Check daemon logs: `adb shell "su -c 'cat /data/local/tmp/daemon.log'"`

#### "Authentication failed" error
- Verify secret matches in both daemon config and app
- Check device time is synchronized (HMAC uses timestamps)

#### App can't reach daemon
- Test with curl from dev machine: `curl http://100.99.172.92:8080/status`
- Ensure main phone is on Tailscale (check Tailscale app)
- Ping dumb phone: `ping 100.99.172.92` from main phone (if termux/SSH available)

## Development Testing (without building APK)

If you have Flutter installed on main phone or want to test on dev machine:

```bash
cd /mnt/work/Coding/OhMyPhone/flutter_app

# Run on connected device
flutter run

# Or run on Linux desktop (for quick testing)
flutter run -d linux
```

## Next Steps After Installation

1. ✅ Install Tailscale on main phone
2. ✅ Build and install Flutter APK
3. ✅ Open app and verify connection
4. 🧪 Test all controls (Data, Airplane, Call Forwarding)
5. 🔋 Monitor battery life on dumb phone
6. 🔒 Optional: Enable Magisk auto-start for daemon

## Security Reminders

- 🔒 Secret is embedded in APK - only share with trusted users
- 🌐 Daemon only accessible via Tailscale VPN (not public internet)
- 🔐 All requests use HMAC authentication
- ⏰ Replay protection with 30-second window
- 📱 No root required on main phone
