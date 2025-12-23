# Call Forwarding Module - Implementation Complete ✅

**Date**: December 23, 2025  
**Module**: POST `/call/forward` - Call forwarding control  
**Status**: Implementation complete, ready for Android testing

---

## Summary

Implemented call forwarding control functionality as Module 3 of the OhMyPhone project. The daemon can now enable/disable call forwarding on the rooted Android device via the `service call phone` interface.

---

## Implementation Details

### 1. API Endpoint: `/call/forward` (POST)

**File**: `daemon/src/api/call.rs`

**Request Format**:
```json
{
  "enable": true,
  "number": "+1234567890"  // Required when enabling, optional when disabling
}
```

**Response Format**:
```json
{
  "success": true,
  "enabled": true,
  "message": "Call forwarding enabled"
}
```

**Features**:
- ✅ HMAC-SHA256 authentication with replay protection
- ✅ Phone number validation (7-15 digits, optional + prefix)
- ✅ Requires number when enabling forwarding
- ✅ Returns clear error messages for invalid requests
- ✅ No arbitrary string execution - validated inputs only

**Validation Rules**:
- Number must start with `+` or digit
- Must contain 7-15 digits total
- No special characters except leading `+`
- Examples: `+1234567890`, `9876543210`, `+919876543210`

---

### 2. Shell Executor Commands

**File**: `daemon/src/executor/shell.rs`

Added three new commands to the whitelist:

```rust
pub enum ShellCommand {
    // ... existing commands ...
    EnableCallForwarding(String),
    DisableCallForwarding,
    GetCallForwardingState,
}
```

**Enable Call Forwarding**:
```bash
service call phone 14 i32 1 s16 "*21*+1234567890#"
```
- Uses Android IPhoneInterface (code 14 = setCallForward)
- MMI code `*21*NUMBER#` unconditionally forwards all calls
- Number is validated before execution (no injection risk)

**Disable Call Forwarding**:
```bash
service call phone 14 i32 1 s16 "#21#"
```
- MMI code `#21#` disables call forwarding
- No user input required

**Get Call Forwarding State**:
```bash
service call phone 13 i32 1 i32 0
```
- Queries current forwarding status (code 13 = getCallForwardingOption)
- Used by `/status` endpoint to report state

---

### 3. Status Endpoint Update

**File**: `daemon/src/api/status.rs`

Updated `GET /status` to include call forwarding state:

```json
{
  "battery": 82,
  "charging": false,
  "signal_dbm": -93,
  "data": true,
  "airplane": false,
  "call_forwarding": true,  // <-- New field
  "uptime": 93422
}
```

**Implementation**:
- Calls `ShellCommand::GetCallForwardingState`
- Parses parcel output (heuristic: >50 chars indicates active forwarding)
- Note: Parsing may need device-specific tuning during Android testing

---

### 4. Integration Test Script

**File**: `test/call_forward_test.sh`

Comprehensive test suite with 6 test cases:

1. ✅ **Enable call forwarding** - Valid number
2. ✅ **Check status** - Verify state in `/status` response
3. ✅ **Disable call forwarding** - Remove forwarding
4. ✅ **Missing number** - Should return 400 Bad Request
5. ✅ **Invalid number format** - Should return 400 Bad Request
6. ✅ **Invalid authentication** - Should return 401 Unauthorized

**Usage**:
```bash
# Set secret to match daemon config
export SECRET="fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188"

# Run tests against local daemon
cd test && bash call_forward_test.sh

# Or test on Android via ADB port forwarding
export HOST="127.0.0.1"
export PORT="8080"
bash call_forward_test.sh
```

---

## Security Analysis

### ✅ No Arbitrary Execution
- Phone number validated with strict regex
- Only digits and optional leading `+` allowed
- Length restricted to 7-15 digits
- Validated **before** passing to shell executor

### ✅ HMAC Authentication
- All requests require valid HMAC signature
- Timestamp window: 30 seconds
- Replay protection via nonce tracking

### ✅ Command Whitelist
- `EnableCallForwarding` takes validated String parameter
- No shell metacharacters possible in validated number
- Uses `Command::new().args()` (safe argument passing, not shell interpolation)

### ✅ Error Handling
- Invalid requests return 400 with descriptive message
- Authentication failures return 401
- Shell execution errors return 500 with error message

