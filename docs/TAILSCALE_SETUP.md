# Tailscale Network Setup

## Device IP Addresses

- **Dumb Phone (Android)**: `100.99.172.92`
- **Main Phone**: `100.111.10.92`

## Daemon Configuration

The daemon is configured to bind to the Tailscale IP address of the dumb phone (`100.99.172.92:8080`).

### Configuration File
Location: `/data/local/tmp/config.toml` on dumb phone

```toml
[server]
bind_address = "100.99.172.92"
port = 8080

[security]
secret = "fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188"
timestamp_window = 30

[logging]
level = "info"
file = "/data/local/tmp/ohmyphone.log"
```

## Deployment Steps

### 1. Push Updated Config to Dumb Phone
```bash
cd /mnt/work/Coding/OhMyPhone/daemon
adb push deploy/config.toml /data/local/tmp/config.toml
```

### 2. Restart Daemon
```bash
# Kill existing daemon
adb shell "su -c 'pkill -f ohmyphone-daemon'"

# Start daemon with new config
adb shell "su -c 'cd /data/local/tmp && RUST_LOG=info ./ohmyphone-daemon > daemon.log 2>&1 &'"
```

### 3. Verify Daemon is Listening on Tailscale IP
```bash
# Check if daemon is running
adb shell "su -c 'ps | grep ohmyphone'"

# Check listening sockets (should show 100.99.172.92:8080)
adb shell "su -c 'netstat -tuln | grep 8080'"
```

### 4. Test from Main Phone
Once the Flutter app is configured, test connectivity:
```bash
# From main phone or development machine on Tailscale network
curl -v http://100.99.172.92:8080/status
```

## Flutter App Configuration

Update Flutter app settings:
- **Server URL**: `http://100.99.172.92:8080`
- **Shared Secret**: `fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188`

## Security Notes

1. **Tailscale Only**: Daemon binds to Tailscale IP, not `0.0.0.0` - only accessible via Tailscale network
2. **HMAC Authentication**: All requests require valid HMAC signature
3. **No Public Exposure**: Dumb phone's cellular IP is isolated from daemon
4. **VPN Encryption**: All traffic encrypted by Tailscale WireGuard

## Troubleshooting

### Daemon won't start
```bash
# Check logs
adb shell "su -c 'cat /data/local/tmp/daemon.log'"
adb shell "su -c 'cat /data/local/tmp/ohmyphone.log'"
```

### Can't connect from main phone
```bash
# Verify Tailscale connectivity
ping 100.99.172.92

# Check firewall (Android may block by default)
adb shell "su -c 'iptables -L -n | grep 8080'"
```

### Connection times out
- Ensure both devices are connected to Tailscale (check Tailscale app)
- Verify daemon is running: `adb shell "su -c 'ps | grep ohmyphone'"`
- Check daemon is bound to correct IP: `adb shell "su -c 'netstat -tuln'"`

## Next Steps

1. ✅ Configure daemon to bind to Tailscale IP
2. 🔄 Deploy updated config and restart daemon
3. ⏳ Build Flutter APK for main phone
4. ⏳ Configure Flutter app with dumb phone Tailscale IP
5. ⏳ End-to-end testing over Tailscale network
