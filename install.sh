#!/bin/bash

# Music Player Installation Script for Desktop Environment

# Set non-interactive mode to prevent prompts
export DEBIAN_FRONTEND=noninteractive

# Configure automatic service restarts
echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

# Configure needrestart to not prompt
sudo mkdir -p /etc/needrestart/conf.d
echo '$nrconf{restart} = "a";' | sudo tee /etc/needrestart/conf.d/50-auto.conf > /dev/null

echo "=== Raspberry Pi Music Player Installation (Desktop Environment) ==="
echo "This script will install all dependencies and set up the music player."
echo "Note: This script assumes you're running Raspberry Pi OS with Desktop Environment"
echo "which includes auto-mounting and VLC pre-installed."

# Check if running on desktop environment
if [ -z "$DISPLAY" ]; then
    echo "WARNING: No display detected. This script is designed for desktop environments."
    echo "If you're running headless, consider using the headless installation instead."
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

# Check and disable RF kill if active
echo -e "\n[Prerequisite] Checking wireless status..."
if command -v rfkill &> /dev/null; then
    # Check if wireless is blocked
    if rfkill list wifi | grep -q "Soft blocked: yes"; then
        echo "Wireless is soft blocked. Unblocking..."
        sudo rfkill unblock wifi
    fi
    
    if rfkill list wifi | grep -q "Hard blocked: yes"; then
        echo "WARNING: Wireless is hard blocked. This is typically caused by a physical switch."
        echo "Please enable your wireless hardware switch and then press Enter to continue..."
        read -p "Press Enter after enabling wireless or Ctrl+C to cancel installation..." 
    fi
    
    echo "Wireless status:"
    rfkill list wifi
else
    echo "rfkill not found. Installing..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y rfkill
    echo "Installed rfkill utility for wireless management."
fi

# Update system
echo -e "\n[1/5] Updating system packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update

# Fix any broken VLC packages before upgrading system
echo "Checking for package conflicts before system upgrade..."
if dpkg -l | grep -q vlc; then
    echo "VLC packages detected. Preventing conflicts during upgrade..."
    
    # Fix any currently broken packages
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y || true
    
    # Hold VLC packages to prevent conflicts during upgrade
    sudo apt-mark hold vlc vlc-bin vlc-plugin-base vlc-plugin-qt vlc-plugin-skins2 2>/dev/null || true
    
    # Perform system upgrade
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    # Unhold VLC packages after upgrade
    sudo apt-mark unhold vlc vlc-bin vlc-plugin-base vlc-plugin-qt vlc-plugin-skins2 2>/dev/null || true
    
    echo "System upgrade completed. VLC packages preserved."
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
fi

# Install system dependencies (VLC should already be installed on desktop)
echo -e "\n[2/5] Installing system dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv git curl

# Verify VLC is installed and working
echo "Checking VLC installation..."
if command -v vlc &> /dev/null; then
    echo "VLC is already installed."
    
    # Test VLC functionality
    if vlc --version >/dev/null 2>&1; then
        echo "VLC is working correctly."
    else
        echo "VLC installation may be broken. Attempting repair..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -f
        sudo DEBIAN_FRONTEND=noninteractive apt-get install --reinstall vlc-bin vlc-plugin-base
    fi
else
    echo "VLC not found. Installing with dependency resolution..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f  # Fix any broken packages first
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vlc
fi

# Install Docker
echo -e "\n[3/5] Installing Docker..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "Docker installed. You may need to log out and back in for group changes to take effect."
else
    echo "Docker is already installed."
fi

# Install Docker Compose
echo "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing..."
    
    # First try with pip3 (for compatibility)
    if command -v pip3 &> /dev/null; then
        echo "Attempting pip3 installation..."
        sudo pip3 install docker-compose
        
        # Verify installation
        if command -v docker-compose &> /dev/null; then
            echo "Docker Compose installed successfully via pip3."
        else
            echo "pip3 installation failed. Trying binary installation..."
            # Install via binary (more reliable method)
            DOCKER_COMPOSE_VERSION="v2.20.3"
            echo "Installing Docker Compose $DOCKER_COMPOSE_VERSION..."
            
            # Download and install docker-compose binary
            sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            
            # Create symlink for easier access
            sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            
            # Verify installation
            if command -v docker-compose &> /dev/null; then
                echo "Docker Compose installed successfully via binary."
                docker-compose --version
            else
                echo "ERROR: Docker Compose installation failed. Please install manually."
                exit 1
            fi
        fi
    else
        echo "pip3 not available. Installing Docker Compose binary directly..."
        # Install via binary
        DOCKER_COMPOSE_VERSION="v2.20.3"
        echo "Installing Docker Compose $DOCKER_COMPOSE_VERSION..."
        
        # Download and install docker-compose binary
        sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Create symlink for easier access
        sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        # Verify installation
        if command -v docker-compose &> /dev/null; then
            echo "Docker Compose installed successfully via binary."
            docker-compose --version
        else
            echo "ERROR: Docker Compose installation failed. Please install manually."
            exit 1
        fi
    fi
