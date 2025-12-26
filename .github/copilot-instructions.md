# OhMyPhone - Copilot Instructions

## Project Overview

Dual-phone relay system: rooted Android "dumb phone" (with SIM) controlled by Flutter app on standard "main phone" (not rooted). Secure communication over Tailscale VPN with VoIP call bridging via Raspberry Pi.

**Architecture**: Dumb phone runs Rust daemon with SIP client. Raspberry Pi runs Asterisk/FreePBX SIP server. Main phone runs Flutter app with SIP client. Calls to dumb phone's SIM are auto-answered and bridged to main phone via VoIP.

**Read `README.md` for complete architecture and API specs. Read `docs/guide.md` for setup/deployment. Read `docs/VOIP_BRIDGE.md` for VoIP implementation details.**

---

## Key Design Principles

1. **Security-first**: HMAC-SHA256 auth with replay protection. Daemon binds to Tailscale/localhost only.
2. **No arbitrary shell execution**: Static command map with validated arguments. No user-provided shell fragments.
3. **Main phone NOT rooted**: All privileged operations on dumb phone only.
4. **Polling-only**: No push notifications (no Firebase/GCM). Main phone polls daemon for status.
5. **VoIP call bridging**: Incoming GSM calls auto-answered and bridged via SIP server (no carrier forwarding).
6. **Single client**: Daemon assumes one main phone connection at a time.

**Language preferences**: Daemon = Rust > Go > Python (prototype). Flutter = Dart. SIP Server = Asterisk/FreePBX.

---

## System Architecture

```
┌─────────────────────┐    Tailscale    ┌─────────────────────┐    Tailscale    ┌─────────────────────┐
│   Dumb Phone        │◄───────────────►│   Raspberry Pi      │◄───────────────►│   Main Phone        │
│   (Rooted, SIM)     │                 │   (SIP Server)      │                 │   (No SIM)          │
│                     │                 │                     │                 │                     │
│  ┌───────────────┐  │                 │  ┌───────────────┐  │                 │  ┌───────────────┐  │
│  │ Rust Daemon   │  │                 │  │ Asterisk/     │  │                 │  │ Flutter App   │  │
│  │ - REST API    │──┼─HMAC Auth──────►│  │ FreePBX       │  │                 │  │ - Dashboard   │  │
│  │ - Auth Layer  │  │                 │  │               │  │                 │  │ - Controls    │  │
│  │ - Shell Exec  │  │                 │  │ SIP Routing   │  │                 │  │ - HMAC Client │  │
│  │ - SIP Client  │──┼─SIP (ext 100)──►│  │ - Ext 100     │◄─┼─SIP (ext 101)──│  │ - SIP Client  │  │
│  │ - Call Bridge │  │                 │  │ - Ext 101     │  │                 │  │ - Call UI     │  │
│  └───────────────┘  │                 │  └───────────────┘  │                 │  └───────────────┘  │
│                     │                 │                     │                 │                     │
│  GSM call arrives   │                 │  Routes VoIP call   │                 │  Receives VoIP call │
│  → Auto-answer      │                 │  between endpoints  │                 │  → Ring + answer    │
│  → Bridge to SIP    │                 │                     │                 │                     │
└─────────────────────┘                 └─────────────────────┘                 └─────────────────────┘
```

---

## Project Structure

### Daemon (Dumb Phone - Rust)
```
daemon/
 ├─ src/
 │   ├─ main.rs          # HTTP server setup, bind to Tailscale IP
 │   ├─ auth.rs          # HMAC-SHA256 verification, replay protection
 │   ├─ api/
 │   │   ├─ status.rs    # GET /status
 │   │   ├─ radio.rs     # POST /radio/data, /radio/airplane
 │   │   └─ call.rs      # POST /call/dial (carrier forwarding deprecated)
 │   ├─ executor/
 │   │   └─ shell.rs     # Whitelisted shell command execution
 │   ├─ voip/
 │   │   ├─ sip.rs       # PJSIP client integration
 │   │   ├─ bridge.rs    # Call auto-answer and audio bridging
 │   │   └─ audio.rs     # Android audio capture/playback
 │   ├─ state.rs         # Device state management
 │   └─ config.rs        # Load config.toml (secret, bind IP, port, SIP config)
 └─ deploy/
     ├─ daemon.sh        # Magisk service script
     └─ config.toml.example
```

