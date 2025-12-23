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
- [x] GET `/status` endpoint (battery, signal, data/airplane states)
- [x] Shell executor with command whitelist
- [x] Configuration management
- [x] Module structure (`api/` and `executor/`)
- [x] Unit tests for authentication
- [x] Integration test scripts
- [x] Daemon runs successfully on development machine

### 🚧 In Progress
- [ ] POST `/radio/data` - Toggle mobile data
- [ ] POST `/radio/airplane` - Toggle airplane mode

### 📋 Todo
- [ ] POST `/call/forward` - Call forwarding control
- [ ] POST `/call/dial` - Initiate calls
- [ ] Flutter app (UI + API client)
- [ ] Integration tests with curl scripts
- [ ] Rate limiting and audit logs
- [ ] End-to-end testing
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

5. **Test connection**
   ```bash
   # From main phone (replace with dumb phone's Tailscale IP)
   curl -H "X-Auth: <hmac>" -H "X-Time: <timestamp>" http://100.x.x.x:8080/status
   ```

See [docs/guide.md](docs/guide.md) for detailed setup instructions.

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

#### POST `/radio/data` *(Coming soon)*
Toggle mobile data
```json
{ "enable": true }
```

#### POST `/radio/airplane` *(Coming soon)*
Toggle airplane mode
```json
{ "enable": false }
```

#### POST `/call/forward` *(Planned)*
Configure call forwarding
```json
{ "enable": true, "number": "+1234567890" }
```

#### POST `/call/dial` *(Planned)*
Initiate outgoing call
```json
{ "number": "+1234567890" }
```

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
