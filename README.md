# OhMyPhone

> Secure dual-phone relay system: rooted Android "dumb phone" with SIM controlled remotely by Flutter app on standard "main phone" via REST API over VPN.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Rust](https://img.shields.io/badge/rust-1.75+-orange.svg)](https://www.rust-lang.org)
[![Flutter](https://img.shields.io/badge/flutter-3.0+-blue.svg)](https://flutter.dev)

---

## Overview

**OhMyPhone** enables secure remote control of a rooted Android device (dumb phone with SIM) from a standard smartphone (main phone without SIM). Perfect for:

- **Privacy**: Keep SIM and cellular modem physically separated from your daily-use phone
- **Battery**: Main phone lasts longer without cellular radio
- **Security**: Control privileged operations without rooting your primary device
- **Flexibility**: Switch carriers/SIMs without changing main phone

### Architecture

```
┌─────────────────────┐           ┌─────────────────────┐
│   Main Phone        │  Tailscale│   Dumb Phone        │
│   (Not rooted)      │◄─────────►│   (Rooted)          │
│                     │  HMAC Auth│                     │
│  ┌───────────────┐  │           │  ┌───────────────┐  │
│  │ Flutter App   │  │           │  │ Rust Daemon   │  │
│  │ - Dashboard   │──┼───────────┼─►│ - REST API    │  │
│  │ - Controls    │  │           │  │ - Auth Layer  │  │
│  │ - HMAC Client │  │           │  │ - Shell Exec  │  │
│  └───────────────┘  │           │  └───────────────┘  │
│                     │           │                     │
│  No SIM             │           │  SIM + GSM          │
└─────────────────────┘           └─────────────────────┘
```

**Key features:**
- 🔒 HMAC-SHA256 authentication with replay protection
- 🌐 Tailscale VPN for secure communication
- 📱 Control mobile data, airplane mode, call forwarding
- 🔋 Optimized for multi-day battery life on dumb phone
- 🚫 No arbitrary shell execution (whitelist-only commands)

---

## Project Status

### ✅ Completed
- [x] Architecture documentation
- [x] Setup and deployment guide
- [x] Daemon structure (Rust)
- [x] HMAC authentication implementation
- [x] GET `/status` endpoint (battery, signal, data/airplane/forwarding states)
- [x] POST `/radio/data` - Toggle mobile data
- [x] POST `/radio/airplane` - Toggle airplane mode
- [x] POST `/call/forward` - Call forwarding control with phone number validation
- [x] POST `/call/dial` - Initiate phone calls
- [x] Shell executor with command whitelist (MMI codes via `service call phone`)
- [x] Configuration management
- [x] Module structure (`api/` and `executor/`)
- [x] Unit tests for authentication and phone number validation
- [x] Integration test scripts (data, airplane, call forwarding, call dial)
- [x] Daemon runs successfully on development machine
- [x] Local testing validated (API endpoints, validation logic, error handling)
- [x] Flutter app with Material 3 dark theme
- [x] Provider state management with auto-polling
- [x] HMAC authentication client
- [x] Dashboard with card-based UI (equal priority controls)
- [x] Settings page with connection testing
- [x] Persistent configuration storage

### 🚧 In Progress
- [ ] Android cross-compilation for daemon binary

### 📋 Todo
- [ ] Deploy daemon to Android device
- [ ] Tailscale setup for remote access (without ADB)
- [ ] Build and test Flutter APK on main phone
- [ ] Rate limiting and audit logs
- [ ] End-to-end testing over Tailscale
- [ ] Magisk service auto-start on boot
- [ ] Optional: SIP/VoIP bridge

---

## Quick Start

### Prerequisites
- Rooted Android device (dumb phone) - LineageOS recommended
- Standard Android/iOS device (main phone)
- Tailscale account

### Installation

1. **Clone repository**
   ```bash
   git clone https://github.com/yourusername/ohmyphone.git
   cd ohmyphone
   ```

2. **Configure daemon** (on dumb phone)
   ```bash
   cd daemon
   cp deploy/config.toml.example deploy/config.toml
   # Edit config.toml: set secret, bind_address (Tailscale IP)
   ```

3. **Build daemon**
   ```bash
   cargo build --release
   ```

4. **Deploy to dumb phone**
   ```bash
   adb push target/release/ohmyphone-daemon /data/local/tmp/ohmyphone/
   adb push deploy/config.toml /data/local/tmp/ohmyphone/
   adb push deploy/daemon.sh /data/adb/service.d/ohmyphone.sh
   adb shell chmod 755 /data/adb/service.d/ohmyphone.sh
   adb reboot
   ```

5. **Install Flutter app** (on main phone)
   ```bash
   cd flutter_app
   flutter pub get
   flutter build apk --release
   flutter install
   ```

6. **Configure Flutter app**
   - Open app and tap settings icon (⚙️)
   - Enter daemon URL: `http://100.x.x.x:8080` (Tailscale IP)
   - Enter HMAC secret (from config.toml)
   - Set polling interval (default: 15s)
   - Tap "Test Connection" then "Save"

See [docs/guide.md](docs/guide.md) for detailed setup instructions and [flutter_app/README.md](flutter_app/README.md) for Flutter-specific documentation.

---

## API Reference

### Authentication
All requests require HMAC-SHA256 authentication:
```
X-Auth: HMAC_SHA256(body + timestamp, secret)
X-Time: <unix_milliseconds>
```

### Endpoints

#### GET `/status`
Returns device status
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

#### POST `/radio/data`
Toggle mobile data
```json
Request: { "enable": true }
Response: {
  "success": true,
  "enabled": true,
  "message": "Mobile data enabled"
}
```

#### POST `/radio/airplane`
Toggle airplane mode
```json
Request: { "enable": false }
Response: {
  "success": true,
  "enabled": false,
  "message": "Airplane mode disabled"
}
```

#### POST `/call/forward`
Configure call forwarding
```json
Request: { "enable": true, "number": "+1234567890" }
Response: {
  "success": true,
  "enabled": true,
  "message": "Call forwarding enabled"
}
```
*Supports phone numbers with 7-15 digits, optional + prefix*

#### POST `/call/dial`
Initiate outgoing call
```json
Request: { "number": "+1234567890" }
Response: {
  "success": true,
  "message": "Dialing +1234567890"
}
```
*Validates phone number format before dialing*

---

## Security

- **Network**: Daemon binds only to Tailscale/localhost interface (never mobile data)
- **Authentication**: HMAC-SHA256 with 30-second timestamp window
- **Replay protection**: Nonce tracking prevents replay attacks
- **Command whitelist**: No arbitrary shell execution
- **Rate limiting**: *(Planned)* Prevent brute-force attacks
- **Audit logs**: All commands logged to `/data/local/tmp/ohmyphone.log`

---

## Project Structure

```
.
├── daemon/                 # Rust daemon (dumb phone)
│   ├── src/
│   │   ├── main.rs        # HTTP server
│   │   ├── auth.rs        # HMAC verification
│   │   ├── config.rs      # Configuration
│   │   ├── api/           # API endpoints
│   │   │   └── status.rs
│   │   └── executor/      # Shell command execution
│   │       └── shell.rs
│   ├── deploy/            # Deployment scripts
│   └── Cargo.toml
├── flutter_app/           # Flutter app (main phone) - Coming soon
├── docs/
│   └── guide.md          # Setup & deployment guide
└── README.md
```

---

## Development

### Build daemon
```bash
cd daemon
cargo build              # Build debug version
cargo build --release    # Build optimized version
cargo test               # Run unit tests
cargo run                # Run locally
```

### Testing
```bash
# Unit tests
cd daemon && cargo test

# Quick integration test (daemon must be running)
./test/quick_test.sh

# Full test suite
export DAEMON_SECRET="your-secret-from-config"
./test/api_test.sh
```

### Understanding the Code

New to the codebase? Start here:

1. **[Daemon Explained](docs/DAEMON_EXPLAINED.md)** - Beginner's guide with analogies
2. `daemon/src/main.rs` - Entry point, see how server starts
3. `daemon/src/api/status.rs` - Example endpoint implementation
4. `daemon/src/auth.rs` - See how security works

**Key concepts:**
- **Module structure**: `api/` for endpoints, `executor/` for shell commands
- **Authentication flow**: Request → Auth check → Execute → Response
- **Whitelist pattern**: Only predefined commands, no arbitrary execution

---

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Follow Rust coding standards
4. Add tests for new features
5. Submit a pull request

---

## License

## Documentation

- **[Setup Guide](docs/guide.md)** - Detailed installation and configuration
- **[Architecture Details](docs/ARCHITECTURE.md)** - In-depth system design and API specs
- **[Daemon Explained](docs/DAEMON_EXPLAINED.md)** - Beginner-friendly guide to understanding the daemon
- **[Testing Guide](test/manual_test.md)** - How to test locally and on Android
- **API Reference** - See above

- [Setup Guide](docs/guide.md) - Detailed installation and configuration
- [Architecture Details](docs/ARCHITECTURE.md) - In-depth system design
- API Reference - See above

---

## Roadmap

See [Project Status](#project-status) for current progress.

**Phase 1** (Current): Core daemon functionality
**Phase 2**: Flutter app development
**Phase 3**: Security hardening & testing
**Phase 4**: Optional features (SIP bridge, advanced call control)

---

## Support

For issues, questions, or feature requests, please [open an issue](https://github.com/yourusername/ohmyphone/issues).
