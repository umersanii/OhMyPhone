#!/bin/bash
# Fix Asterisk configuration to use PJSIP instead of chan_sip
# Run with: sudo bash fix_pjsip_config.sh

set -e

echo "=========================================="
echo "Fixing Asterisk PJSIP Configuration"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Please run as root (sudo bash fix_pjsip_config.sh)"
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

# Get passwords from existing sip.conf
DUMB_PHONE_PASSWORD=$(grep -A 5 "^\[100\]" /etc/asterisk/sip.conf | grep "^secret=" | cut -d'=' -f2)
MAIN_PHONE_PASSWORD=$(grep -A 5 "^\[101\]" /etc/asterisk/sip.conf | grep "^secret=" | cut -d'=' -f2)

if [ -z "$DUMB_PHONE_PASSWORD" ] || [ -z "$MAIN_PHONE_PASSWORD" ]; then
    echo "ERROR: Could not extract passwords from sip.conf"
    echo "Please enter them manually:"
    read -p "Dumb phone password (extension 100): " DUMB_PHONE_PASSWORD
    read -p "Main phone password (extension 101): " MAIN_PHONE_PASSWORD
fi

echo "Extracted passwords from sip.conf"
echo ""

# Backup existing config
BACKUP_DIR="/etc/asterisk/backup_pjsip_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/asterisk/pjsip.conf "$BACKUP_DIR/" 2>/dev/null || true
echo "Backup saved to: $BACKUP_DIR"

# Configure PJSIP
echo "Configuring PJSIP..."
cat > /etc/asterisk/pjsip.conf << EOF
[global]
max_forwards=70
user_agent=OhMyPhone Asterisk
default_realm=$TAILSCALE_IP

[transport-udp]
type=transport
protocol=udp
bind=$TAILSCALE_IP:5060
local_net=100.0.0.0/8

; Dumb phone (extension 100)
[100]
type=endpoint
context=from-dumb
disallow=all
allow=ulaw
allow=alaw
auth=100
aors=100
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes

[100]
type=auth
auth_type=userpass
username=100
password=$DUMB_PHONE_PASSWORD

[100]
type=aor
max_contacts=1
qualify_frequency=30

; Main phone (extension 101)
[101]
type=endpoint
context=from-main
disallow=all
allow=ulaw
allow=alaw
auth=101
aors=101
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes

[101]
type=auth
auth_type=userpass
username=101
password=$MAIN_PHONE_PASSWORD

[101]
type=aor
max_contacts=1
qualify_frequency=30
EOF

# Set permissions
chown asterisk:asterisk /etc/asterisk/pjsip.conf

# Reload PJSIP
echo ""
echo "Reloading PJSIP configuration..."
asterisk -rx "module reload res_pjsip.so"
sleep 2

# Verify
echo ""
echo "=========================================="
echo "Verifying PJSIP endpoints..."
echo "=========================================="
asterisk -rx "pjsip show endpoints"

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "SIP Server: $TAILSCALE_IP:5060"
echo "Extension 100 (Dumb Phone): $DUMB_PHONE_PASSWORD"
echo "Extension 101 (Main Phone): $MAIN_PHONE_PASSWORD"
echo ""
echo "Test registration with:"
echo "  sudo asterisk -rx 'pjsip show endpoints'"
echo "  sudo asterisk -rx 'pjsip show auths'"
echo ""
