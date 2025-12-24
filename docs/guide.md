# OhMyPhone Setup Guide

## Overview

**OhMyPhone** is a dual-phone relay system where a rooted Android "dumb phone" (with SIM) is controlled remotely by a Flutter app on a "main phone" (standard device, not rooted).

**Architecture**:
```
[Flutter App] ←HTTPS/HMAC→ [Control Daemon on rooted Android]
(Main Phone)                (Dumb Phone w/ SIM + GSM)
NOT rooted                  Rooted LineageOS
```

---

## Network Setup

### Development
- Both phones on same WiFi network
- Daemon binds to `192.168.x.x:8080`

### Production
- Tailscale VPN tunnel between phones
- Daemon binds to Tailscale IP `100.x.x.x:8080`

### Tailscale Configuration

1. Install Tailscale on both devices
2. Authenticate both to same tailnet
3. Note dumb phone's assigned Tailscale IP (e.g., `100.64.0.1`)
4. Configure daemon to bind to Tailscale interface
5. Flutter app connects to `http://100.64.0.1:8080`

**Firewall**: Allow only port 8080 from main phone's Tailscale IP

---

## LineageOS Hardening (Dumb Phone)

### Disable System Services
```bash
# Disable via adb (requires root)
pm disable-user --user 0 com.android.browser
pm disable-user --user 0 com.android.calendar
pm disable-user --user 0 com.android.camera2
pm disable-user --user 0 com.android.email
pm disable-user --user 0 com.android.gallery3d
pm disable-user --user 0 com.android.music
pm disable-user --user 0 com.android.deskclock
pm disable-user --user 0 com.android.soundrecorder
pm disable-user --user 0 org.lineageos.jelly
pm disable-user --user 0 org.lineageos.recorder

# Disable Google services (if present)
pm disable-user --user 0 com.google.android.gms
pm disable-user --user 0 com.google.android.gsf
pm disable-user --user 0 com.android.vending
```

### Disable Background Sync
```bash
settings put global background_data 0
settings put global airplane_mode_radios "cell,bluetooth,nfc,wimax"
settings put global wifi_sleep_policy 2  # Never sleep when plugged in
```

### System Settings Optimization
- **Location**: Off (unless needed for emergency calls)
- **Bluetooth**: Off
- **NFC**: Off
- **Auto-sync**: Off
- **Automatic updates**: Off
- **Screen brightness**: Minimum
- **Sleep timeout**: 30 seconds
- **Animations**: Off (`settings put global window_animation_scale 0`)

### Essential Apps Only
- **Keep**: Phone, Contacts, Settings, Dialer, Messaging (SMS)
- **Add**: Control daemon, Tailscale
- **Optional**: Terminal emulator (debugging)

### Battery Optimization Script
Create `daemon/deploy/optimize_battery.sh`:
```bash
#!/system/bin/sh
# Run once after LineageOS setup

settings put system haptic_feedback_enabled 0
settings put system sound_effects_enabled 0
dumpsys deviceidle enable all
settings put secure location_mode 0
echo 1 > /sys/module/printk/parameters/console_suspend
```

---

## Configuration

### Daemon Config (`daemon/deploy/config.toml`)
```toml
[server]
bind_ip = "100.64.0.1"  # Tailscale IP, or "192.168.1.100" for WiFi
port = 8080

[auth]
shared_secret = "base64_encoded_32_byte_key"
replay_window_seconds = 30

[logging]
level = "info"
path = "/data/local/tmp/ohmyphone.log"
```

### Flutter Config (via Settings UI)

The Flutter app stores configuration in persistent storage. No code changes needed!

1. **Open app** on main phone
2. **Tap settings icon** (⚙️) in app bar
3. **Configure connection**:
   - **Server URL**: `http://100.64.0.1:8080` (dumb phone's Tailscale IP)
   - **HMAC Secret**: Same value as `shared_secret` in daemon's config.toml
   - **Polling Interval**: 5-60 seconds (default: 15s)
4. **Test Connection**: Verifies connectivity before saving
5. **Tap Save**: Configuration persisted locally

**Generate shared secret**: `openssl rand -base64 32`

> **Note**: Both daemon config.toml and Flutter app must use identical HMAC secret.

See [flutter_app/README.md](../flutter_app/README.md) for Flutter-specific documentation.

---

## Testing

### Manual Testing Checklist
- [ ] Daemon survives reboot and starts automatically
- [ ] Flutter app reconnects after dumb phone reboot
- [ ] Flutter app UI displays all status indicators correctly
- [ ] Toggle controls work (data, airplane mode, call forwarding)
- [ ] Call forwarding dialog accepts and validates phone numbers
- [ ] Battery and signal indicators update in real-time
- [ ] Connection status card shows accurate state (online/offline/error)
- [ ] Settings page saves and restores configuration
- [ ] Test Connection feature validates daemon connectivity
- [ ] Pull-to-refresh manually updates status
- [ ] HMAC replay protection rejects old requests
- [ ] Battery drain < 5% per day on dumb phone (screen off)
- [ ] Main phone polling doesn't cause excessive battery drain

### Integration Tests
1. **Daemon tests**: Curl scripts in `test/` directory validate all API endpoints
2. **Flutter tests**: Mock HTTP server for unit testing API client (`flutter test`)
3. **End-to-end**: Real devices on WiFi/Tailscale
   - Deploy daemon to dumb phone
   - Install Flutter APK on main phone
   - Configure connection via Settings UI
   - Test all dashboard controls

---

## Debugging

### Daemon Logs
```bash
# On dumb phone via adb
adb shell su -c "tail -f /data/local/tmp/ohmyphone.log"
```

### Flutter Debug Output
```bash
# Run app in debug mode
cd flutter_app
flutter run

# View logs
flutter logs

# Build and check for errors
flutter analyze
flutter test
```

**App features**:
- Connection status indicator in persistent top card
- Color-coded battery and signal indicators
- Material 3 dark theme for stealth appearance
- Dialog popups for call forwarding configuration
- Developer mode info in Settings (protocol, architecture)
- Real-time status updates via configurable polling

---

## Security Checklist

- [ ] Daemon binds to Tailscale IP only (no `0.0.0.0`)
- [ ] HMAC authentication implemented with replay protection
- [ ] Rate limiting on API endpoints (max 10 req/min)
- [ ] Tailscale ACLs configured
- [ ] No arbitrary command execution paths
- [ ] All unnecessary system services disabled
- [ ] No Google services or Play Store on dumb phone
