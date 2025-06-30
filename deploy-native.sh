#!/bin/bash

# Native USB Music Player Deployment Script
# This runs the music player directly on the Pi host, avoiding Docker USB permission issues

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a regular user (not root/sudo)"
    exit 1
fi

print_step "1/6 - Installing System Dependencies"

print_status "Updating package list..."
sudo apt-get update -qq

print_status "Installing audio and USB utilities..."
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    udisks2 \
    exfat-fuse \
    exfatprogs \
    curl \
    git

print_step "2/6 - Setting Up Python Environment"

print_status "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install flask pygame mutagen

print_step "3/6 - Configuring Audio System"

print_status "Setting up PulseAudio for user session..."
# Ensure PulseAudio starts with user session
systemctl --user enable pulseaudio
systemctl --user start pulseaudio || true

# Add user to audio group
sudo usermod -aG audio $USER

print_step "4/6 - Setting Up USB Auto-mounting"

print_status "Configuring desktop environment USB auto-mounting..."

# Create USB directories
mkdir -p /home/pi/usb
chown -R pi:pi /home/pi/usb

# Create bind mount monitoring service
print_status "Creating USB bind mount service..."
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

# Create systemd service
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

print_step "5/6 - Setting Up Native Music Player Service"

print_status "Creating systemd service for music player..."
sudo tee /etc/systemd/system/usb-music-player.service > /dev/null << EOL
[Unit]
Description=USB Music Player
After=graphical.target usb-bind-mount-monitor.service pulseaudio.service
Wants=usb-bind-mount-monitor.service

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/slab-local
Environment=PATH=/home/pi/slab-local/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=PYTHONPATH=/home/pi/slab-local
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse
Environment=CONTROL_FILE_NAME=playMusic.txt
Environment=WEB_PORT=5000
Environment=DEFAULT_VOLUME=70
ExecStart=/home/pi/slab-local/venv/bin/python /home/pi/slab-local/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

print_step "6/6 - Starting Services"

print_status "Enabling and starting USB music player service..."
sudo systemctl daemon-reload
sudo systemctl enable usb-music-player.service

# Stop Docker version if running
docker-compose down 2>/dev/null || true

# Start native service
sudo systemctl start usb-music-player.service

print_status "Creating directories for configuration and logs..."
mkdir -p ./config
mkdir -p ./logs
chown -R pi:pi ./config ./logs

echo ""
echo "✅ Native USB Music Player deployment complete!"
echo ""
echo "🎵 Architecture:"
echo "• Native Python service running directly on Pi host"
echo "• No Docker containers - direct access to USB drives"
echo "• Bind mounts provide proper permissions"
echo "• PulseAudio integration for audio output"
echo ""
echo "🔧 Service Management:"
echo "• Status: sudo systemctl status usb-music-player.service"
echo "• Logs: sudo journalctl -u usb-music-player.service -f"
echo "• Restart: sudo systemctl restart usb-music-player.service"
echo ""
echo "🌐 Web Interface: http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "🔌 USB Setup:"
echo "1. Label USB drives as 'MUSIC' and 'PLAY_CARD'"
echo "2. Insert drives - they'll auto-mount to /media/pi/"
echo "3. Bind mounts will be created at /home/pi/usb/ with proper permissions"
echo "4. Service will automatically detect and use them" 