# VoIP Bridge Implementation Guide

> Complete guide for implementing VoIP call bridging between dumb phone (GSM) and main phone (VoIP) using Raspberry Pi as SIP server.

---

## Overview

The VoIP bridge enables incoming GSM calls on the dumb phone to be automatically answered and bridged to the main phone as VoIP calls, eliminating the need for carrier-based call forwarding and allowing the main phone to operate without a SIM card.

### Architecture

```
GSM Call → Dumb Phone → Auto-answer → SIP Client → Raspberry Pi (Asterisk) → SIP Client → Main Phone
```

**Components:**
1. **Dumb Phone**: Detects incoming calls, auto-answers, captures audio, streams to SIP
2. **Raspberry Pi**: Routes SIP calls between dumb phone (ext 100) and main phone (ext 101)
3. **Main Phone**: Receives VoIP call, displays call UI, handles audio playback

---

## 1. Raspberry Pi Setup

### Install Asterisk

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Asterisk
sudo apt install asterisk -y

# Verify installation
sudo systemctl status asterisk
```

### Configure SIP Extensions

Edit `/etc/asterisk/sip.conf`:

```ini
[general]
context=default
bindaddr=100.x.x.x  ; Your Raspberry Pi's Tailscale IP
bindport=5060
transport=udp
disallow=all
allow=ulaw
allow=alaw

[100]  ; Dumb phone
type=friend
secret=dumbphone_secret_password
host=dynamic
context=from-dumb
qualify=yes
nat=force_rport,comedia

[101]  ; Main phone
type=friend
secret=mainphone_secret_password
host=dynamic
context=from-main
qualify=yes
nat=force_rport,comedia
```

### Configure Call Routing

Edit `/etc/asterisk/extensions.conf`:

```ini
[from-dumb]
; When dumb phone calls, route to main phone (extension 101)
exten => 101,1,Dial(SIP/101,30)
exten => 101,n,Hangup()

[from-main]
; When main phone calls, route to dumb phone (extension 100)
exten => 100,1,Dial(SIP/100,30)
exten => 100,n,Hangup()
```

### Restart Asterisk

```bash
sudo systemctl restart asterisk

# Check SIP peers
sudo asterisk -rx "sip show peers"
```

---

## 2. Dumb Phone Integration (Rust Daemon)

### Add Dependencies

Add to `daemon/Cargo.toml`:

```toml
[dependencies]
# Existing dependencies...
jni = "0.21"  # For Android JNI
pjproject-sys = "0.1"  # PJSIP bindings (or use FFI directly)
```

### Project Structure

```
daemon/src/
 ├─ voip/
 │   ├─ mod.rs          # Module exports
 │   ├─ sip.rs          # PJSIP client wrapper
 │   ├─ bridge.rs       # Call detection and auto-answer
 │   └─ audio.rs        # Android audio capture/playback via JNI
```

### Call Detection (`voip/bridge.rs`)

```rust
use jni::JNIEnv;
use jni::objects::{JClass, JString};
use jni::sys::jint;

// Android TelephonyManager listener (called from Java/Kotlin)
#[no_mangle]
pub extern "C" fn Java_com_ohmyphone_CallListener_onCallStateChanged(
    env: JNIEnv,
    _class: JClass,
    state: jint,
    phone_number: JString,
) {
    match state {
        1 => {  // TelephonyManager.CALL_STATE_RINGING
            let number: String = env.get_string(phone_number)
                .expect("Invalid phone number")
                .into();
            
            log::info!("Incoming call from: {}", number);
            
            // Auto-answer the call
            auto_answer_call(&env);
            
            // Initiate SIP call to main phone
            initiate_sip_call();
        },
        2 => {  // TelephonyManager.CALL_STATE_OFFHOOK
            log::info!("Call answered, starting audio bridge");
            start_audio_bridge();
        },
        0 => {  // TelephonyManager.CALL_STATE_IDLE
            log::info!("Call ended, stopping audio bridge");
            stop_audio_bridge();
        },
        _ => {}
    }
}

fn auto_answer_call(env: &JNIEnv) {
    // Use reflection to call ITelephony.answerRingingCall()
    // Requires root permissions
    let result = std::process::Command::new("su")
        .args(["-c", "service call phone 5"])  // answerRingingCall
        .output()
        .expect("Failed to auto-answer");
    
    log::info!("Auto-answer result: {:?}", result);
}
```

### PJSIP Client (`voip/sip.rs`)

```rust
use std::ffi::CString;
use std::os::raw::c_char;

