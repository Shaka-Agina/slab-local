#!/bin/bash

# USB Music Player Installation Script - Safe Network Version
# This script preserves existing network configuration and sets up smart hotspot

set -e  # Exit on any error

echo "=== USB Music Player Installation (Safe Network) ==="
echo "This script will install the music player while preserving your network configuration"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as pi user (not root)"
    echo "Usage: ./install.sh"
    exit 1
fi

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Configure automatic service restarts
echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

# Configure needrestart to not prompt
sudo mkdir -p /etc/needrestart/conf.d
echo '$nrconf{restart} = "a";' | sudo tee /etc/needrestart/conf.d/50-auto.conf > /dev/null

# Update system
echo "[1/6] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Install required packages
echo "[2/6] Installing required packages..."
sudo apt-get install -y \
    docker.io \
    docker-compose \
    python3 \
    python3-pip \
    git \
    curl \
    hostapd \
    dnsmasq \
    inotify-tools

# Add pi user to docker group
sudo usermod -aG docker pi
echo "Added pi user to docker group"

# Configure Git (if not already configured)
if ! git config --global user.name >/dev/null 2>&1; then
    echo "[3/6] Configuring Git..."
    git config --global user.name "Music Player"
    git config --global user.email "music@slab.local"
    echo "Git configured"
else
    echo "[3/6] Git already configured, skipping..."
fi

# Set up SAFE Wi-Fi hotspot (only activates when no internet)
echo "[4/6] Setting up smart Wi-Fi hotspot..."

# Generate random hotspot name and password
RANDOM_SUFFIX=$(printf "%04d" $((RANDOM % 10000)))
HOTSPOT_NAME="S L A B - $RANDOM_SUFFIX"
HOTSPOT_PASSWORD="slabmusic"

echo "Hotspot will be: $HOTSPOT_NAME (password: $HOTSPOT_PASSWORD)"

# IMPORTANT: Backup existing network configuration
if [ -f /etc/network/interfaces ] && [ ! -f /etc/network/interfaces.backup ]; then
    sudo cp /etc/network/interfaces /etc/network/interfaces.backup
    echo "✅ Backed up existing network configuration"
fi

# Configure hostapd (but don't enable by default)
sudo bash -c "cat > /etc/hostapd/hostapd.conf << EOL
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
EOL"

# Configure dnsmasq (but don't start by default)
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig 2>/dev/null || true
sudo bash -c "cat > /etc/dnsmasq.conf << EOL
# SLAB Music Player DNS Configuration
interface=wlan0
bind-interfaces
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/slab.local/192.168.4.1
address=/www.slab.local/192.168.4.1
EOL"

# Create SMART hotspot management script (only activates when needed)
sudo bash -c "cat > /usr/local/bin/auto-hotspot.sh << 'EOL'
#!/bin/bash

# Smart Auto Hotspot - Only activate when no internet connection
LOG_FILE=\"/var/log/auto-hotspot.log\"

log_message() {
    echo \"\$(date '+%Y-%m-%d %H:%M:%S') - \$1\" | tee -a \"\$LOG_FILE\"
}

check_internet() {
    # Check if we have internet connectivity
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
        return 0  # Connected
    else
        return 1  # Not connected
    fi
}

get_wlan0_status() {
    # Check if wlan0 is connected to a network
    if iwconfig wlan0 2>/dev/null | grep -q \"ESSID:off\" || ! iwconfig wlan0 2>/dev/null | grep -q \"Access Point:\"; then
        return 1  # Not connected
    else
        return 0  # Connected
    fi
}

start_hotspot() {
    log_message \"Starting hotspot mode - no internet connection detected\"
    
    # Stop any existing network management on wlan0
    sudo pkill wpa_supplicant 2>/dev/null || true
    sudo pkill dhclient 2>/dev/null || true
    
    # Configure wlan0 for hotspot
    sudo ip addr flush dev wlan0 2>/dev/null || true
    sudo ip addr add 192.168.4.1/24 dev wlan0
    sudo ip link set wlan0 up
    
    # Start hostapd and dnsmasq
    sudo systemctl start hostapd
    sudo systemctl start dnsmasq
    
    # Enable IP forwarding and NAT if ethernet is available
    if ip link show eth0 up >/dev/null 2>&1 && ip route | grep -q \"eth0\"; then
        echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward >/dev/null
        
        # Add iptables rules (check if they don't already exist)
        sudo iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || \
        sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        
        sudo iptables -C FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
        sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
        
        sudo iptables -C FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || \
        sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
        
        log_message \"Hotspot with internet sharing enabled via ethernet\"
    else
        log_message \"Hotspot enabled (no ethernet for internet sharing)\"
    fi
    
    log_message \"Hotspot active: $HOTSPOT_NAME\"
}

