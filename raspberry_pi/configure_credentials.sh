#!/bin/bash
# OhMyPhone - Configure SIP Credentials
# Use this script to set up SIP credentials from your saved passwords
# Run with: sudo bash configure_credentials.sh

set -e

echo "=========================================="
echo "OhMyPhone - SIP Credentials Configuration"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Please run as root (sudo bash configure_credentials.sh)"
    exit 1
fi

# Get Tailscale IP
TAILSCALE_IP=$(ip addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")

if [ -z "$TAILSCALE_IP" ]; then
    echo "WARNING: Tailscale interface not found. Please enter your Tailscale IP manually:"
    read -p "Tailscale IP: " TAILSCALE_IP
fi

echo "Using Tailscale IP: $TAILSCALE_IP"
echo ""

# Prompt for passwords
echo "Enter your SIP credentials:"
echo ""
read -p "Dumb phone password (extension 100): " DUMB_PHONE_PASSWORD
read -p "Main phone password (extension 101): " MAIN_PHONE_PASSWORD

if [ -z "$DUMB_PHONE_PASSWORD" ] || [ -z "$MAIN_PHONE_PASSWORD" ]; then
    echo "ERROR: Both passwords are required"
    exit 1
fi

echo ""
echo "Configuring SIP with provided credentials..."

# Backup existing config
BACKUP_DIR="/etc/asterisk/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/asterisk/sip.conf "$BACKUP_DIR/" 2>/dev/null || true
echo "Backup saved to: $BACKUP_DIR"

# Configure SIP
cat > /etc/asterisk/sip.conf << EOF
[general]
context=default
bindaddr=$TAILSCALE_IP
bindport=5060
transport=udp
disallow=all
allow=ulaw
allow=alaw
qualify=yes
nat=force_rport,comedia

; Dumb phone (extension 100)
[100]
type=friend
secret=$DUMB_PHONE_PASSWORD
host=dynamic
context=from-dumb
qualify=yes
nat=force_rport,comedia

; Main phone (extension 101)
[101]
type=friend
secret=$MAIN_PHONE_PASSWORD
host=dynamic
context=from-main
qualify=yes
nat=force_rport,comedia
EOF

# Set proper permissions
chown asterisk:asterisk /etc/asterisk/sip.conf

# Restart Asterisk
echo ""
echo "Restarting Asterisk..."
systemctl restart asterisk

# Wait for restart
sleep 3

# Verify
echo ""
echo "Verifying SIP configuration..."
asterisk -rx "sip show peers" || echo "WARNING: Could not verify SIP peers"

# Save credentials
CREDS_FILE="/root/ohmyphone_sip_credentials.txt"
cat > "$CREDS_FILE" << EOF
OhMyPhone SIP Credentials
Updated: $(date)

SIP Server: sip:$TAILSCALE_IP:5060

Dumb Phone (Extension 100):
  Username: 100
  Password: $DUMB_PHONE_PASSWORD

Main Phone (Extension 101):
  Username: 101
  Password: $MAIN_PHONE_PASSWORD

Configuration Files:
  - /etc/asterisk/sip.conf
  - /etc/asterisk/extensions.conf
  - Backup: $BACKUP_DIR
EOF

chmod 600 "$CREDS_FILE"

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "SIP Server: $TAILSCALE_IP:5060"
echo "Extension 100 (Dumb Phone): $DUMB_PHONE_PASSWORD"
echo "Extension 101 (Main Phone): $MAIN_PHONE_PASSWORD"
echo ""
echo "Credentials saved to: $CREDS_FILE"
echo ""
echo "Next: Configure your devices with these credentials"
echo "=========================================="