// Simplified PJSIP wrapper (use pjproject-sys or FFI)
pub struct SipClient {
    acc_id: i32,
    call_id: i32,
}

impl SipClient {
    pub fn new(server: &str, username: &str, password: &str) -> Self {
        unsafe {
            // Initialize PJSIP
            pjsua_create();
            
            let mut cfg = Default::default();
            pjsua_config_default(&mut cfg);
            pjsua_init(&cfg, std::ptr::null(), std::ptr::null());
            
            // Create UDP transport
            let mut transport_cfg = Default::default();
            pjsua_transport_config_default(&mut transport_cfg);
            pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transport_cfg, std::ptr::null_mut());
            
            // Start PJSIP
            pjsua_start();
            
            // Register account
            let uri = CString::new(format!("sip:{}@{}", username, server)).unwrap();
            let mut acc_cfg = Default::default();
            pjsua_acc_config_default(&mut acc_cfg);
            acc_cfg.id = pjstr(uri.as_ptr());
            acc_cfg.reg_uri = pjstr(CString::new(format!("sip:{}", server)).unwrap().as_ptr());
            acc_cfg.cred_count = 1;
            acc_cfg.cred_info[0].username = pjstr(CString::new(username).unwrap().as_ptr());
            acc_cfg.cred_info[0].data = pjstr(CString::new(password).unwrap().as_ptr());
            
            let mut acc_id = 0;
            pjsua_acc_add(&acc_cfg, 1, &mut acc_id);
            
            SipClient { acc_id, call_id: -1 }
        }
    }
    
    pub fn make_call(&mut self, dest: &str) {
        unsafe {
            let uri = CString::new(dest).unwrap();
            pjsua_call_make_call(self.acc_id, &pjstr(uri.as_ptr()), 0, std::ptr::null_mut(), std::ptr::null(), &mut self.call_id);
        }
    }
    
    pub fn hangup(&mut self) {
        unsafe {
            if self.call_id >= 0 {
                pjsua_call_hangup(self.call_id, 0, std::ptr::null(), std::ptr::null());
                self.call_id = -1;
            }
        }
    }
}

// Helper to convert Rust string to pjsip pj_str_t
unsafe fn pjstr(s: *const c_char) -> pj_str_t {
    pj_str_t {
        ptr: s as *mut c_char,
        slen: libc::strlen(s) as i32,
    }
}
```

### Audio Capture (`voip/audio.rs`)

```rust
use jni::JNIEnv;
use jni::objects::JObject;

pub struct AudioBridge {
    audio_record: JObject,  // Android AudioRecord
    audio_track: JObject,   // Android AudioTrack
}

impl AudioBridge {
    pub fn new(env: &JNIEnv) -> Self {
        // Create AudioRecord for capturing GSM call audio
        let audio_record = env.new_object(
            "android/media/AudioRecord",
            "(IIIII)V",
            &[
                1.into(),  // MediaRecorder.AudioSource.VOICE_CALL (requires root)
                8000.into(),  // Sample rate
                16.into(),  // AudioFormat.CHANNEL_IN_MONO
                2.into(),  // AudioFormat.ENCODING_PCM_16BIT
                8000.into(),  // Buffer size
            ],
        ).expect("Failed to create AudioRecord");
        
        // Create AudioTrack for playing SIP audio to GSM call
        let audio_track = env.new_object(
            "android/media/AudioTrack",
            "(IIIIII)V",
            &[
                0.into(),  // AudioManager.STREAM_VOICE_CALL
                8000.into(),  // Sample rate
                4.into(),  // AudioFormat.CHANNEL_OUT_MONO
                2.into(),  // AudioFormat.ENCODING_PCM_16BIT
                8000.into(),  // Buffer size
                1.into(),  // AudioTrack.MODE_STREAM
            ],
        ).expect("Failed to create AudioTrack");
        
        AudioBridge { audio_record, audio_track }
    }
    
    pub fn start(&self, env: &JNIEnv) {
        // Start recording
        env.call_method(self.audio_record, "startRecording", "()V", &[])
            .expect("Failed to start recording");
        
        // Start playback
        env.call_method(self.audio_track, "play", "()V", &[])
            .expect("Failed to start playback");
        
        // TODO: Bridge audio in separate thread
        // - Read from AudioRecord → send to PJSIP
        // - Receive from PJSIP → write to AudioTrack
    }
    
