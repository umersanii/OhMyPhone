```md
# Root + Shell + REST Wrapper Architecture
**(Option 3 — No Tasker, Full Control)**

This document defines the complete system architecture, components, APIs, and operational flow for a **relay (dumb) phone + main phone** setup using a **rooted Android device** controlled via a **secure REST interface**, with **Flutter** as the control UI.

---

## 1. High-level Architecture

```

┌────────────────────────┐
│        Main Phone      │
│                        │
│  Flutter App           │
│  ├─ UI / State         │
│  ├─ Network client     │
│  └─ Auth + Logic       │
│                        │
│  (No SIM)              │
└──────────┬─────────────┘
│ HTTPS / WS
│ (mutual auth)
┌──────────▼─────────────┐
│      Dumb Phone        │
│  (Rooted LineageOS)    │
│                        │
│  Control Daemon        │
│  ├─ HTTP server        │
│  ├─ Auth layer         │
│  ├─ Command router     │
│  └─ State reporter     │
│                        │
│  Shell Executors       │
│  ├─ svc / cmd          │
│  ├─ telephony service  │
│  └─ system props       │
│                        │
│  SIM + GSM             │
└────────────────────────┘

```

---

## 2. Dumb Phone Internals

### 2.1 Control Daemon

**Role:**
A single always-on daemon running as `root`.

**Language (recommended order):**
1. Rust (best long-term)
2. Go
3. Python (prototype only)

**Responsibilities:**
- Listen on `127.0.0.1:<port>` or VPN interface
- Authenticate all requests
- Execute whitelisted shell commands
- Return system state as JSON
- Log all actions

> ⚠️ No arbitrary command execution.

---

### 2.2 API Authentication

**Mechanism:**
- Pre-shared secret
- HMAC-SHA256
- Timestamp + nonce (replay protection)

**Headers:**
```

X-Auth: HMAC_SHA256(body + timestamp, secret)
X-Time: <unix_ms>

````

---

### 2.3 API Endpoints

#### `/status`
**GET**

```json
{
  "battery": 82,
  "charging": false,
  "signal_dbm": -93,
  "data": true,
  "airplane": false,
  "call_forwarding": true,
  "uptime": 93422
}
````

---

#### `/radio/data`

**POST**

```json
{ "enable": true }
```

**Shell:**

```sh
svc data enable
```

---

#### `/radio/airplane`

**POST**

```json
{ "enable": false }
```

**Shell:**

```sh
settings put global airplane_mode_on 0
am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false
```

---

#### `/call/forward`

**POST**

```json
{
  "enable": true,
  "number": "+123456789"
}
```

**Enable:**

```sh
service call phone 14 i32 1 s16 "*21*+123456789#"
```

**Disable:**

```sh
service call phone 14 i32 1 s16 "#21#"
```

---

#### `/call/dial`

**POST**

```json
{ "number": "+123456789" }
```

**Shell:**

```sh
am start -a android.intent.action.CALL -d tel:+123456789
```

---

### 2.4 Shell Executor Layer

**Rules:**

* Command map is static
* No string concatenation
* Arguments validated
* No user-provided shell fragments

**Example (pseudo):**

```rust
match cmd {
  EnableData => exec("svc data enable"),
  DisableData => exec("svc data disable"),
}
```

---

### 2.5 Boot & Persistence

**Startup options:**

* Magisk service (`/data/adb/service.d/daemon.sh`)
* `init.rc` (if ROM-controlled)

**Requirements:**

* Start before UI
* Survive reboot
* Zero polling loops

---

## 3. Main Phone (Flutter App)

### 3.1 Responsibilities

* UI + state visualization
* Send authenticated commands
* Handle offline / retry logic
* No system privileges required

---

### 3.2 Flutter Project Structure

```
lib/
 ├─ api/
 │   ├─ client.dart
 │   └─ models.dart
 ├─ state/
 │   ├─ relay_state.dart
 │   └─ sync.dart
 ├─ ui/
 │   ├─ dashboard.dart
 │   └─ controls.dart
 └─ security/
     └─ hmac.dart
```

---

### 3.3 UX Behavior

* Shows:

  * Online / offline
  * Battery %
  * Signal strength
* Controls:

  * Mobile data
  * Airplane mode
  * Call forwarding
  * Dial via relay phone

Everything is explicit and manual.

---

## 4. Call Behavior

### Incoming Calls

* Phone rings on dumb phone
* User can answer directly
* If unanswered:

  * Call forwarding activates
  * Main phone receives call (via carrier/SIP)

### Outgoing Calls

* Initiated on dumb phone normally
* Or:

  * Main phone → `/call/dial`

> ⚠️ True GSM call pickup on another device is impossible without forwarding or SIP.

---

## 5. WhatsApp Behavior

* WhatsApp runs on **main phone**
* Linked-device mode
* SIM remains in dumb phone
* No automation or control required

---

## 6. Security Model

**Minimum:**

* Bind daemon to LAN/VPN only
* HMAC authentication
* Rate limiting
* No open mobile-data ports

**Recommended:**

* WireGuard tunnel between phones
* API accessible only via tunnel IP

---

## 7. Power & Stability

* Disable:

  * Location
  * Sync
  * Unused system apps
* Daemon uses blocking I/O
* Main phone polls state (no push)

**Result:**

* Multi-day battery life
* Headless operation

---

## 8. Modular Build Order

1. Flash LineageOS + root
2. Implement daemon `/status`
3. Add data toggle
4. Add call forwarding
5. Build Flutter dashboard
6. Harden security
7. Optional SIP/VoIP bridge

Do **not** combine steps.

---

## 9. One-line Summary

You are building a **headless, rooted Android modem node** controlled remotely via a **secure, minimal REST API**, with Flutter as the brain and UI.

This is a clean, serious architecture.

```

If you want next:
- a **Rust / Go daemon skeleton**
- exact **Xiaomi telephony binder notes**
- **WireGuard-only** layout between phones
```