### Flutter App (Main Phone)
```
flutter_app/lib/
 ├─ api/
 │   ├─ client.dart      # HTTP client with HMAC auth
 │   ├─ models.dart      # API response models
 │   └─ endpoints.dart   # Typed endpoint definitions
 ├─ state/
 │   ├─ relay_state.dart # State management (Provider/Riverpod)
 │   └─ sync.dart        # Polling logic (5-30s intervals)
 ├─ ui/
 │   ├─ dashboard.dart   # Status display
 │   ├─ controls.dart    # Radio controls
 │   ├─ call.dart        # VoIP call UI
 │   └─ settings.dart    # Configure server IP, secret, poll interval, SIP
 ├─ security/
 │   └─ hmac.dart        # HMAC-SHA256 signing
 └─ voip/
     ├─ sip_client.dart  # SIP client (flutter_linphone or native bridge)
     └─ call_manager.dart # Call state management
```

### Raspberry Pi (SIP Server)
```
/etc/asterisk/
 ├─ sip.conf            # SIP peer configuration (ext 100, 101)
 ├─ extensions.conf     # Call routing rules
 └─ pjsip.conf          # PJSIP transport configuration (Tailscale IP)
```

---

## REST API Reference

**Authentication**: All requests include `X-Auth: HMAC_SHA256(body+timestamp, secret)` and `X-Time: <unix_ms>`

**Endpoints** (see `README.md` for full specs):
- `GET /status` → battery, signal, data/airplane states
- `POST /radio/data` → `svc data {enable|disable}`
- `POST /radio/airplane` → `cmd connectivity airplane-mode {enable|disable}`
- `POST /call/dial` → `am start -a android.intent.action.CALL`
- ~~`POST /call/forward`~~ → **DEPRECATED** (replaced by VoIP bridge)

**VoIP Bridge** (handled by SIP client, not REST API):
- Incoming GSM calls detected via `TelephonyManager`
- Auto-answer via `ITelephony.answerRingingCall()`
- Audio bridged to SIP extension 100
- Main phone receives call on SIP extension 101

---

## Shell Executor Pattern

**Critical**: Commands are whitelisted and hardcoded. No string interpolation.

```rust
// Example
match cmd {
  EnableData => exec("svc data enable"),
  DisableData => exec("svc data disable"),
  // NO user input in shell commands
}
```

**Rules**:
- Command map is static (enum-based)
- Arguments validated against expected types
- Never concatenate user input into shell strings

---

## VoIP Bridge Implementation

### Call Flow

1. **Incoming GSM call** → `TelephonyManager.EXTRA_STATE_RINGING`
2. **Daemon detects** → Call listener in `voip/bridge.rs`
3. **Auto-answer** → `ITelephony.answerRingingCall()` (requires root)
4. **Audio capture** → Android `AudioRecord` API (requires `MODIFY_AUDIO_SETTINGS`)
5. **SIP call** → PJSIP client dials extension 101 via Asterisk
6. **Audio stream** → RTP packets to Raspberry Pi
7. **Asterisk routes** → Call to extension 101 (main phone)
8. **Main phone rings** → SIP client receives call, displays UI
9. **Bidirectional audio** → GSM ↔ SIP bridge active
10. **Hangup** → Either side terminates, both calls end

### Audio Routing (Android)

```rust
// Capture call audio
AudioRecord::new(
    MediaRecorder.AudioSource.VOICE_CALL,  // Requires root
    sample_rate: 8000,
    channel: AudioFormat.CHANNEL_IN_MONO,
    format: AudioFormat.ENCODING_PCM_16BIT
)

// Playback from SIP
AudioTrack::new(
    AudioManager.STREAM_VOICE_CALL,
    sample_rate: 8000,
    channel: AudioFormat.CHANNEL_OUT_MONO,
    format: AudioFormat.ENCODING_PCM_16BIT
)
```

### PJSIP Integration (Rust)

