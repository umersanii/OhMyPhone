# OhMyPhone Flutter App

Flutter client application for controlling a rooted Android "dumb phone" running the OhMyPhone daemon.

## Features

- **Material 3 Design**: Modern dark theme with card-based layout
- **State Management**: Provider pattern for reactive state updates
- **HMAC Authentication**: Secure communication with HMAC-SHA256 + replay protection
- **Auto-Polling**: Configurable status polling (5-60 seconds)
- **Connection Monitoring**: Persistent status indicator showing connection health
- **Radio Controls**: Toggle mobile data and airplane mode
- **Call Forwarding**: Enable/disable call forwarding with number input
- **Device Status**: Real-time battery and signal strength indicators

## Architecture

```
lib/
├── api/
│   ├── client.dart        # HTTP client with HMAC auth
│   └── models.dart        # API response models
├── config/
│   └── app_config.dart    # Persistent settings storage
├── security/
│   └── hmac.dart          # HMAC-SHA256 signing
├── state/
│   └── relay_state.dart   # Provider state management
├── ui/
│   ├── dashboard.dart     # Main control interface
│   └── settings.dart      # Configuration page
└── main.dart              # App entry point
```

## Setup

### 1. Install Dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Configure Connection

On first launch:
1. Tap the settings icon (⚙️)
2. Enter your daemon's server URL (e.g., `http://100.64.1.2:8080`)
3. Enter the HMAC secret (must match `daemon/deploy/config.toml`)
4. Adjust polling interval (default: 15s)
5. Tap "Test Connection" to verify
6. Tap "Save"

### 3. Run the App

**On Android:**
```bash
flutter run
```

**Build APK:**
```bash
flutter build apk --release
```

**Install APK:**
```bash
flutter install
```

## Usage

### Dashboard

The main screen displays:
- **Connection Status Card**: Shows online/offline state and last update time
- **Mobile Data Toggle**: Enable/disable mobile data on dumb phone
- **Airplane Mode Toggle**: Enable/disable airplane mode
- **Call Forwarding**: Toggle with number input dialog
- **Battery Level**: Color-coded battery indicator
- **Signal Strength**: Color-coded signal indicator

All cards have equal visual priority. Pull down to refresh manually.

### Settings

Configure:
- **Server URL**: Tailscale IP or local address (http://...)
- **HMAC Secret**: Shared secret for authentication
- **Polling Interval**: 5-60 seconds (use slider)
- **Test Connection**: Verify connectivity before saving

## Security

- **HMAC-SHA256**: All requests signed with shared secret
- **Replay Protection**: Timestamp-based nonce system (30s window)
- **No Push Notifications**: Polling only (no Firebase/GCM)
- **VPN Recommended**: Use Tailscale for secure remote access

## API Endpoints

| Endpoint | Method | Action |
|----------|--------|--------|
| `/status` | GET | Retrieve device status |
| `/radio/data` | POST | Toggle mobile data |
| `/radio/airplane` | POST | Toggle airplane mode |
| `/call/forward` | POST | Enable/disable call forwarding |
| `/call/dial` | POST | Initiate outgoing call |

## Error Handling

- Network errors displayed in connection status card
- Failed operations show snackbar with error message
- Offline mode gracefully handled (no crashes)
- Invalid configuration detected in settings

## Developer Mode

Settings page includes:
- Protocol information (HMAC-SHA256)
- Connection type (HTTP over Tailscale)
- Architecture description
- Version information

## Dependencies

- `provider: ^6.1.1` - State management
- `http: ^1.1.0` - HTTP client
- `crypto: ^3.0.3` - HMAC signing
- `shared_preferences: ^2.2.2` - Persistent storage

## Troubleshooting

**Connection fails:**
- Verify daemon is running on dumb phone
- Check server URL format (http:// prefix required)
- Confirm HMAC secret matches `config.toml`
- Test local WiFi connection before Tailscale

**Polling not working:**
- Check poll interval in settings
- Verify app is in foreground (no background support yet)
- Restart app after changing settings

**Authentication errors:**
- Regenerate HMAC secret in both apps
- Verify system clock is synchronized
- Check for network proxy interference

## Roadmap

- [ ] Background service for polling
- [ ] Push notifications (optional)
- [ ] Call logs display
- [ ] SMS relay
- [ ] Rate limiting indicators
- [ ] Dark/light theme toggle

## License

See project root `README.md` for license information.
