#!/bin/bash

# Robust USB Bind Mount Fix Script
# Handles USB removal/insertion cycles properly

set -e

echo "=== Robust USB Bind Mount Fix Script ==="
echo "This script sets up robust bind mounts that handle USB removal/insertion properly."
echo ""

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

print_status "Installing USB mounting utilities..."
sudo apt-get update -qq
sudo apt-get install -y udisks2 exfat-fuse exfatprogs

print_status "Cleaning up any existing USB directory conflicts..."
# Force unmount and remove any existing bind mounts
sudo umount /home/pi/usb/music 2>/dev/null || true
sudo umount /home/pi/usb/playcard 2>/dev/null || true
sudo rm -rf /home/pi/usb

print_status "Setting up bind mount directory structure..."
sudo mkdir -p /home/pi/usb
sudo chown pi:pi /home/pi/usb
sudo chmod 755 /home/pi/usb

# Remove old services
print_status "Removing old services..."
sudo systemctl stop usb-bind-mount-monitor.service 2>/dev/null || true
sudo systemctl disable usb-bind-mount-monitor.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/usb-bind-mount-monitor.service
sudo rm -f /usr/local/bin/usb-bind-mount-monitor.sh

print_status "Creating robust USB bind mount monitoring service..."
sudo tee /usr/local/bin/usb-bind-mount-monitor.sh > /dev/null << 'EOL'
#!/bin/bash
# Robust monitor for USB bind mounts with proper cleanup

# Function to safely create bind mount
create_bind_mount() {
    local source="$1"
    local target="$2"
    local label="$3"
    
    echo "$(date): Creating bind mount for $label: $source -> $target"
    
    # Remove target directory if it exists and is corrupted
    if [ -d "$target" ]; then
        # Try to access the directory - if it fails, it's corrupted
        if ! ls "$target" >/dev/null 2>&1; then
            echo "$(date): Target directory $target is corrupted, removing..."
            sudo rm -rf "$target" 2>/dev/null || true
        fi
    fi
    
    # Ensure clean target directory
    mkdir -p "$target"
    chown pi:pi "$target"
    chmod 755 "$target"
    
    # Create bind mount
    if mount --bind "$source" "$target" 2>/dev/null; then
        chown -R pi:pi "$target" 2>/dev/null || true
        chmod -R 755 "$target" 2>/dev/null || true
        echo "$(date): ✅ Successfully created bind mount for $label"
        return 0
    else
        echo "$(date): ❌ Failed to create bind mount for $label"
        return 1
    fi
}

# Function to safely remove bind mount
remove_bind_mount() {
    local target="$1"
    local label="$2"
    
    echo "$(date): Removing bind mount for $label: $target"
    
    # Force unmount (even if busy)
    if mountpoint -q "$target" 2>/dev/null; then
        umount -l "$target" 2>/dev/null || umount -f "$target" 2>/dev/null || true
    fi
    
    # Remove and recreate clean directory
    rm -rf "$target" 2>/dev/null || true
    mkdir -p "$target"
    chown pi:pi "$target"
    chmod 755 "$target"
    
    echo "$(date): 🗑️ Cleaned up bind mount for $label"
}

# Ensure base directory exists
mkdir -p /home/pi/usb
chown pi:pi /home/pi/usb
chmod 755 /home/pi/usb

echo "$(date): Robust USB bind mount monitor started"

while true; do
    # Handle MUSIC USB drives
    music_found=false
    for music_mount in /media/pi/MUSIC*; do
        if mountpoint -q "$music_mount" 2>/dev/null; then
            music_found=true
            bind_target="/home/pi/usb/music"
            
            # Create bind mount if it doesn't exist or is not mounted
            if ! mountpoint -q "$bind_target" 2>/dev/null; then
                create_bind_mount "$music_mount" "$bind_target" "MUSIC"
            fi
            break
        fi
    done
    
    # Clean up MUSIC bind mount if no USB drive found
    if [ "$music_found" = false ] && mountpoint -q "/home/pi/usb/music" 2>/dev/null; then
        remove_bind_mount "/home/pi/usb/music" "MUSIC"
    fi
    
    # Handle PLAY_CARD USB drives
    playcard_found=false
    for playcard_mount in /media/pi/PLAY_CARD*; do
        if mountpoint -q "$playcard_mount" 2>/dev/null; then
            playcard_found=true
            bind_target="/home/pi/usb/playcard"
            
            # Create bind mount if it doesn't exist or is not mounted
            if ! mountpoint -q "$bind_target" 2>/dev/null; then
                create_bind_mount "$playcard_mount" "$bind_target" "PLAY_CARD"
            fi
            break
        fi
    done
    
    # Clean up PLAY_CARD bind mount if no USB drive found
    if [ "$playcard_found" = false ] && mountpoint -q "/home/pi/usb/playcard" 2>/dev/null; then
        remove_bind_mount "/home/pi/usb/playcard" "PLAY_CARD"
    fi
    
    # Ensure clean directories exist even when no USB drives are present
    if [ "$music_found" = false ] && [ ! -d "/home/pi/usb/music" ]; then
        mkdir -p "/home/pi/usb/music"
        chown pi:pi "/home/pi/usb/music"
        chmod 755 "/home/pi/usb/music"
    fi
    
    if [ "$playcard_found" = false ] && [ ! -d "/home/pi/usb/playcard" ]; then
        mkdir -p "/home/pi/usb/playcard"
        chown pi:pi "/home/pi/usb/playcard"
        chmod 755 "/home/pi/usb/playcard"
    fi
    
    sleep 2
done
EOL

sudo chmod +x /usr/local/bin/usb-bind-mount-monitor.sh

print_status "Creating robust systemd service..."
sudo tee /etc/systemd/system/usb-bind-mount-monitor.service > /dev/null << 'EOL'
[Unit]
Description=Robust USB Bind Mount Monitor for Music Player
After=graphical.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/usb-bind-mount-monitor.sh
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable usb-bind-mount-monitor.service
sudo systemctl start usb-bind-mount-monitor.service

print_status "Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "✅ Robust USB bind mount fix complete!"
echo ""
print_status "Checking service status..."
sudo systemctl status usb-bind-mount-monitor.service --no-pager -l

echo ""
print_status "Checking directory permissions..."
ls -la /home/pi/usb/

echo ""
echo "🔧 Improvements in this version:"
echo "• 🛡️ Detects and removes corrupted bind mount directories"
echo "• 🔄 Uses lazy/force unmount to handle busy directories"
echo "• 🧹 Always recreates clean target directories"
echo "• ⚡ Faster monitoring cycle (2s instead of 3s)"
echo "• 📋 Better logging with timestamps and status"
echo ""
echo "🔌 Test the fix:"
echo "1. Unplug your PLAY_CARD USB drive"
echo "2. Wait 5 seconds"
echo "3. Plug it back in"
echo "4. Check: ls -la /home/pi/usb/"
echo "5. Monitor logs: sudo journalctl -u usb-bind-mount-monitor.service -f"
echo ""
echo "🔧 If issues persist:"
echo "• Check logs: sudo journalctl -u usb-bind-mount-monitor.service -f"
echo "• Manual cleanup: sudo umount -l /home/pi/usb/* && sudo rm -rf /home/pi/usb && sudo mkdir -p /home/pi/usb"
echo "• Restart service: sudo systemctl restart usb-bind-mount-monitor.service"
echo "" 