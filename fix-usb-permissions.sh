#!/bin/bash

# USB Bind Mount Fix Script
# Run this if you're getting "permission denied" errors with USB drives

set -e

echo "=== USB Bind Mount Fix Script ==="
echo "This script will set up bind mounts for USB drives with proper permissions."
echo "This approach works around desktop environment permission restrictions."
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a regular user (not root/sudo)"
    print_status "Usage: ./fix-usb-permissions.sh"
    exit 1
fi

print_status "Installing USB mounting utilities..."
sudo apt-get update -qq
sudo apt-get install -y udisks2 exfat-fuse exfatprogs

print_status "Setting up bind mount directory structure..."
mkdir -p /home/pi/usb
chown -R pi:pi /home/pi/usb
chmod -R 755 /home/pi/usb

# Remove old permission monitoring service if it exists
print_status "Removing old permission monitoring service..."
sudo systemctl stop usb-permissions-monitor.service 2>/dev/null || true
sudo systemctl disable usb-permissions-monitor.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/usb-permissions-monitor.service
sudo rm -f /usr/local/bin/fix-usb-permissions-monitor.sh

# Remove conflicting udev rules if they exist
print_status "Removing conflicting custom udev rules..."
sudo rm -f /etc/udev/rules.d/99-usb-automount.rules
sudo rm -f /usr/local/bin/usb-mount-helper.sh

print_status "Creating USB bind mount monitoring service..."
# Create a service that monitors and creates bind mounts for USB drives
sudo tee /usr/local/bin/usb-bind-mount-monitor.sh > /dev/null << 'EOL'
#!/bin/bash
# Monitor and create bind mounts for USB drives with proper permissions

# Create the bind mount directory structure
mkdir -p /home/pi/usb
chown -R pi:pi /home/pi/usb
chmod -R 755 /home/pi/usb

while true; do
    # Handle MUSIC USB drives
    for music_mount in /media/pi/MUSIC*; do
        if mountpoint -q "$music_mount" 2>/dev/null; then
            bind_target="/home/pi/usb/music"
            
            # Create bind mount if it doesn't exist
            if ! mountpoint -q "$bind_target" 2>/dev/null; then
                mkdir -p "$bind_target"
                chown pi:pi "$bind_target"
                
                # Create the bind mount
                if mount --bind "$music_mount" "$bind_target" 2>/dev/null; then
                    # Set proper permissions on the bind mount
                    chown -R pi:pi "$bind_target" 2>/dev/null || true
                    chmod -R 755 "$bind_target" 2>/dev/null || true
                    echo "$(date): Created bind mount: $music_mount -> $bind_target"
                else
                    echo "$(date): Failed to create bind mount: $music_mount -> $bind_target"
                fi
            fi
            break  # Only bind mount the first MUSIC drive found
        fi
    done
    
    # Handle PLAY_CARD USB drives
    for playcard_mount in /media/pi/PLAY_CARD*; do
        if mountpoint -q "$playcard_mount" 2>/dev/null; then
            bind_target="/home/pi/usb/playcard"
            
            # Create bind mount if it doesn't exist
            if ! mountpoint -q "$bind_target" 2>/dev/null; then
                mkdir -p "$bind_target"
                chown pi:pi "$bind_target"
                
                # Create the bind mount
                if mount --bind "$playcard_mount" "$bind_target" 2>/dev/null; then
                    # Set proper permissions on the bind mount
                    chown -R pi:pi "$bind_target" 2>/dev/null || true
                    chmod -R 755 "$bind_target" 2>/dev/null || true
                    echo "$(date): Created bind mount: $playcard_mount -> $bind_target"
                else
                    echo "$(date): Failed to create bind mount: $playcard_mount -> $bind_target"
                fi
            fi
            break  # Only bind mount the first PLAY_CARD drive found
        fi
    done
    
    # Clean up bind mounts if USB drives are removed
    if mountpoint -q "/home/pi/usb/music" 2>/dev/null; then
        # Check if the original mount still exists
        music_exists=false
        for music_mount in /media/pi/MUSIC*; do
            if mountpoint -q "$music_mount" 2>/dev/null; then
                music_exists=true
                break
            fi
        done
        
        if [ "$music_exists" = false ]; then
            umount "/home/pi/usb/music" 2>/dev/null || true
            echo "$(date): Removed bind mount: /home/pi/usb/music (original USB removed)"
        fi
    fi
    
    if mountpoint -q "/home/pi/usb/playcard" 2>/dev/null; then
        # Check if the original mount still exists
        playcard_exists=false
        for playcard_mount in /media/pi/PLAY_CARD*; do
            if mountpoint -q "$playcard_mount" 2>/dev/null; then
                playcard_exists=true
                break
            fi
        done
        
        if [ "$playcard_exists" = false ]; then
            umount "/home/pi/usb/playcard" 2>/dev/null || true
            echo "$(date): Removed bind mount: /home/pi/usb/playcard (original USB removed)"
        fi
    fi
    
    sleep 3
done
EOL

sudo chmod +x /usr/local/bin/usb-bind-mount-monitor.sh

# Create systemd service for the monitor
print_status "Creating USB bind mount monitoring service..."
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

print_status "Reloading udev rules to clear any conflicts..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "✅ USB bind mount fix complete!"
echo ""
echo "🔧 How this works now:"
echo "• Desktop environment handles USB auto-mounting (can't control permissions)"
echo "• Bind mount service creates /home/pi/usb/music and /home/pi/usb/playcard"
echo "• These bind mounts have proper pi:pi permissions that Docker can access"
echo "• Application uses bind mount paths with fallback to original paths"
echo ""
echo "🔌 Next steps:"
echo "1. Unplug any USB drives that are currently connected"
echo "2. Wait 5 seconds"
echo "3. Plug them back in"
echo "4. Check bind mounts: ls -la /home/pi/usb/"
echo ""
echo "🔧 Troubleshooting commands:"
echo "• Check bind mount monitor: sudo systemctl status usb-bind-mount-monitor.service"
echo "• View bind mount logs: sudo journalctl -u usb-bind-mount-monitor.service -f"
echo "• Check current mounts: mount | grep /home/pi/usb"
echo "• List USB drives: ls -la /media/pi/ (original mounts)"
echo "• List bind mounts: ls -la /home/pi/usb/ (what Docker uses)"
echo "" 