else
    echo "Docker Compose is already installed."
    docker-compose --version
fi

# Set up auto hotspot
echo -e "\n[4/5] Setting up auto hotspot..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update

# Install and verify hostapd and dnsmasq
echo "Installing hostapd and dnsmasq..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y hostapd dnsmasq

# Verify installation
if ! dpkg -l | grep -q hostapd || ! dpkg -l | grep -q dnsmasq; then
    echo "ERROR: Failed to install hostapd or dnsmasq. Retrying..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall hostapd dnsmasq
    
    # Check again
    if ! dpkg -l | grep -q hostapd || ! dpkg -l | grep -q dnsmasq; then
        echo "CRITICAL ERROR: Could not install required packages hostapd and dnsmasq."
        echo "Please check your internet connection and try again."
        exit 1
    fi
fi

# Unmask services in case they are masked
echo "Unmasking services..."
sudo systemctl unmask hostapd
sudo systemctl unmask dnsmasq

# Stop services initially
sudo systemctl stop hostapd
sudo systemctl stop dnsmasq

# Configure hostapd
RANDOM_SUFFIX=$(printf "%04d" $((RANDOM % 10000)))
HOTSPOT_NAME="S L A B - $RANDOM_SUFFIX"
HOTSPOT_PASSWORD="slabmusic"

echo "Creating hostapd configuration..."
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

# Configure hostapd default
sudo bash -c "cat > /etc/default/hostapd << EOL
DAEMON_CONF=\"/etc/hostapd/hostapd.conf\"
EOL"

# Configure dnsmasq
echo "Configuring dnsmasq..."
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig 2>/dev/null || true
sudo bash -c "cat > /etc/dnsmasq.conf << EOL
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
domain=local
address=/slab.local/192.168.4.1
address=/www.slab.local/192.168.4.1
EOL"

# Configure network interfaces
echo "Configuring network interfaces..."
sudo bash -c "cat > /etc/network/interfaces << EOL
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
    network 192.168.4.0
    broadcast 192.168.4.255
EOL"

# Enable IP forwarding
echo "Enabling IP forwarding..."
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Create startup script
echo "Creating auto hotspot startup script..."
sudo bash -c "cat > /usr/local/bin/start_hotspot.sh << EOL
#!/bin/bash
# Ensure wireless is not blocked
if command -v rfkill &> /dev/null; then
    rfkill unblock wifi
fi
sudo systemctl start hostapd
sudo systemctl start dnsmasq
EOL"
sudo chmod +x /usr/local/bin/start_hotspot.sh

# Create systemd service for hotspot
echo "Creating systemd service for auto hotspot..."
sudo bash -c "cat > /etc/systemd/system/auto-hotspot.service << EOL
[Unit]
Description=Auto Hotspot Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start_hotspot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL"

# Enable services
echo "Enabling hotspot services..."
sudo systemctl daemon-reload
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq
sudo systemctl enable auto-hotspot.service

echo "Auto hotspot configured with name: $HOTSPOT_NAME and password: $HOTSPOT_PASSWORD"

# Set up Docker service for boot launch
echo -e "\n[5/5] Setting up Docker service for boot launch..."
CURRENT_DIR=$(pwd)

# Create USB mount directories
echo "Creating USB mount directories..."
sudo mkdir -p /media/pi/MUSIC /media/pi/PLAY_CARD
sudo chown pi:pi /media/pi/MUSIC /media/pi/PLAY_CARD

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

echo -e "\n=== Installation Complete! ==="
echo "=== Important Notes ==="
echo "1. USB devices will be auto-mounted by the desktop environment"
echo "2. Label your USB drives as 'MUSIC' for music files and 'PLAY_CARD' for control files"
echo "3. The music player will start automatically on boot"
echo ""
echo "=== How to Access the Music Player ==="
echo "1. Connect to the Wi-Fi hotspot: $HOTSPOT_NAME"
echo "2. Password: $HOTSPOT_PASSWORD"
echo "3. Open a web browser and navigate to: http://slab.local:5000"
echo ""
echo "You can also access using the IP address: http://192.168.4.1:5000"
echo ""
echo "=== Manual Control ==="
echo "Start: sudo systemctl start music-player-docker.service"
echo "Stop: sudo systemctl stop music-player-docker.service"
echo "Status: sudo systemctl status music-player-docker.service"
echo "Logs: docker-compose logs -f"
echo ""
echo "=== Next Steps ==="
echo "1. Reboot your Raspberry Pi to start all services"
echo "2. Insert your USB drives (they'll be auto-mounted)"
echo "3. Connect to the hotspot and access the web interface"

# Final check for RF kill before completion
echo -e "\nPerforming final wireless check..."
if command -v rfkill &> /dev/null; then
    if rfkill list wifi | grep -q "blocked: yes"; then
        echo "WARNING: Wireless is still blocked. The hotspot may not work until wireless is enabled."
        echo "You can enable wireless with: sudo rfkill unblock wifi"
    else
        echo "Wireless is enabled and ready for hotspot."
    fi
fi

echo -e "\nReboot now to start all services: sudo reboot" 