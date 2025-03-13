#!/bin/bash

# Music Player Installation Script

echo "=== Raspberry Pi Music Player Installation ==="
echo "This script will install all dependencies and set up the music player."

# Update system
echo -e "\n[1/9] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo -e "\n[2/9] Installing system dependencies..."
sudo apt-get install -y vlc python3-pip python3-venv git

# Install USB automount
echo -e "\n[3/9] Installing USB automount..."
sudo apt-get install -y git debhelper build-essential
git clone https://github.com/rbrito/usbmount.git
cd usbmount
sudo dpkg-buildpackage -us -uc -b
cd ..
sudo apt-get update
sudo apt --fix-broken install -y
sudo dpkg -i usbmount_0.0.24_all.deb
echo "USB automount installed successfully."

# Install exFAT support and set up mounting points
echo -e "\n[4/9] Setting up exFAT support and USB mounting points..."
sudo apt-get update
sudo apt-get install -y exfat-fuse exfatprogs

# Create mounting points
echo "Creating USB mounting points..."
sudo mkdir -p /media/pi/MUSIC
sudo mkdir -p /media/pi/PLAY_CARD
sudo chown pi:pi /media/pi/MUSIC
sudo chown pi:pi /media/pi/PLAY_CARD

# Update fstab
echo "Updating fstab for persistent mounts..."
sudo bash -c "cat >> /etc/fstab << EOL
LABEL=PLAY_CARD   /media/pi/PLAY_CARD   exfat   defaults,nofail   0   0
LABEL=MUSIC   /media/pi/MUSIC  exfat   defaults,nofail   0   0
EOL"

# Create mount files
echo "Creating mount files..."
sudo bash -c "cat > /etc/systemd/system/media-pi-PLAY_CARD.mount << EOL
[Unit]
Description=Mount a USB labeled PLAY_CARD at /media/pi/PLAY_CARD
After=local-fs.target

[Mount]
Where=/media/pi/PLAY_CARD
What=LABEL=PLAY_CARD
Type=exfat
Options=defaults

[Install]
WantedBy=multi-user.target
EOL"

sudo bash -c "cat > /etc/systemd/system/media-pi-MUSIC.mount << EOL
[Unit]
Description=Mount a USB labeled MUSIC at /media/pi/MUSIC
After=local-fs.target

[Mount]
Where=/media/pi/MUSIC
What=LABEL=MUSIC
Type=exfat
Options=defaults

[Install]
WantedBy=multi-user.target
EOL"

# Create automount files
echo "Creating automount files for hotswap support..."
sudo bash -c "cat > /etc/systemd/system/media-pi-PLAY_CARD.automount << EOL
[Unit]
Description=Automount for /media/pi/PLAY_CARD

[Automount]
Where=/media/pi/PLAY_CARD

[Install]
WantedBy=multi-user.target
EOL"

sudo bash -c "cat > /etc/systemd/system/media-pi-MUSIC.automount << EOL
[Unit]
Description=Automount for /media/pi/MUSIC

[Automount]
Where=/media/pi/MUSIC

[Install]
WantedBy=multi-user.target
EOL"

# Enable mount and automount services
echo "Enabling mount and automount services..."
sudo systemctl daemon-reload
sudo systemctl enable media-pi-PLAY_CARD.mount
sudo systemctl enable media-pi-MUSIC.mount
sudo systemctl enable media-pi-PLAY_CARD.automount
sudo systemctl enable media-pi-MUSIC.automount
sudo systemctl start media-pi-PLAY_CARD.automount
sudo systemctl start media-pi-MUSIC.automount
echo "USB mounting configuration completed successfully."

# Set up auto hotspot
echo -e "\n[5/9] Setting up auto hotspot..."
sudo apt-get update
sudo apt-get install -y hostapd dnsmasq

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
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
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
echo "The hotspot will be available after reboot."

# Install Node.js
echo -e "\n[6/9] Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js is already installed."
fi

# Set up Python virtual environment
echo -e "\n[7/9] Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo -e "\n[8/9] Installing Python dependencies..."
pip install -r requirements.txt

# Build frontend
echo -e "\n[9/9] Building the frontend..."
cd frontend
npm install
npm run build
cd ..

# Create systemd service
echo -e "\n[Optional] Setting up systemd service..."
read -p "Do you want to set up the music player to start automatically on boot? (y/n): " setup_service

if [[ $setup_service == "y" || $setup_service == "Y" ]]; then
    SERVICE_PATH="/etc/systemd/system/music-player.service"
    CURRENT_DIR=$(pwd)
    
    sudo bash -c "cat > $SERVICE_PATH << EOL
[Unit]
Description=Raspberry Pi Music Player
After=network.target media-pi-MUSIC.mount media-pi-PLAY_CARD.mount auto-hotspot.service
Requires=media-pi-MUSIC.mount media-pi-PLAY_CARD.mount

[Service]
User=$USER
WorkingDirectory=$CURRENT_DIR
ExecStart=$CURRENT_DIR/venv/bin/python $CURRENT_DIR/main.py
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL"

    sudo systemctl daemon-reload
    sudo systemctl enable music-player.service
    sudo systemctl start music-player.service
    
    echo "Service installed and started. Check status with: sudo systemctl status music-player.service"
else
    echo "Skipping service setup. You can start the player manually with: python main.py"
fi

echo -e "\n=== Installation Complete! ==="
echo "=== How to Access the Music Player ==="
echo "1. Connect to the Wi-Fi hotspot: $HOTSPOT_NAME"
echo "2. Password: $HOTSPOT_PASSWORD"
echo "3. Open a web browser and navigate to: http://slab.local:5000"
echo ""
echo "You can also access using the IP address: http://192.168.4.1:5000"
echo "To start the player manually: source venv/bin/activate && python main.py" 