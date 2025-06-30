#!/bin/bash

# One-Click USB Music Player Installer
# Native deployment with Docker fallback option

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
    echo "║              USB Music Player Installer                 ║"
    echo "║                  Native Deployment                      ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a regular user (not root/sudo)"
    print_status "Usage: ./install.sh"
    exit 1
fi

print_header

# Check if we're on a Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    print_warning "This doesn't appear to be a Raspberry Pi"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled"
        exit 0
    fi
fi

# Offer deployment choice
echo ""
print_status "Choose deployment method:"
echo "1. Native (Recommended) - Direct host deployment, best performance, no USB permission issues"
echo "2. Docker - Containerized deployment (legacy option)"
echo ""
read -p "Enter choice [1-2] (default: 1): " deployment_choice
deployment_choice=${deployment_choice:-1}

echo ""
case $deployment_choice in
    1)
        print_status "Selected: Native deployment"
        DEPLOYMENT_METHOD="native"
        ;;
    2)
        print_status "Selected: Docker deployment"
        DEPLOYMENT_METHOD="docker"
        ;;
    *)
        print_error "Invalid choice. Using native deployment (recommended)"
        DEPLOYMENT_METHOD="native"
        ;;
esac

print_step "1/7 - System Check and Preparation"

print_status "Checking system requirements..."
# Check for required commands
MISSING_DEPS=()
for cmd in python3 git; do
    if ! command -v $cmd >/dev/null 2>&1; then
        MISSING_DEPS+=($cmd)
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    print_warning "Missing dependencies: ${MISSING_DEPS[*]}"
    print_status "Installing missing dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y ${MISSING_DEPS[*]}
fi

print_step "2/7 - Installing System Dependencies"

print_status "Updating package list..."
sudo apt-get update -qq

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
    print_status "Installing dependencies for native deployment..."
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
        curl \
        git \
        build-essential \
        python3-dev \
        libasound2-dev \
        pkg-config
else
    print_status "Installing dependencies for Docker deployment..."
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
        curl \
        git \
        docker.io \
        docker-compose
        
    # Add user to docker group
    sudo usermod -aG docker $USER
    print_warning "You may need to log out and back in for Docker group changes to take effect"
fi

print_step "3/7 - Setting Up Audio System"

print_status "Configuring audio system..."
# Ensure user is in audio group
sudo usermod -aG audio $USER

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
    # Configure PulseAudio for user session
    systemctl --user enable pulseaudio 2>/dev/null || true
    systemctl --user start pulseaudio 2>/dev/null || true
fi

print_step "4/7 - Setting Up USB Auto-mounting"

print_status "Configuring USB auto-mounting system..."

# Create USB directories
mkdir -p /home/pi/usb
chown -R pi:pi /home/pi/usb

# Create bind mount monitoring service
print_status "Installing USB bind mount service..."
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

sudo systemctl daemon-reload
sudo systemctl enable usb-bind-mount-monitor.service
sudo systemctl start usb-bind-mount-monitor.service

print_step "5/7 - Setting Up Python Environment"

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    
    print_status "Installing Python dependencies..."
    pip install --upgrade pip
    pip install flask werkzeug flask-cors python-vlc mutagen
    
    print_status "Python environment ready"
else
    print_status "Skipping Python setup for Docker deployment"
fi

print_step "6/7 - Creating Application Service"

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
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

    sudo systemctl daemon-reload
    sudo systemctl enable usb-music-player.service
else
    print_status "Docker service will be managed via docker-compose"
fi

print_step "7/7 - Starting Services"

# Create required directories
print_status "Creating configuration directories..."
mkdir -p ./config
mkdir -p ./logs
chown -R pi:pi ./config ./logs

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
    print_status "Starting native music player service..."
    sudo systemctl start usb-music-player.service
    
    # Wait a moment and check status
    sleep 3
    if systemctl is-active --quiet usb-music-player.service; then
        print_status "✅ Native service started successfully"
    else
        print_warning "Service may have issues. Check logs with: sudo journalctl -u usb-music-player.service -f"
    fi
else
    print_status "Building and starting Docker containers..."
    docker-compose build
    docker-compose up -d
    
    # Wait a moment and check status
    sleep 5
    if docker-compose ps | grep -q "Up"; then
        print_status "✅ Docker containers started successfully"
    else
        print_warning "Containers may have issues. Check logs with: docker-compose logs -f"
    fi
fi

# Final output
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 Installation Complete!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
    echo -e "${BLUE}🎵 Native USB Music Player Setup Complete!${NC}"
    echo ""
    echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}'):5000"
    echo ""
    echo "🔧 Service Management:"
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
else
    echo -e "${BLUE}🐳 Docker USB Music Player Setup Complete!${NC}"
    echo ""
    echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}'):5000"
    echo ""
    echo "🔧 Service Management:"
    echo "• Status: docker-compose ps"
    echo "• Logs: docker-compose logs -f"
    echo "• Restart: docker-compose restart"
    echo "• Stop: docker-compose down"
    echo ""
fi

echo "🔌 USB Setup:"
echo "1. Label USB drives as 'MUSIC' and 'PLAY_CARD'"
echo "2. Insert drives - they'll auto-mount to /media/pi/"
echo "3. Bind mounts will be created at /home/pi/usb/ with proper permissions"
echo "4. Create 'playMusic.txt' on PLAY_CARD drive to control playback"
echo ""

echo "🎛️ Control Files (create on PLAY_CARD USB):"
echo "• playMusic.txt - Start/stop playback"
echo "• nextTrack.txt - Skip to next track"  
echo "• prevTrack.txt - Previous track"
echo "• volumeUp.txt - Increase volume"
echo "• volumeDown.txt - Decrease volume"
echo ""

if [ "$DEPLOYMENT_METHOD" = "native" ]; then
    echo "✨ Benefits of Native Deployment:"
    echo "• No USB permission issues"
    echo "• Better audio performance"
    echo "• Faster startup and operation"
    echo "• Easier debugging and development"
    echo "• Direct hardware access"
fi

echo ""
print_status "Installation complete! Insert your USB drives and enjoy your music! 🎵" 