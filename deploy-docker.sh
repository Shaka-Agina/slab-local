#!/bin/bash

# USB Music Player Docker Deployment Script for Raspberry Pi

set -e

echo "=== USB Music Player Docker Deployment ==="
echo "This script will set up Docker and deploy the music player container."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    print_warning "This script is designed for Raspberry Pi. Continuing anyway..."
fi

# Update system
print_status "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_status "Docker installed successfully"
else
    print_status "Docker is already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    sudo apt-get install -y docker-compose
    print_status "Docker Compose installed successfully"
else
    print_status "Docker Compose is already installed"
fi

# Install system dependencies for USB mounting
print_status "Installing USB mounting dependencies..."
sudo apt-get install -y exfat-fuse exfatprogs usbmount git

# Install VLC for audio playback (if not already present)
print_status "Checking VLC installation..."
if command -v vlc &> /dev/null; then
    print_status "VLC is already installed"
    
    # Test VLC functionality
    if vlc --version >/dev/null 2>&1; then
        print_status "VLC is working correctly"
    else
        print_warning "VLC installation may be broken. Attempting repair..."
        sudo apt-get install -f
        sudo apt-get install --reinstall -y vlc-bin vlc-plugin-base
    fi
else
    print_status "Installing VLC..."
    sudo apt-get install -f  # Fix any broken packages first
    sudo apt-get install -y vlc vlc-plugin-base
fi

# Create USB mounting points
print_status "Setting up USB mounting points..."
sudo mkdir -p /media/pi/MUSIC
sudo mkdir -p /media/pi/PLAY_CARD
sudo chown pi:pi /media/pi/MUSIC
sudo chown pi:pi /media/pi/PLAY_CARD

# Set up USB automounting with systemd
print_status "Configuring USB automounting..."

# Create mount units for USB drives
sudo tee /etc/systemd/system/media-pi-MUSIC.mount > /dev/null << EOL
[Unit]
Description=Mount USB drive labeled MUSIC
After=local-fs.target

[Mount]
Where=/media/pi/MUSIC
What=LABEL=MUSIC
Type=exfat
Options=defaults,nofail,uid=pi,gid=pi

[Install]
WantedBy=multi-user.target
EOL

sudo tee /etc/systemd/system/media-pi-PLAY_CARD.mount > /dev/null << EOL
[Unit]
Description=Mount USB drive labeled PLAY_CARD
After=local-fs.target

[Mount]
Where=/media/pi/PLAY_CARD
What=LABEL=PLAY_CARD
Type=exfat
Options=defaults,nofail,uid=pi,gid=pi

[Install]
WantedBy=multi-user.target
EOL

# Create automount units
sudo tee /etc/systemd/system/media-pi-MUSIC.automount > /dev/null << EOL
[Unit]
Description=Automount for MUSIC USB drive

[Automount]
Where=/media/pi/MUSIC

[Install]
WantedBy=multi-user.target
EOL

sudo tee /etc/systemd/system/media-pi-PLAY_CARD.automount > /dev/null << EOL
[Unit]
Description=Automount for PLAY_CARD USB drive

[Automount]
Where=/media/pi/PLAY_CARD

[Install]
WantedBy=multi-user.target
EOL

# Enable and start automount services
sudo systemctl daemon-reload
sudo systemctl enable media-pi-MUSIC.automount
sudo systemctl enable media-pi-PLAY_CARD.automount
sudo systemctl start media-pi-MUSIC.automount
sudo systemctl start media-pi-PLAY_CARD.automount

print_status "USB automounting configured"

# Create necessary directories for Docker volumes
print_status "Creating Docker volume directories..."
mkdir -p ./config
mkdir -p ./logs

# Set up audio group permissions
print_status "Setting up audio permissions..."
sudo usermod -aG audio $USER

# Build and start the Docker container
print_status "Building and starting the music player container..."

# Stop any existing container
docker-compose down 2>/dev/null || true

# Build the image
docker-compose build

# Start the container
docker-compose up -d

# Wait for container to be ready
print_status "Waiting for container to start..."
sleep 10

# Check container status
if docker-compose ps | grep -q "Up"; then
    print_status "Container started successfully!"
    
    # Get the container IP (should be host network)
    echo ""
    echo "=== Deployment Complete! ==="
    echo "The USB Music Player is now running in Docker"
    echo ""
    echo "Access the web interface at:"
    echo "  - http://localhost:5000"
    echo "  - http://$(hostname -I | awk '{print $1}'):5000"
    echo ""
    echo "USB Drive Setup:"
    echo "  - Label your music USB drive as 'MUSIC'"
    echo "  - Label your control USB drive as 'PLAY_CARD'"
    echo "  - Create a file named 'playMusic.txt' on the PLAY_CARD drive"
    echo ""
    echo "Container Management:"
    echo "  - View logs: docker-compose logs -f"
    echo "  - Stop: docker-compose down"
    echo "  - Restart: docker-compose restart"
    echo "  - Rebuild: docker-compose build --no-cache"
    echo ""
else
    print_error "Container failed to start. Check logs with: docker-compose logs"
    exit 1
fi

# Optional: Set up systemd service for auto-start
read -p "Do you want to set up auto-start on boot? (y/n): " setup_autostart

if [[ $setup_autostart == "y" || $setup_autostart == "Y" ]]; then
    print_status "Setting up auto-start service..."
    
    CURRENT_DIR=$(pwd)
    
    sudo tee /etc/systemd/system/usb-music-player.service > /dev/null << EOL
[Unit]
Description=USB Music Player Docker Container
Requires=docker.service
After=docker.service media-pi-MUSIC.automount media-pi-PLAY_CARD.automount

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$CURRENT_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable usb-music-player.service
    
    print_status "Auto-start service enabled"
fi

print_status "Deployment script completed successfully!"

# Note about Docker group
if groups $USER | grep -q docker; then
    print_status "You're already in the docker group"
else
    print_warning "You may need to log out and back in for Docker group permissions to take effect"
fi 