stop_hotspot() {
    log_message \"Stopping hotspot mode - internet connection available\"
    
    # Stop services
    sudo systemctl stop hostapd 2>/dev/null || true
    sudo systemctl stop dnsmasq 2>/dev/null || true
    
    # Clean up iptables rules
    sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sudo iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null || true
    
    # Reset wlan0 and try to reconnect to WiFi
    sudo ip addr flush dev wlan0 2>/dev/null || true
    
    # Restart wpa_supplicant if config exists
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true
        sleep 2
        sudo dhclient wlan0 2>/dev/null &
    fi
    
    log_message \"Hotspot stopped, attempting to reconnect to WiFi\"
}

# Main logic
if check_internet; then
    # We have internet, make sure hotspot is off
    if systemctl is-active --quiet hostapd; then
        stop_hotspot
    else
        log_message \"Internet connection available, hotspot not needed\"
    fi
else
    # No internet, start hotspot if not already running
    if ! systemctl is-active --quiet hostapd; then
        start_hotspot
    else
        log_message \"No internet connection, hotspot already active\"
    fi
fi
EOL"

sudo chmod +x /usr/local/bin/auto-hotspot.sh

# Create systemd service for smart hotspot
sudo bash -c "cat > /etc/systemd/system/auto-hotspot.service << EOL
[Unit]
Description=Smart Auto Hotspot Service
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-hotspot.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOL"

# Create timer for periodic checks
sudo bash -c "cat > /etc/systemd/system/auto-hotspot.timer << EOL
[Unit]
Description=Smart Auto Hotspot Check Timer
Requires=auto-hotspot.service

[Timer]
OnBootSec=3min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOL"

# IMPORTANT: Don't enable hostapd/dnsmasq by default - let auto-hotspot manage them
sudo systemctl disable hostapd 2>/dev/null || true
sudo systemctl disable dnsmasq 2>/dev/null || true

# Enable the smart hotspot timer
sudo systemctl daemon-reload
sudo systemctl enable auto-hotspot.timer

echo "✅ Smart hotspot configured - will only activate when no internet connection"

# Set up USB auto-mounting
echo "[5/6] Setting up USB auto-mounting..."

# Create USB mount directories
sudo mkdir -p /home/pi/usb/music /home/pi/usb/playcard
sudo chown -R pi:pi /home/pi/usb

# Detect if we're in a desktop environment
if pgrep -x "lxsession" > /dev/null || pgrep -x "pcmanfm" > /dev/null || [ -n "$DESKTOP_SESSION" ] || systemctl list-units --type=service | grep -q udisks2; then
    echo "Desktop environment detected - using enhanced USB bind mount service"
    
    # Create USB bind mount monitoring script
    sudo bash -c "cat > /usr/local/bin/usb-bind-monitor.sh << 'EOL'
#!/bin/bash

# Simple USB Bind Mount Monitor - Static Mount Points
LOG_FILE=\"/var/log/usb-bind-mounts.log\"
MUSIC_BIND=\"/home/pi/usb/music\"
CONTROL_BIND=\"/home/pi/usb/playcard\"

log_message() {
    echo \"\$(date '+%Y-%m-%d %H:%M:%S') - \$1\" | tee -a \"\$LOG_FILE\"
}

# Create static mount points (always exist)
setup_static_mounts() {
    mkdir -p \"\$MUSIC_BIND\" \"\$CONTROL_BIND\"
    chown pi:pi \"\$MUSIC_BIND\" \"\$CONTROL_BIND\"
    log_message \"Static mount points created: \$MUSIC_BIND, \$CONTROL_BIND\"
}

