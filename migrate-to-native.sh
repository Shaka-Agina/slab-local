#!/bin/bash

# Migration Script: Docker to Native Deployment
# This script migrates from Docker-based deployment to native deployment

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           Docker to Native Migration Script             ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a regular user (not root/sudo)"
    exit 1
fi

print_header

print_status "This script will migrate your USB Music Player from Docker to native deployment"
print_status "Benefits: Better performance, no USB permission issues, easier development"
echo ""

# Check if Docker version is currently running
if docker-compose ps 2>/dev/null | grep -q "Up"; then
    print_status "Found running Docker containers"
    DOCKER_RUNNING=true
else
    print_status "No running Docker containers detected"
    DOCKER_RUNNING=false
fi

# Confirm migration
read -p "Do you want to proceed with migration to native deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Migration cancelled"
    exit 0
fi

print_step "1/6 - Backing Up Current Configuration"

# Create backup directory
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

print_status "Creating backup in $BACKUP_DIR/"

# Backup existing configuration
if [ -d "config" ]; then
    cp -r config "$BACKUP_DIR/"
    print_status "✅ Backed up config directory"
fi

if [ -d "logs" ]; then
    cp -r logs "$BACKUP_DIR/"
    print_status "✅ Backed up logs directory"
fi

if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "$BACKUP_DIR/"
    print_status "✅ Backed up docker-compose.yml"
fi

print_step "2/6 - Stopping Docker Services"

if [ "$DOCKER_RUNNING" = true ]; then
    print_status "Stopping Docker containers..."
    docker-compose down
    print_status "✅ Docker containers stopped"
else
    print_status "✅ No Docker containers to stop"
fi

# Stop any existing Docker systemd services
if systemctl is-active --quiet music-player-docker.service 2>/dev/null; then
    print_status "Stopping Docker systemd service..."
    sudo systemctl stop music-player-docker.service
    sudo systemctl disable music-player-docker.service
    print_status "✅ Docker systemd service disabled"
fi

print_step "3/6 - Installing Native Dependencies"

print_status "Installing system dependencies for native deployment..."
sudo apt-get update -qq
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    vlc \
    python3-vlc \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    udisks2 \
    exfat-fuse \
    exfatprogs \
    build-essential \
    python3-dev \
    libasound2-dev \
    pkg-config

print_status "✅ System dependencies installed"

print_step "4/6 - Setting Up Python Environment"

print_status "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install flask werkzeug flask-cors python-vlc mutagen

print_status "✅ Python environment ready"

print_step "5/6 - Configuring Native Services"

print_status "Setting up USB bind mount service..."

# Create USB directories
mkdir -p /home/pi/usb
chown -R pi:pi /home/pi/usb

# Create bind mount monitoring service (same as in install.sh)
sudo tee /usr/local/bin/usb-bind-mount-monitor.sh > /dev/null << 'EOL'
#!/bin/bash
# Monitor and create bind mounts for USB drives with proper permissions

mkdir -p /home/pi/usb
chown -R pi:pi /home/pi/usb

