# Understanding the OhMyPhone Daemon

## 🏠 The Big Picture: Your Two-Phone House

Imagine you have **two houses**:

1. **Main House** (your main phone) - Where you live and work daily
   - Nice furniture, apps, your personal data
   - But NO telephone line (no SIM card)

2. **Phone Booth House** (dumb phone) - A simple building with just a landline
   - Only has a telephone (SIM card + cellular radio)
   - Someone needs to answer calls and relay messages

**The Problem:** You're in the main house, but the only telephone is in the phone booth house. How do you make/receive calls?

**The Solution:** Hire a **butler** (the daemon) who:
- Lives in the phone booth house
- Listens for your commands via walkie-talkie (REST API over VPN)
- Operates the phone on your behalf
- Reports back what's happening

---

## 🏗️ Architecture: How It Actually Works

```
┌─────────────────────────────────────┐
│      YOUR MAIN PHONE                │
│  (Flutter App - Coming Soon)        │
│                                     │
│  You tap: "Turn off mobile data"    │
│         ↓                           │
│  App creates secure message         │
│  Signs it with secret code (HMAC)   │
└─────────────┬───────────────────────┘
              │
              │ Encrypted tunnel (Tailscale VPN)
              │ Like a secure underground pipe
              ↓
┌─────────────────────────────────────┐
│      DUMB PHONE (Rooted Android)    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   THE DAEMON (Butler)       │   │
│  │   - Always listening        │   │
│  │   - Checks your ID badge    │   │
│  │   - Executes safe commands  │   │
│  └──────────┬──────────────────┘   │
│             ↓                       │
│  ┌─────────────────────────────┐   │
│  │   Android System            │   │
│  │   - Mobile data switch      │   │
│  │   - Call forwarding         │   │
│  │   - Airplane mode           │   │
│  └─────────────────────────────┘   │
│                                     │
│  📡 SIM Card + Cellular Radio       │
└─────────────────────────────────────┘
```

---

## 📁 The Daemon Directory: What Each File Does

Think of the daemon as a **restaurant**:

```
daemon/
├── Cargo.toml              # 📋 Menu & Ingredient List
├── src/
│   ├── main.rs             # 👨‍🍳 Head Chef (starts everything)
│   ├── config.rs           # ⚙️ Restaurant Settings
│   ├── auth.rs             # 🛡️ Security Guard (checks IDs)
│   ├── api/                # 📞 Order-Taking System
│   │   ├── mod.rs          # Directory listing
│   │   └── status.rs       # "What's the kitchen status?"
│   └── executor/           # 🔪 Kitchen (does actual work)
│       ├── mod.rs          # Directory listing
│       └── shell.rs        # The actual cooking tools
└── deploy/
    ├── config.toml.example # 🏠 Restaurant blueprint
    └── daemon.sh           # 🚀 Grand opening script
```

### Let's Break Down Each "Room":

---

### 1️⃣ `Cargo.toml` - The Menu & Ingredient List

**Analogy:** Like a recipe book's first page listing all ingredients

**What it does:**
```toml
[package]
name = "ohmyphone-daemon"  # Restaurant name

[dependencies]
actix-web = "4.4"          # Waiter system (handles customer orders)
serde = "1.0"              # Menu translator (JSON ↔ Rust data)
hmac = "0.12"              # Security badge maker
sha2 = "0.10"              # Encryption ink
tokio = "1.35"             # Kitchen task manager
```

**Why you need it:** Tells Rust what "ingredients" (libraries) to download and use.

---

### 2️⃣ `src/main.rs` - The Head Chef

**Analogy:** The restaurant manager who opens doors and coordinates everything

**What it does:**
```rust
1. Wake up and read the restaurant rules (load config.toml)
2. Hire security guard (create auth service)
3. Open the front door (start HTTP server on port 8080)
4. Tell waiters what menu items exist (/status, /radio/data, etc.)
5. Keep restaurant running 24/7
```

**Code flow:**
```rust
main() {
    Load config          → "What's our address? What's the secret password?"
    Create auth service  → "Make the ID checker"
    Start HTTP server    → "Open for business at 127.0.0.1:8080"
    Wait forever         → "Keep serving customers"
}
```

---

### 3️⃣ `src/config.rs` - Restaurant Settings

**Analogy:** The settings file: "Open 8am-10pm, accept cash only, secret knock is 'shave-and-a-haircut'"

**What it does:**
```rust
struct Config {
    server: {
        bind_address: "127.0.0.1",  // Restaurant address
        port: 8080                   // Front door number
    },
    security: {
        secret: "your-secret-key",   // Password to get in
        timestamp_window: 30         // "Orders expire after 30 seconds"
    }
}
```

**Why you need it:** Keeps all settings in one file so you can change them without recompiling code.

---

### 4️⃣ `src/auth.rs` - The Security Guard

**Analogy:** Bouncer at a club checking ID badges

**What it does:**
```rust
1. Customer arrives with a message
2. Check their badge (HMAC signature)
   - Is the badge real? (correct secret key)
   - Is it recent? (timestamp not expired)
   - Have they used this badge before? (replay attack check)
3. If all checks pass → Let them in
4. If anything fails → "ACCESS DENIED"
```