Use `pjproject-rs` or FFI bindings to `pjsip`:

```rust
// Initialize PJSIP
pjsua_create();
pjsua_init(&cfg, &log_cfg, &media_cfg);
pjsua_transport_create(PJSIP_TRANSPORT_UDP, &cfg);
pjsua_start();

// Register to Asterisk
pjsua_acc_add(&acc_cfg, PJ_TRUE, &acc_id);

// Make call when GSM rings
pjsua_call_make_call(acc_id, &dest_uri, 0, NULL, NULL, &call_id);

// Stream audio
// Bridge AudioRecord → PJSIP media stream
// Bridge PJSIP media stream → AudioTrack
```

---

## Code Generation Rules

### Daemon (Rust)
- Use `actix-web` or `axum` for HTTP server
- Bind to Tailscale IP from config (not `0.0.0.0`)
- HMAC verification on every endpoint (check timestamp within 30s window, track nonces)
- Shell executor uses `std::process::Command` with static paths
- **VoIP**: Use `pjproject-rs` or FFI to PJSIP for SIP client
- **Audio**: Use JNI to access Android `AudioRecord`/`AudioTrack` APIs
- Log to `/data/local/tmp/ohmyphone.log`
- Unit tests: HMAC verification, command whitelisting, replay protection, SIP registration

### Flutter App (Dart)
- Use `Provider` or `Riverpod` for state management
- HTTP client: `http` package with custom HMAC signing
- Poll daemon every 5-30s (configurable), no push notifications
- **VoIP**: Use `flutter_linphone` or native platform channels for SIP
- Display connection status prominently (online/offline, last successful poll)
- **Call UI**: Incoming call screen with answer/reject, active call controls
- Store config in `lib/config.dart` (server URL, secret, timeouts, SIP credentials)
- Unit tests: HMAC signing, API client error handling, state updates, SIP client

### Raspberry Pi (Asterisk)
- Install Asterisk or FreePBX
- Configure SIP extensions: 100 (dumb phone), 101 (main phone)
- Bind to Tailscale IP only (security)
- Set up call routing: extension 100 → extension 101
- Enable RTP for audio streaming
- Configure codecs: G.711 (ulaw/alaw) for compatibility

### Testing Strategy
- Daemon: Unit tests for auth, shell executor, SIP client; integration tests with curl scripts
- Flutter: Mock HTTP server for unit tests; mock SIP server for call tests
- VoIP: End-to-end call test (dumb phone → Raspberry Pi → main phone)

---

## Critical Constraints

- ❌ Don't allow user-provided strings in shell commands
- ❌ Don't skip HMAC validation on any endpoint
- ❌ Don't use push notifications (polling only for status, SIP for calls)
- ❌ Don't assume main phone is rooted (it's not)
- ❌ Don't expose daemon on mobile data interface (Tailscale/WiFi only)
- ❌ Don't hardcode IPs/secrets in code (use config files)
- ❌ Don't use carrier call forwarding (VoIP bridge only)
- ❌ Don't skip audio permission checks (root required for VOICE_CALL source)

---

## Modular Development Order

1. ~~Implement daemon `GET /status` (battery, signal from shell commands)~~ ✅
2. ~~Add `POST /radio/data` toggle~~ ✅
3. ~~Add `POST /call/dial`~~ ✅
4. ~~Build Flutter dashboard (display status, send commands)~~ ✅
5. **Set up Raspberry Pi with Asterisk/FreePBX** (SIP server)
6. **Implement PJSIP client in daemon** (SIP registration, call handling)
7. **Implement call auto-answer and audio bridge** (GSM → SIP)
8. **Add SIP client to Flutter app** (receive VoIP calls)
9. **Build call UI in Flutter** (incoming call screen, active call controls)
10. **End-to-end testing** (GSM call → VoIP bridge → main phone)
11. Harden security (rate limiting, audit logs)
12. Optional: Call recording, voicemail integration

**Do not combine steps** — implement and test incrementally.

---

**For setup/deployment instructions, see `docs/guide.md`. For full architecture, see `README.md`. For VoIP bridge implementation, see `docs/VOIP_BRIDGE.md`.**
