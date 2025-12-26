# Raspberry Pi Setup

This directory contains setup scripts and configuration files for the Raspberry Pi SIP server.

## Quick Start

1. **Copy script to Raspberry Pi:**
   ```bash
   scp raspberry_pi/setup_asterisk.sh pi@<raspberry-pi-ip>:~/
   ```

2. **Run setup script:**
   ```bash
   ssh pi@<raspberry-pi-ip>
   sudo bash setup_asterisk.sh
   ```

3. **Save the generated credentials** - you'll need them for configuring the dumb phone and main phone.

## What the Script Does

- Detects Tailscale IP (or prompts for manual entry)
- Generates secure random passwords for SIP extensions
- Installs Asterisk
- Configures SIP extensions (100 for dumb phone, 101 for main phone)
- Sets up call routing between extensions
- Starts and enables Asterisk service
- Saves credentials to `/root/ohmyphone_sip_credentials.txt`

## Manual Configuration

If you prefer to configure manually, see [`../docs/VOIP_BRIDGE.md`](../docs/VOIP_BRIDGE.md) Section 1.

## Verification

After setup, verify SIP peers are registered:

```bash
sudo asterisk -rx "sip show peers"
```

Expected output:
```
Name/username             Host                                    Dyn Forcerport Comedia    ACL Port     Status      
100/100                   (Unspecified)                            D  Yes        Yes            0        Unmonitored
101/101                   (Unspecified)                            D  Yes        Yes            0        Unmonitored
```

## Troubleshooting

- **Tailscale not detected**: Ensure Tailscale is installed and running
- **Asterisk won't start**: Check logs with `sudo journalctl -u asterisk -f`
- **SIP registration fails**: Verify firewall allows port 5060 from Tailscale network

## Security

- SIP server binds to Tailscale IP only (not public internet)
- 24-character random passwords for each extension
- Firewall should restrict access to Tailscale network only