while true; do
    # Handle MUSIC USB drives
    for music_mount in /media/pi/MUSIC*; do
        if mountpoint -q "$music_mount" 2>/dev/null; then
            bind_target="/home/pi/usb/music"
            if ! mountpoint -q "$bind_target" 2>/dev/null; then
                mkdir -p "$bind_target"
                chown pi:pi "$bind_target"
                if mount --bind "$music_mount" "$bind_target" 2>/dev/null; then
                    chown -R pi:pi "$bind_target" 2>/dev/null || true
                    chmod -R 755 "$bind_target" 2>/dev/null || true
                    echo "$(date): Created bind mount: $music_mount -> $bind_target"
                fi
            fi
            break
        fi
    done
    
    # Handle PLAY_CARD USB drives
    for playcard_mount in /media/pi/PLAY_CARD*; do
        if mountpoint -q "$playcard_mount" 2>/dev/null; then
            bind_target="/home/pi/usb/playcard"
            if ! mountpoint -q "$bind_target" 2>/dev/null; then
                mkdir -p "$bind_target"
                chown pi:pi "$bind_target"
                if mount --bind "$playcard_mount" "$bind_target" 2>/dev/null; then
                    chown -R pi:pi "$bind_target" 2>/dev/null || true
                    chmod -R 755 "$bind_target" 2>/dev/null || true
                    echo "$(date): Created bind mount: $playcard_mount -> $bind_target"
                fi
            fi
            break
        fi
    done
    
    # Clean up stale bind mounts
    if mountpoint -q "/home/pi/usb/music" 2>/dev/null; then
        music_exists=false
        for music_mount in /media/pi/MUSIC*; do
            if mountpoint -q "$music_mount" 2>/dev/null; then
                music_exists=true
                break
            fi
        done
        if [ "$music_exists" = false ]; then
            umount "/home/pi/usb/music" 2>/dev/null || true
            echo "$(date): Removed stale bind mount: /home/pi/usb/music"
        fi
    fi
    
    if mountpoint -q "/home/pi/usb/playcard" 2>/dev/null; then
        playcard_exists=false
        for playcard_mount in /media/pi/PLAY_CARD*; do
            if mountpoint -q "$playcard_mount" 2>/dev/null; then
                playcard_exists=true
                break
            fi
        done
        if [ "$playcard_exists" = false ]; then
            umount "/home/pi/usb/playcard" 2>/dev/null || true
            echo "$(date): Removed stale bind mount: /home/pi/usb/playcard"
        fi
    fi
    
    sleep 3
done
EOL

sudo chmod +x /usr/local/bin/usb-bind-mount-monitor.sh

# Create systemd service for USB monitoring
sudo tee /etc/systemd/system/usb-bind-mount-monitor.service > /dev/null << 'EOL'
[Unit]
Description=USB Bind Mount Monitor for Music Player
After=graphical.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/usb-bind-mount-monitor.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Create native music player service
print_status "Creating native systemd service..."
sudo tee /etc/systemd/system/usb-music-player.service > /dev/null << EOL
[Unit]
Description=USB Music Player
After=graphical.target usb-bind-mount-monitor.service pulseaudio.service
Wants=usb-bind-mount-monitor.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=$PWD
Environment=PATH=$PWD/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=$PWD
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse
Environment=CONTROL_FILE_NAME=playMusic.txt
Environment=WEB_PORT=5000
Environment=DEFAULT_VOLUME=70
ExecStart=$PWD/venv/bin/python $PWD/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Configure audio system
sudo usermod -aG audio $USER
systemctl --user enable pulseaudio 2>/dev/null || true
systemctl --user start pulseaudio 2>/dev/null || true

print_status "✅ Native services configured"

print_step "6/6 - Starting Native Services"

print_status "Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable usb-bind-mount-monitor.service
sudo systemctl enable usb-music-player.service
sudo systemctl start usb-bind-mount-monitor.service
sudo systemctl start usb-music-player.service

# Wait a moment and check status
sleep 3
if systemctl is-active --quiet usb-music-player.service; then
    print_status "✅ Native music player service started successfully"
else
    print_warning "Service may have issues. Check logs with: sudo journalctl -u usb-music-player.service -f"
fi

# Final output
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Migration to Native Complete!                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}🎵 Migration Summary:${NC}"
echo "• Docker deployment → Native deployment"
echo "• Configuration preserved in config/ and logs/"
echo "• Backup created in $BACKUP_DIR/"
echo "• Better performance and no USB permission issues"
echo ""

echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}'):5000"
echo ""

echo "🔧 Native Service Management:"
echo "• Status: sudo systemctl status usb-music-player.service"
echo "• Logs: sudo journalctl -u usb-music-player.service -f"
echo "• Restart: sudo systemctl restart usb-music-player.service"
echo "• Stop: sudo systemctl stop usb-music-player.service"
echo ""

echo "🔧 Development Mode:"
echo "• cd $PWD"
echo "• source venv/bin/activate"
echo "• python app.py"
echo ""

echo "🗂️ Docker Files:"
echo "• Docker files are preserved for fallback if needed"
echo "• Backup of previous setup in $BACKUP_DIR/"
echo "• To rollback: Use files in $BACKUP_DIR/ and docker-compose up -d"
echo ""

print_status "Migration complete! Your USB music player is now running natively! 🎵" 