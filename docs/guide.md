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

### Flutter Config (`flutter_app/lib/config.dart`)
```dart
class Config {
  static const String serverUrl = "http://100.64.0.1:8080";  // Tailscale IP
  static const String sharedSecret = "base64_encoded_32_byte_key";
  static const Duration pollInterval = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 5);
}
```

**Generate shared secret**: `openssl rand -base64 32`

---

## Testing

### Manual Testing Checklist
- [ ] Daemon survives reboot and starts automatically
- [ ] Flutter app reconnects after dumb phone reboot
- [ ] Call forwarding persists across mobile data toggle
- [ ] HMAC replay protection rejects old requests
- [ ] Battery drain < 5% per day on dumb phone (screen off)

### Integration Tests
1. Mock HTTP server for Flutter app testing
2. Daemon test suite with curl scripts (`tests/integration/`)
3. End-to-end: Real devices on WiFi

---

## Debugging

### Daemon Logs
```bash
# On dumb phone via adb
adb shell su -c "tail -f /data/local/tmp/ohmyphone.log"
```

### Flutter Debug Output
- Use `logger` package for structured logging
- Log all API requests/responses in debug mode
- Show connection status prominently in UI

---

## Security Checklist

- [ ] Daemon binds to Tailscale IP only (no `0.0.0.0`)
- [ ] HMAC authentication implemented with replay protection
- [ ] Rate limiting on API endpoints (max 10 req/min)
- [ ] Tailscale ACLs configured
- [ ] No arbitrary command execution paths
- [ ] All unnecessary system services disabled
- [ ] No Google services or Play Store on dumb phone