**Real example:**
```rust
// Main phone sends:
{
    message: "Get status",
    timestamp: 1703340000000,
    signature: "abc123..."  // HMAC of (message + timestamp)
}

// Security guard checks:
1. Recompute signature using secret key
2. Does abc123 match? ✓
3. Is timestamp within 30 seconds? ✓
4. Have we seen abc123 before? ✗
→ ALLOW
```

**Why you need it:** Prevents hackers from sending fake commands to your phone.

---

### 5️⃣ `src/api/status.rs` - The Waiter Taking Orders

**Analogy:** Waiter who takes your order "I'll have the #3 combo" and brings it to the kitchen

**What it does:**
```rust
Customer says: "GET /status"
↓
Waiter (status.rs):
    1. Call security guard → Check their ID badge
    2. Go to kitchen → "Hey, get me battery, signal, etc."
    3. Kitchen returns → battery: 82%, signal: -93dBm
    4. Format as JSON → {"battery": 82, "signal_dbm": -93}
    5. Serve to customer → Return HTTP 200 with JSON
```

**Code structure:**
```rust
pub async fn get_status(req, auth) {
    auth.verify_request(&req)?;           // Check ID badge
    
    let battery = ShellCommand::GetBattery.execute();   // Kitchen work
    let signal = ShellCommand::GetSignal.execute();
    
    HttpResponse::Ok().json({             // Serve the meal
        "battery": battery,
        "signal_dbm": signal
    })
}
```

**Why you need it:** Translates human requests into kitchen actions.

---

### 6️⃣ `src/executor/shell.rs` - The Kitchen Tools

**Analogy:** The actual knives, pans, and ovens that do the cooking

**What it does:**
```rust
enum ShellCommand {
    GetBattery,    // Like a thermometer
    GetSignal,     // Like a radio tuner
    GetDataState,  // Like a light switch checker
}

// Each tool does ONE specific thing:
GetBattery → runs: `dumpsys battery`
GetSignal  → runs: `dumpsys telephony.registry`
```

**Safety feature:** Whitelist-only commands
```rust
// ✅ SAFE: Predefined commands
match cmd {
    GetBattery => exec("dumpsys battery"),
}

// ❌ DANGEROUS (we DON'T do this):
fn run_any_command(user_input: String) {
    exec(user_input)  // User could send: "rm -rf /"
}
```

**Why you need it:** Does the actual Android system work, but safely.

---

### 7️⃣ `deploy/config.toml` - The Restaurant Blueprint

**Analogy:** Instructions for "How to set up your restaurant"

```toml
[server]
bind_address = "127.0.0.1"    # Street address
port = 8080                    # Building number

[security]
secret = "your-secret-here"    # Master key to the building
timestamp_window = 30          # "Orders expire in 30 seconds"
```

**Why you need it:** Separates settings from code. Change address/port without recompiling.

---

### 8️⃣ `deploy/daemon.sh` - Grand Opening Script

**Analogy:** Script that says "At system boot, start the restaurant automatically"

```bash
# Wait until phone fully boots
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# Open the restaurant
/data/local/tmp/ohmyphone-daemon &
```

**Why you need it:** Ensures daemon starts when phone reboots (like a service/systemd unit).

---

## 🔄 How A Request Flows (Real Example)

**Scenario:** You want to check battery level from your main phone

```
┌─────────────────────────────────────────────────────────┐
│ 1. MAIN PHONE: Flutter App                             │
│    User taps "Refresh Status" button                    │
│    ↓                                                     │
│    App creates request:                                 │
│      timestamp = current_time()                         │
│      message = "" (empty for GET)                       │
│      hmac = sign(message + timestamp, secret_key)       │
│    ↓                                                     │
│    Sends over Tailscale VPN:                            │
│      GET http://100.x.x.x:8080/status                   │
│      Headers:                                           │
│        X-Auth: abc123...                                │
│        X-Time: 1703340000000                            │
└─────────────────────────────────────────────────────────┘
                        │
                        │ VPN tunnel
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 2. DUMB PHONE: Daemon Receives Request                 │
│    main.rs → Routes to api/status.rs                    │
│    ↓                                                     │
│    status.rs → Calls auth.verify_request()              │
│    ↓                                                     │
│    auth.rs → Security guard checks:                     │
│      ✓ HMAC valid?                                      │
│      ✓ Timestamp recent?                                │
│      ✓ Not seen before?                                 │
│    ↓                                                     │
│    PASS → Continue                                      │
└─────────────────────────────────────────────────────────┘
                        │
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 3. EXECUTOR: Run Shell Commands                        │
│    status.rs calls:                                     │
│      ShellCommand::GetBattery.execute()                 │
│      ShellCommand::GetSignal.execute()                  │
│    ↓                                                     │
│    shell.rs → Runs on Android:                          │
│      $ dumpsys battery          → "level: 82"           │
│      $ dumpsys telephony.registry → "rssi=-93"          │
│    ↓                                                     │
│    Parse output → battery=82, signal=-93                │
└─────────────────────────────────────────────────────────┘
                        │
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 4. RESPONSE: Send Back to Main Phone                   │
│    status.rs → Creates JSON:                            │
│      {                                                   │
│        "battery": 82,                                   │
│        "charging": false,                               │
│        "signal_dbm": -93,                               │
│        ...                                              │
│      }                                                   │
│    ↓                                                     │
│    HTTP 200 OK                                          │
└─────────────────────────────────────────────────────────┘
                        │
                        │ VPN tunnel
                        ↓
┌─────────────────────────────────────────────────────────┐
│ 5. MAIN PHONE: Flutter App Displays                    │
│    Receives JSON                                        │
│    ↓                                                     │
│    Updates UI:                                          │
│      🔋 Battery: 82%                                    │
│      📡 Signal: -93 dBm                                 │
└─────────────────────────────────────────────────────────┘
```