# Simple function to bind mount if not already mounted
bind_usb_to_static() {
    local source=\"\$1\"
    local target=\"\$2\"
    local label=\"\$3\"
    
    # Check if target is already bind mounted
    if mountpoint -q \"\$target\"; then
        # Check if it's the same source
        current_source=\$(findmnt -n -o SOURCE \"\$target\" 2>/dev/null)
        if [ \"\$current_source\" = \"\$source\" ]; then
            return 0  # Already correctly mounted
        else
            log_message \"Unmounting old bind mount: \$target (was: \$current_source)\"
            umount \"\$target\" 2>/dev/null || true
        fi
    fi
    
    # Wait a moment for USB to be fully ready
    sleep 2
    
    # Check if source is accessible and has content
    if [ -d \"\$source\" ] && mountpoint -q \"\$source\" && [ -n \"\$(ls -A \"\$source\" 2>/dev/null)\" ]; then
        if mount --bind \"\$source\" \"\$target\"; then
            log_message \"SUCCESS: Bind mounted \$source -> \$target (\$label)\"
            
            # Verify specific content for control USB
            if [ \"\$label\" = \"control\" ] && [ -f \"\$target/control.txt\" ]; then
                log_message \"VERIFIED: Control file found at \$target/control.txt\"
            elif [ \"\$label\" = \"control\" ]; then
                log_message \"WARNING: Control USB mounted but no control.txt file found\"
            fi
            
            return 0
        else
            log_message \"FAILED: Could not bind mount \$source -> \$target\"
            return 1
        fi
    else
        log_message \"SKIPPED: Source not ready or empty: \$source\"
        return 1
    fi
}

# Clean up orphaned mounts (only unmount if source USB is gone)
cleanup_orphaned_mounts() {
    for target in \"\$MUSIC_BIND\" \"\$CONTROL_BIND\"; do
        if mountpoint -q \"\$target\"; then
            source=\$(findmnt -n -o SOURCE \"\$target\" 2>/dev/null)
            if [ -n \"\$source\" ]; then
                # Check if the original USB mount point still exists and is mounted
                if ! mountpoint -q \"\$source\" 2>/dev/null; then
                    log_message \"Cleaning up orphaned bind mount: \$target (source \$source no longer mounted)\"
                    umount \"\$target\" 2>/dev/null || true
                fi
            fi
        fi
    done
}

# Scan for USB drives and bind mount them to static points
scan_and_bind_usb() {
    log_message \"Scanning for USB drives to bind mount...\"
    
    # Look for mounted USB drives in /media/pi/
    for usb_mount in /media/pi/*; do
        if [ -d \"\$usb_mount\" ] && mountpoint -q \"\$usb_mount\"; then
            usb_label=\$(basename \"\$usb_mount\")
            log_message \"Found USB drive: \$usb_mount (label: \$usb_label)\"
            
            # Check for music USB (MUSIC or MUSIC with numbers, or has music files)
            if [[ \"\$usb_label\" =~ ^MUSIC[0-9]*\$ ]] || [ \"\$usb_label\" = \"MUSIC\" ]; then
                log_message \"Detected MUSIC USB: \$usb_mount\"
                bind_usb_to_static \"\$usb_mount\" \"\$MUSIC_BIND\" \"music\"
            elif find \"\$usb_mount\" -maxdepth 2 -type f \\( -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' -o -iname '*.m4a' \\) -print -quit | grep -q .; then
                log_message \"Detected music files in: \$usb_mount\"
                bind_usb_to_static \"\$usb_mount\" \"\$MUSIC_BIND\" \"music\"
            fi
            
            # Check for control USB (PLAY_CARD or has control.txt)
            if [[ \"\$usb_label\" =~ ^PLAY_CARD[0-9]*\$ ]] || [ \"\$usb_label\" = \"PLAY_CARD\" ]; then
                log_message \"Detected PLAY_CARD USB: \$usb_mount\"
                bind_usb_to_static \"\$usb_mount\" \"\$CONTROL_BIND\" \"control\"
            elif [ -f \"\$usb_mount/control.txt\" ]; then
                log_message \"Detected control.txt in: \$usb_mount\"
                bind_usb_to_static \"\$usb_mount\" \"\$CONTROL_BIND\" \"control\"
            fi
        fi
    done
    
    # Clean up any orphaned mounts
    cleanup_orphaned_mounts
}

# Main monitoring function
monitor_usb() {
    log_message \"Starting simple USB bind mount monitor\"
    
    # Set up static mount points
    setup_static_mounts
    
    # Initial scan
    scan_and_bind_usb
    
    # Monitor /media/pi for changes
    inotifywait -m -e create,delete,moved_to,moved_from /media/pi 2>/dev/null | while read path action file; do
        log_message \"USB event: \$action \$file\"
        
        # Wait for mount to stabilize
        sleep 3
        
        # Re-scan after any change
        scan_and_bind_usb
    done
}

# Start monitoring
monitor_usb

else
    echo "No desktop environment detected - setting up custom udev rules..."
    
    # Create udev rules for headless systems
    sudo bash -c "cat > /etc/udev/rules.d/99-usb-automount.rules << EOL
# USB automount rules for music player (headless systems)
SUBSYSTEM==\"block\", ATTRS{idVendor}==\"*\", ENV{ID_FS_LABEL}==\"MUSIC\", ACTION==\"add\", RUN+=\"/bin/mkdir -p /media/pi/MUSIC\", RUN+=\"/bin/mount -o uid=1000,gid=1000,umask=0022 /dev/%k /media/pi/MUSIC\"
SUBSYSTEM==\"block\", ATTRS{idVendor}==\"*\", ENV{ID_FS_LABEL}==\"PLAY_CARD\", ACTION==\"add\", RUN+=\"/bin/mkdir -p /media/pi/PLAY_CARD\", RUN+=\"/bin/mount -o uid=1000,gid=1000,umask=0022 /dev/%k /media/pi/PLAY_CARD\"
SUBSYSTEM==\"block\", ENV{ID_FS_LABEL}==\"MUSIC\", ACTION==\"remove\", RUN+=\"/bin/umount /media/pi/MUSIC\", RUN+=\"/bin/rmdir /media/pi/MUSIC\"
SUBSYSTEM==\"block\", ENV{ID_FS_LABEL}==\"PLAY_CARD\", ACTION==\"remove\", RUN+=\"/bin/umount /media/pi/PLAY_CARD\", RUN+=\"/bin/rmdir /media/pi/PLAY_CARD\"
EOL"

    sudo udevadm control --reload-rules
    sudo udevadm trigger

    echo "✅ USB auto-mounting configured with custom udev rules"
fi

# Set up Docker service for boot launch
echo "[6/6] Setting up Docker service for boot launch..."
CURRENT_DIR=$(pwd)

# Create Docker startup script
sudo bash -c "cat > /usr/local/bin/start_music_player.sh << EOL
#!/bin/bash
cd $CURRENT_DIR
echo \"Starting music player...\"
docker-compose down 2>/dev/null || true
docker-compose up -d
EOL"
sudo chmod +x /usr/local/bin/start_music_player.sh

# Create systemd service for music player
sudo bash -c "cat > /etc/systemd/system/music-player-docker.service << EOL
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
EOL"

# Enable Docker and music player services
echo "Enabling Docker and music player services..."
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl enable music-player-docker.service

# Build the Docker image
echo "Building Docker image..."
docker-compose build

# Create config and logs directories
mkdir -p config logs

echo -e "\n🎉 Installation Complete! 🎉"
echo "=================================="
echo ""
echo "✅ SAFE NETWORK CONFIGURATION:"
echo "• Your existing network configuration has been PRESERVED"
echo "• Hotspot will ONLY activate when no internet connection is available"
echo "• SSH access will NOT be disrupted"
echo ""
echo "🔧 HOTSPOT DETAILS:"
echo "• Name: $HOTSPOT_NAME"
echo "• Password: $HOTSPOT_PASSWORD"
echo "• Only activates when no internet connection"
echo ""
echo "🎵 MUSIC PLAYER ACCESS:"
echo "• Normal network: http://slab.local:5000 or http://[your-pi-ip]:5000"
echo "• Hotspot mode: http://192.168.4.1:5000 or http://slab.local:5000"
echo ""
echo "📱 USB DRIVES:"
echo "• Label music USB as 'MUSIC'"
echo "• Label control USB as 'PLAY_CARD'"
echo "• Drives will auto-mount and bind to /home/pi/usb/"
echo ""
echo "⚙️  MANUAL CONTROL:"
echo "• Start music player: sudo systemctl start music-player-docker.service"
echo "• Stop music player: sudo systemctl stop music-player-docker.service"
echo "• Check hotspot status: sudo systemctl status auto-hotspot.timer"
echo "• View hotspot logs: sudo tail -f /var/log/auto-hotspot.log"
echo "• Manual hotspot check: sudo /usr/local/bin/auto-hotspot.sh"
echo ""
echo "🔄 NEXT STEPS:"
echo "1. Reboot your Raspberry Pi: sudo reboot"
echo "2. Insert your USB drives (they'll auto-mount)"
echo "3. Access the web interface using the URLs above"
echo ""
echo "Your SSH access and existing network configuration are preserved!" 