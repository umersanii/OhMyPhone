#!/bin/bash
# OhMyPhone Raspberry Pi SIP Server Setup Script
# Installs and configures Asterisk for VoIP call bridging
# Run with: sudo bash setup_asterisk.sh

set -e  # Exit on error

echo "=========================================="
echo "OhMyPhone - Raspberry Pi SIP Server Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Please run as root (sudo bash setup_asterisk.sh)"
    exit 1
fi

# Get Tailscale IP
echo "[1/7] Detecting Tailscale IP..."
TAILSCALE_IP=$(ip addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")

if [ -z "$TAILSCALE_IP" ]; then
    echo "WARNING: Tailscale interface not found. Please enter your Tailscale IP manually:"
    read -p "Tailscale IP: " TAILSCALE_IP
    if [ -z "$TAILSCALE_IP" ]; then
        echo "ERROR: Tailscale IP is required for security"
        exit 1
    fi
fi

echo "Using Tailscale IP: $TAILSCALE_IP"
echo ""

# Generate random SIP passwords
echo "[2/7] Generating secure SIP passwords..."
DUMB_PHONE_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
MAIN_PHONE_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
echo "Dumb phone password: $DUMB_PHONE_PASSWORD"
echo "Main phone password: $MAIN_PHONE_PASSWORD"
echo ""
echo "IMPORTANT: Save these passwords! You'll need them for device configuration."
echo ""

# Update system
echo "[3/7] Updating system packages..."
apt update && apt upgrade -y

# Install dependencies for Asterisk
echo "[4/7] Installing Asterisk dependencies..."
apt install -y build-essential wget libssl-dev libncurses5-dev libnewt-dev \
    libxml2-dev linux-headers-$(uname -r) libsqlite3-dev uuid-dev \
    libjansson-dev

# Download and compile Asterisk
echo "[5/7] Downloading Asterisk 20 LTS..."
cd /usr/src
ASTERISK_VERSION="20.11.1"
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz
tar xvf asterisk-${ASTERISK_VERSION}.tar.gz
cd asterisk-${ASTERISK_VERSION}

echo "[6/7] Compiling Asterisk (this may take 15-30 minutes)..."
./configure --with-jansson-bundled
make menuselect.makeopts
# Disable unnecessary modules to speed up compilation
menuselect/menuselect --disable BUILD_NATIVE \
    --disable chan_dahdi --disable chan_mobile \
    --disable app_voicemail --disable app_directory \
    menuselect.makeopts
make -j$(nproc)
make install
make samples
make config

# Create asterisk user
useradd -r -d /var/lib/asterisk -s /bin/false asterisk || true
chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /usr/lib/asterisk

# Set Asterisk to run as asterisk user
sed -i 's/#AST_USER="asterisk"/AST_USER="asterisk"/' /etc/default/asterisk
sed -i 's/#AST_GROUP="asterisk"/AST_GROUP="asterisk"/' /etc/default/asterisk

# Stop Asterisk for configuration
systemctl stop asterisk

# Backup original configs
echo "[5/7] Backing up original configuration..."
BACKUP_DIR="/etc/asterisk/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp /etc/asterisk/sip.conf "$BACKUP_DIR/" 2>/dev/null || true
cp /etc/asterisk/extensions.conf "$BACKUP_DIR/" 2>/dev/null || true
echo "Backup saved to: $BACKUP_DIR"

# Configure SIP
echo "[6/7] Configuring SIP extensions..."
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

# Configure call routing
echo "[7/7] Configuring call routing..."
cat > /etc/asterisk/extensions.conf << EOF
[general]
static=yes
writeprotect=no

[from-dumb]
; When dumb phone calls extension 101, route to main phone
exten => 101,1,NoOp(Call from dumb phone to main phone)
exten => 101,n,Dial(SIP/101,30)
exten => 101,n,Hangup()

[from-main]
; When main phone calls extension 100, route to dumb phone
exten => 100,1,NoOp(Call from main phone to dumb phone)
exten => 100,n,Dial(SIP/100,30)
exten => 100,n,Hangup()

[default]
; Default context (should not be reached)
exten => _X.,1,NoOp(Unexpected call to default context)
exten => _X.,n,Hangup()
EOF

# Set proper permissions
chown -R asterisk:asterisk /etc/asterisk/

# Start Asterisk
echo ""
echo "Starting Asterisk..."
systemctl start asterisk
systemctl enable asterisk

# Wait for Asterisk to start
sleep 3

# Verify SIP configuration
echo ""
echo "=========================================="
echo "Verifying SIP configuration..."
echo "=========================================="
asterisk -rx "sip show peers" || echo "WARNING: Could not verify SIP peers"

# Display firewall instructions
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "SIP Server Configuration:"
echo "  - Listening on: $TAILSCALE_IP:5060"
echo "  - Extension 100 (Dumb Phone): Password = $DUMB_PHONE_PASSWORD"
echo "  - Extension 101 (Main Phone): Password = $MAIN_PHONE_PASSWORD"
echo ""
echo "Next Steps:"
echo "  1. Configure dumb phone daemon with:"
echo "     - SIP Server: sip:$TAILSCALE_IP"
echo "     - Username: 100"
echo "     - Password: $DUMB_PHONE_PASSWORD"
echo ""
echo "  2. Configure main phone Flutter app with:"
echo "     - SIP Server: sip:$TAILSCALE_IP"
echo "     - Username: 101"
echo "     - Password: $MAIN_PHONE_PASSWORD"
echo ""
echo "  3. Test SIP registration:"
echo "     sudo asterisk -rx 'sip show peers'"
echo ""
echo "  4. Monitor Asterisk logs:"
echo "     sudo tail -f /var/log/asterisk/messages"
echo ""
echo "Firewall Configuration (if using ufw):"
echo "  sudo ufw allow from 100.0.0.0/8 to any port 5060 proto udp"
echo "  sudo ufw allow from 100.0.0.0/8 to any port 10000:20000 proto udp  # RTP"
echo ""
echo "Configuration files:"
echo "  - SIP: /etc/asterisk/sip.conf"
echo "  - Routing: /etc/asterisk/extensions.conf"
echo "  - Backup: $BACKUP_DIR"
echo ""
echo "=========================================="

# Save credentials to file
CREDS_FILE="/root/ohmyphone_sip_credentials.txt"
cat > "$CREDS_FILE" << EOF
OhMyPhone SIP Credentials
Generated: $(date)

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
echo "Credentials saved to: $CREDS_FILE"
echo ""