**Time elapsed:** ~50-200 milliseconds

---

## 🎯 Why This Architecture?

### Separation of Concerns (Restaurant Analogy)

```
┌──────────────────────────────────────────┐
│  Security Guard (auth.rs)                │  
│  → Only checks badges                    │  Never cooks food
│  → Doesn't care what kitchen does        │  or takes orders
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  Waiter (api/status.rs)                  │  
│  → Takes orders                          │  Never checks IDs
│  → Brings food from kitchen              │  or cooks
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  Chef (executor/shell.rs)                │  
│  → Only cooks (runs commands)            │  Never talks to
│  → Doesn't know who ordered              │  customers
└──────────────────────────────────────────┘
```

**Benefits:**
- Easy to add new menu items (endpoints) without touching security
- Easy to change security without breaking the kitchen
- Easy to test each part independently

---

## 🔒 Security: Why HMAC?

**Bad approach:** Just send password
```
Request: "Turn off data, password=mysecret"
Problem: Anyone sniffing network sees your password
```

**Better:** Send encrypted signature (HMAC)
```
1. Main phone: 
   message = "Turn off data"
   timestamp = 1703340000
   hmac = HMAC(message + timestamp, secret_key)
   → hmac = "abc123def456..."

2. Send: message + timestamp + hmac

3. Hacker intercepts: "Turn off data, 1703340000, abc123def456"
   - Hacker tries to replay: REJECTED (timestamp old)
   - Hacker tries to change message: REJECTED (HMAC won't match)
   - Hacker doesn't know secret_key: CAN'T create valid HMAC
```

**Like a wax seal on a letter:** You can see the letter, but can't forge the seal without the royal stamp.

---

## 🚀 Current Status & Next Steps

### What Works Now ✅
```
[Main Phone] → (Flutter app not built yet, using curl for testing)
       ↓
   Tailscale VPN
       ↓
[Dumb Phone] → Daemon running ✓
       ↓
   GET /status → Returns device info ✓
       ↓
   HMAC Auth → Working ✓
```

### Next Steps 📋

**Phase 1:** Add control endpoints (in progress)
```rust
POST /radio/data      → svc data enable/disable
POST /radio/airplane  → settings put global airplane_mode_on
POST /call/forward    → service call phone 14...
```

**Phase 2:** Build Flutter app
```dart
- UI with buttons: "Toggle Data", "Airplane Mode"
- HMAC signing in Dart
- Polling /status every 5-30 seconds
```

**Phase 3:** Deploy & test on real device
```bash
- Cross-compile for ARM64
- Push to /data/local/tmp/
- Test with real SIM card
```

---

## 🎓 Key Concepts Summary

1. **Daemon** = Restaurant that never closes (runs 24/7)
2. **REST API** = Menu of things you can order
3. **HMAC** = Signature proving "this order is really from you"
4. **Whitelist** = Only cook items on the menu (no surprise dishes)
5. **Tailscale** = Secret underground tunnel between houses
6. **Port 8080** = Which door to knock on

---

## 💡 Common Beginner Questions

**Q: Why Rust and not Python/JavaScript?**  
A: Like using a metal pan vs plastic. Rust is:
- Fast (no performance overhead)
- Safe (catches bugs at compile time)
- Small binary (important for phones)

**Q: Why not use Termux or Tasker?**  
A: Like driving a car vs taking a taxi:
- Full control over everything
- No middleman restrictions
- Can root the phone safely

**Q: Is this secure enough?**  
A: Yes, because:
- Daemon only listens on VPN (not public internet)
- HMAC prevents tampering
- Whitelist prevents arbitrary commands
- No user data stored

**Q: What if daemon crashes?**  
A: The `daemon.sh` script and Magisk ensure it auto-restarts on boot. You can also add a watchdog.

---

## 📚 Further Reading

- **Rust basics:** [rust-lang.org/learn](https://rust-lang.org/learn)
- **REST APIs:** [restfulapi.net](https://restfulapi.net)
- **HMAC authentication:** [Wikipedia - HMAC](https://en.wikipedia.org/wiki/HMAC)
- **Actix-web framework:** [actix.rs](https://actix.rs)

---

**Bottom line:** You've built a secure, remote-controlled robot butler that lives in your dumb phone and follows your orders from the main phone. The daemon is the butler's brain. 🧠🤖
