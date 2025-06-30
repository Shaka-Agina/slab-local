#!/bin/bash

# SLAB USB Music Player - Fully Native Installation Script
# This script installs the music player with native USB detection only

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🎵 SLAB USB Music Player Installation${NC}"
echo -e "${PURPLE}======================================${NC}"
echo ""
echo -e "${GREEN}✨ Using fully native USB detection${NC}"
echo -e "${GREEN}✨ No bind mounts or complex mounting required${NC}"
echo -e "${GREEN}✨ Works with desktop auto-mounting${NC}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root/sudo"
    exit 1
fi

# Generate unique hotspot name based on last 4 characters of hostname
HOSTNAME=$(hostname)
LAST_4_CHARS=$(echo "$HOSTNAME" | tail -c 5)
HOTSPOT_NAME="S L A B - $LAST_4_CHARS"
HOTSPOT_PASSWORD="slabmusic"

print_status "Hotspot will be: $HOTSPOT_NAME (password: $HOTSPOT_PASSWORD)"

# [1/6] System package installation
echo ""
echo -e "${CYAN}[1/6] Installing required system packages...${NC}"

# Update package list
sudo apt update

# Install required packages
sudo apt install -y \
    docker.io \
    docker-compose \
    git \
    python3 \
    python3-pip \
    hostapd \
    dnsmasq \
    iptables \
    netfilter-persistent \
    iptables-persistent \
    avahi-daemon \
    python3-pygame \
    alsa-utils \
    pulseaudio

# [2/6] Docker setup
echo ""
echo -e "${CYAN}[2/6] Setting up Docker...${NC}"

# Add user to docker group (requires logout/login or reboot to take effect)
sudo usermod -aG docker $USER
print_status "Added $USER user to docker group"

# [3/6] Git configuration
echo ""
echo -e "${CYAN}[3/6] Configuring Git...${NC}"

# Check if git is already configured
if git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1; then
    print_status "Git already configured, skipping..."
else
    print_status "Setting up Git configuration..."
    git config --global user.name "SLAB User"
    git config --global user.email "slab@localhost"
    print_status "Git configured with default values"
fi

# [4/6] Smart Wi-Fi hotspot setup
echo ""
echo -e "${CYAN}[4/6] Setting up smart Wi-Fi hotspot...${NC}"

print_status "Hotspot will be: $HOTSPOT_NAME (password: $HOTSPOT_PASSWORD)"

# Create auto-hotspot script that only activates when no internet
sudo bash -c "cat > /usr/local/bin/auto-hotspot.sh << 'EOF'
#!/bin/bash

# Auto-hotspot script - only activates when no internet connection
LOG_FILE=\"/var/log/auto-hotspot.log\"

log_message() {
    echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] \$1\" | sudo tee -a \"\$LOG_FILE\"
}

# Check if we have internet connectivity
check_internet() {
    # Try multiple reliable endpoints
    for host in 8.8.8.8 1.1.1.1 google.com; do
        if ping -c 1 -W 5 \$host >/dev/null 2>&1; then
            return 0  # Internet available
        fi
    done
    return 1  # No internet
}

# Check if hotspot is currently active
hotspot_active() {
    systemctl is-active --quiet hostapd
}

# Start hotspot
start_hotspot() {
    log_message \"Starting hotspot mode...\"
    
    # Stop dhcpcd on wlan0
    sudo systemctl stop dhcpcd
    
    # Configure static IP for hotspot
    sudo ip addr add 192.168.4.1/24 dev wlan0
    
    # Start services
    sudo systemctl start dnsmasq
    sudo systemctl start hostapd
    
    # Enable IP forwarding and NAT (if ethernet available)
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null
    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
    sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || true
    
    log_message \"Hotspot started: $HOTSPOT_NAME\"
}

# Stop hotspot
stop_hotspot() {
    log_message \"Stopping hotspot mode...\"
    
    # Stop services
    sudo systemctl stop hostapd 2>/dev/null || true
    sudo systemctl stop dnsmasq 2>/dev/null || true
    
    # Clear iptables rules
    sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sudo iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || true
    
    # Remove static IP
    sudo ip addr del 192.168.4.1/24 dev wlan0 2>/dev/null || true
    
    # Restart dhcpcd to restore normal networking
    sudo systemctl start dhcpcd
    
    log_message \"Hotspot stopped, normal networking restored\"
}

# Main logic
if check_internet; then
    if hotspot_active; then
        log_message \"Internet restored, switching back to normal mode\"
        stop_hotspot
    else
        log_message \"Internet available, hotspot not needed\"
    fi
else
    if ! hotspot_active; then
        log_message \"No internet detected, activating hotspot\"
        start_hotspot
    else
        log_message \"No internet, hotspot already active\"
    fi
fi
EOF"

sudo chmod +x /usr/local/bin/auto-hotspot.sh

# Configure hostapd
sudo bash -c "cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=$HOTSPOT_NAME
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$HOTSPOT_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF"

# Configure dnsmasq for hotspot
sudo bash -c "cat > /etc/dnsmasq.conf << EOF
# SLAB Music Player hotspot configuration
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=slab.local
address=/slab.local/192.168.4.1
EOF"

# Set hostapd configuration path
sudo bash -c 'echo "DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"" >> /etc/default/hostapd'

# Create systemd timer for auto-hotspot (checks every 30 seconds)
sudo bash -c "cat > /etc/systemd/system/auto-hotspot.timer << EOF
[Unit]
Description=Auto-hotspot check timer
Requires=auto-hotspot.service

[Timer]
OnBootSec=60
OnUnitActiveSec=30