    pub fn stop(&self, env: &JNIEnv) {
        env.call_method(self.audio_record, "stop", "()V", &[]).ok();
        env.call_method(self.audio_track, "stop", "()V", &[]).ok();
    }
}
```

---

## 3. Main Phone Integration (Flutter)

### Add Dependencies

Add to `flutter_app/pubspec.yaml`:

```yaml
dependencies:
  flutter_linphone: ^0.2.0  # SIP client (or use platform channels)
```

### SIP Client (`lib/voip/sip_client.dart`)

```dart
import 'package:flutter_linphone/flutter_linphone.dart';

class SipClient {
  final FlutterLinphone _linphone = FlutterLinphone();
  
  Future<void> initialize(String server, String username, String password) async {
    await _linphone.init();
    
    // Register SIP account
    await _linphone.registerAccount(
      username: username,
      password: password,
      domain: server,
    );
    
    // Listen for incoming calls
    _linphone.onCallStateChanged.listen((state) {
      if (state == CallState.incomingReceived) {
        _showIncomingCallUI();
      }
    });
  }
  
  Future<void> answerCall() async {
    await _linphone.acceptCall();
  }
  
  Future<void> hangupCall() async {
    await _linphone.terminateCall();
  }
  
  void _showIncomingCallUI() {
    // Navigate to incoming call screen
    // See lib/ui/call.dart
  }
}
```

### Call UI (`lib/ui/call.dart`)

```dart
import 'package:flutter/material.dart';

class IncomingCallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text('Incoming Call', style: TextStyle(color: Colors.white, fontSize: 24)),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () => _rejectCall(context),
                  child: Icon(Icons.call_end),
                ),
                FloatingActionButton(
                  backgroundColor: Colors.green,
                  onPressed: () => _answerCall(context),
                  child: Icon(Icons.call),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _answerCall(BuildContext context) {
    // Call SipClient.answerCall()
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ActiveCallScreen()));
  }
  
  void _rejectCall(BuildContext context) {
    // Call SipClient.hangupCall()
    Navigator.pop(context);
  }
}
```

---

## 4. Testing

### Unit Tests

**Daemon (Rust):**
```bash
cd daemon
cargo test voip::  # Test SIP client registration
```

**Flutter:**
```bash
cd flutter_app
flutter test test/voip_test.dart  # Mock SIP server tests
```

### Integration Testing

1. **Raspberry Pi SIP Server**:
   ```bash
   # Check SIP peers are registered
   sudo asterisk -rx "sip show peers"
   # Should show ext 100 (dumb phone) and ext 101 (main phone)
   ```

2. **End-to-End Call Test**:
   - Call dumb phone's SIM number from another phone
   - Verify dumb phone auto-answers
   - Verify main phone receives VoIP call
   - Answer on main phone
   - Verify bidirectional audio works
   - Hangup from either side

---

## 5. Troubleshooting

### Audio Quality Issues

- **Latency**: Reduce by using G.711 codec (low compression)
- **Echo**: Enable echo cancellation in PJSIP config
- **Choppy audio**: Increase buffer sizes in AudioRecord/AudioTrack

### SIP Registration Fails

- Check Tailscale connectivity: `ping <raspberry_pi_tailscale_ip>`
- Verify Asterisk is listening: `sudo netstat -tulpn | grep 5060`
- Check credentials in `sip.conf` match client config

### Auto-Answer Not Working

- Verify root permissions: `su -c "id"`
- Check Android version compatibility (some ROMs block ITelephony)
- Try alternative: `am start -a android.intent.action.ANSWER`

### Main Phone Not Receiving Calls

- Check SIP client registration status
- Verify call routing in `extensions.conf`
- Check Asterisk logs: `sudo tail -f /var/log/asterisk/messages`

---

## 6. Security Considerations

- **Bind to Tailscale IP only**: Never expose SIP server to public internet
- **Strong SIP passwords**: Use 20+ character random passwords
- **Firewall rules**: Block port 5060 except from Tailscale network
- **Encrypted transport**: Consider using TLS (SIPS) for production

---

## Next Steps

1. Set up Raspberry Pi with Asterisk (Section 1)
2. Test SIP registration from a softphone (e.g., Linphone desktop)
3. Implement daemon PJSIP client (Section 2)
4. Implement Flutter SIP client (Section 3)
5. End-to-end testing with real GSM call

For questions or issues, see project README or open an issue on GitHub.