---

## Android Deployment Steps

### 1. Build for Android
```bash
cd daemon
./deploy/build_android.sh
```

### 2. Deploy to Device
```bash
# Push binary and config
adb push target/aarch64-linux-android/release/ohmyphone-daemon /data/local/tmp/
adb push deploy/config.toml /data/local/tmp/
adb shell chmod +x /data/local/tmp/ohmyphone-daemon

# Start daemon
adb shell "su -c '/data/local/tmp/ohmyphone-daemon'"
```

### 3. Test via ADB Port Forwarding
```bash
# Forward port 8080 from Android to localhost
adb forward tcp:8080 tcp:8080

# Run test script
cd test
export SECRET="<your-secret-from-config>"
bash call_forward_test.sh
```

### 4. Verify Call Forwarding
**Important**: Test with actual phone calls to verify MMI codes work on your device!

```bash
# Enable forwarding to test number
curl -X POST http://127.0.0.1:8080/call/forward \
  -H "Content-Type: application/json" \
  -H "X-Auth: <hmac>" \
  -H "X-Time: <timestamp>" \
  -d '{"enable":true,"number":"+15551234567"}'

# Make test call to dumb phone
# Verify it forwards to +15551234567

# Disable forwarding
curl -X POST http://127.0.0.1:8080/call/forward \
  -H "Content-Type: application/json" \
  -H "X-Auth: <hmac>" \
  -H "X-Time: <timestamp>" \
  -d '{"enable":false}'

# Make another test call
# Verify it rings on dumb phone (not forwarded)
```

---

## Known Limitations

1. **Call Forwarding State Detection**:
   - Current implementation uses heuristic (output length >50 chars)
   - May need device-specific tuning
   - Some carriers may not support query via `service call phone 13`
   - Alternative: Track state in daemon memory

2. **MMI Code Compatibility**:
   - `*21*` is standard GSM but may vary by carrier
   - Some carriers use different codes (e.g., `*72*` in US)
   - May need carrier-specific configuration in future

3. **No Number Validation Against Carrier**:
   - Daemon validates format only
   - Doesn't check if number is valid with carrier
   - Invalid numbers may be accepted but not forward calls

---

## Testing Checklist

### Development (Local)
- [x] Code compiles without errors
- [x] API endpoint responds to requests
- [x] Phone number validation works
- [x] HMAC authentication enforced
- [x] Error messages are clear

### Android (Next Step)
- [ ] Binary runs on rooted Android device
- [ ] `service call phone 14` successfully sets forwarding
- [ ] `service call phone 14` successfully disables forwarding
- [ ] Actual phone calls forward to specified number
- [ ] `/status` endpoint correctly reports forwarding state
- [ ] Forwarding persists across daemon restarts (carrier-side)

---

## Files Modified/Created

```
daemon/src/api/call.rs              # New - Call forwarding API endpoint
daemon/src/api/mod.rs               # Modified - Register call module
daemon/src/api/status.rs            # Modified - Add call_forwarding field
daemon/src/executor/shell.rs        # Modified - Add forwarding commands
daemon/src/main.rs                  # Modified - Register /call/forward route
test/call_forward_test.sh           # New - Integration tests
docs/CALL_FORWARDING_COMPLETE.md    # This file
```

---

## Next Module

According to the modular development order:

**Completed**:
1. ✅ GET `/status` - Device status
2. ✅ POST `/radio/data` - Mobile data toggle
3. ✅ POST `/radio/airplane` - Airplane mode toggle
4. ✅ **POST `/call/forward` - Call forwarding** ← Current module

**Next**:
5. 🚧 **POST `/call/dial` - Initiate outgoing calls**

After that:
- Flutter app development
- Tailscale VPN setup
- Rate limiting and audit logs
- Production hardening

---

## Resources

- Android IPhoneInterface reference: https://developer.android.com/reference/android/telephony/SubscriptionManager
- MMI codes specification: 3GPP TS 22.030
- Service call documentation: `adb shell service call phone` (internal API)
- Previous modules:
  - `docs/AIRPLANE_MODE_COMPLETE.md`
  - `docs/DEPLOYMENT_SUCCESS.md`

---

**Status**: ✅ Ready for Android testing  
**Next Action**: Deploy to rooted device and test with actual phone calls