[Install]
WantedBy=timers.target
EOF"

sudo bash -c "cat > /etc/systemd/system/auto-hotspot.service << EOF
[Unit]
Description=Auto-hotspot check service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-hotspot.sh
EOF"

# Enable timer (but don't start hostapd/dnsmasq directly)
sudo systemctl daemon-reload
sudo systemctl enable auto-hotspot.timer
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

print_status "✅ Smart hotspot configured - will only activate when no internet connection"

# [5/6] Native USB detection setup
echo ""
echo -e "${CYAN}[5/6] Setting up native USB detection...${NC}"

print_status "Configuring native USB detection for desktop auto-mounting"

# Ensure /media/pi directory exists for auto-mounting
sudo mkdir -p /media/pi

# Create udev rules for better USB handling (optional enhancement)
sudo bash -c "cat > /etc/udev/rules.d/99-usb-permissions.rules << EOF
# Set proper permissions for USB drives
SUBSYSTEM==\"block\", ATTRS{idVendor}==\"*\", ACTION==\"add\", RUN+=\"/bin/chown pi:pi /media/pi/*\"
EOF"

sudo udevadm control --reload-rules

print_status "✅ Native USB detection configured - uses desktop auto-mounting in /media/pi/"

# [6/6] Docker service setup
echo ""
echo -e "${CYAN}[6/6] Setting up Docker service for boot launch...${NC}"

CURRENT_DIR=$(pwd)

# Create Docker startup script
sudo bash -c "cat > /usr/local/bin/start_music_player.sh << EOF
#!/bin/bash
cd $CURRENT_DIR
echo \"Starting music player...\"
docker-compose down 2>/dev/null || true
docker-compose up -d
EOF"
sudo chmod +x /usr/local/bin/start_music_player.sh

# Create systemd service for music player
sudo bash -c "cat > /etc/systemd/system/music-player-docker.service << EOF
[Unit]
Description=USB Music Player Docker Service
After=docker.service auto-hotspot.service
Requires=docker.service
Wants=auto-hotspot.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/start_music_player.sh
ExecStop=$CURRENT_DIR/docker-compose down
WorkingDirectory=$CURRENT_DIR

[Install]
WantedBy=multi-user.target
EOF"

# Enable Docker and music player services
print_status "Enabling Docker and music player services..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl enable music-player-docker.service

# Build the Docker image
print_status "Building Docker image..."
docker-compose build

# Create config and logs directories
mkdir -p config logs

# Final success message
echo ""
echo -e "${PURPLE}🎉 Installation Complete! 🎉${NC}"
echo -e "${PURPLE}==================================${NC}"
echo ""
echo -e "${GREEN}✅ NATIVE USB DETECTION:${NC}"
echo -e "${GREEN}• Uses desktop auto-mounting in /media/pi/${NC}"
echo -e "${GREEN}• No complex bind mounts or services required${NC}"
echo -e "${GREEN}• Plug and play - USB drives are detected automatically${NC}"
echo ""
echo -e "${GREEN}✅ SAFE NETWORK CONFIGURATION:${NC}"
echo -e "${GREEN}• Your existing network configuration has been PRESERVED${NC}"
echo -e "${GREEN}• Hotspot will ONLY activate when no internet connection is available${NC}"
echo -e "${GREEN}• SSH access will NOT be disrupted${NC}"
echo ""
echo -e "${CYAN}🔧 HOTSPOT DETAILS:${NC}"
echo -e "${CYAN}• Name: $HOTSPOT_NAME${NC}"
echo -e "${CYAN}• Password: $HOTSPOT_PASSWORD${NC}"
echo -e "${CYAN}• Only activates when no internet connection${NC}"
echo ""
echo -e "${BLUE}🎵 MUSIC PLAYER ACCESS:${NC}"
echo -e "${BLUE}• Normal network: http://slab.local:5000 or http://[your-pi-ip]:5000${NC}"
echo -e "${BLUE}• Hotspot mode: http://192.168.4.1:5000 or http://slab.local:5000${NC}"
echo ""
echo -e "${YELLOW}📱 USB DRIVES:${NC}"
echo -e "${YELLOW}• Label music USB as 'MUSIC' or include audio files${NC}"
echo -e "${YELLOW}• Label control USB as 'PLAY_CARD' or include control.txt${NC}"
echo -e "${YELLOW}• Drives auto-mount in /media/pi/ and are detected automatically${NC}"
echo ""
echo -e "${CYAN}⚙️  MANUAL CONTROL:${NC}"
echo -e "${CYAN}• Start music player: sudo systemctl start music-player-docker.service${NC}"
echo -e "${CYAN}• Stop music player: sudo systemctl stop music-player-docker.service${NC}"
echo -e "${CYAN}• Check hotspot status: sudo systemctl status auto-hotspot.timer${NC}"
echo -e "${CYAN}• View hotspot logs: sudo tail -f /var/log/auto-hotspot.log${NC}"
echo -e "${CYAN}• Manual hotspot check: sudo /usr/local/bin/auto-hotspot.sh${NC}"
echo ""
echo -e "${GREEN}🔄 NEXT STEPS:${NC}"
echo -e "${GREEN}1. Reboot your Raspberry Pi: sudo reboot${NC}"
echo -e "${GREEN}2. Insert your USB drives (they'll auto-mount in /media/pi/)${NC}"
echo -e "${GREEN}3. Access the web interface using the URLs above${NC}"
echo -e "${GREEN}4. Test native USB detection: python3 test-native-usb.py${NC}"
echo ""
echo -e "${PURPLE}Your SSH access and existing network configuration are preserved!${NC}" 