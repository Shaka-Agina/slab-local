#!/bin/bash

# Fix USB Mounting Permissions Script
# Run this if you're getting "permission denied" errors with USB drives

set -e

echo "=== USB Permissions Fix Script ==="
echo "This script will fix USB mounting permissions for the music player."
echo "This version works with desktop environment auto-mounting."
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

print_status "Setting up base directory permissions..."
sudo mkdir -p /media/pi
sudo chown pi:pi /media/pi

# Remove conflicting udev rules if they exist
print_status "Removing conflicting custom udev rules..."
sudo rm -f /etc/udev/rules.d/99-usb-automount.rules
sudo rm -f /usr/local/bin/usb-mount-helper.sh

print_status "Creating USB permission monitoring service..."
# Create a service that monitors and fixes USB permissions when they're mounted by the desktop
sudo tee /usr/local/bin/fix-usb-permissions-monitor.sh > /dev/null << 'EOL'
#!/bin/bash
# Monitor and fix USB permissions for music player

while true; do
    # Check for MUSIC USB (including numbered variants like MUSIC1, MUSIC2, etc.)
    for music_mount in /media/pi/MUSIC*; do
        if mountpoint -q "$music_mount" 2>/dev/null; then
            current_owner=$(stat -c '%U' "$music_mount" 2>/dev/null || echo "unknown")
            if [ "$current_owner" != "pi" ]; then
                chown -R pi:pi "$music_mount" 2>/dev/null || true
                echo "$(date): Fixed $music_mount permissions (was: $current_owner, now: pi)"
            fi
        fi
    done
    
    # Check for PLAY_CARD USB (including numbered variants like PLAY_CARD1, PLAY_CARD2, etc.)
    for playcard_mount in /media/pi/PLAY_CARD*; do
        if mountpoint -q "$playcard_mount" 2>/dev/null; then
            current_owner=$(stat -c '%U' "$playcard_mount" 2>/dev/null || echo "unknown")
            if [ "$current_owner" != "pi" ]; then
                chown -R pi:pi "$playcard_mount" 2>/dev/null || true
                echo "$(date): Fixed $playcard_mount permissions (was: $current_owner, now: pi)"
            fi
        fi
    done
    
    sleep 2
done
EOL

sudo chmod +x /usr/local/bin/fix-usb-permissions-monitor.sh

# Create systemd service for the monitor
print_status "Creating USB permissions monitoring service..."
sudo tee /etc/systemd/system/usb-permissions-monitor.service > /dev/null << 'EOL'
[Unit]
Description=USB Permissions Monitor for Music Player
After=graphical.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/fix-usb-permissions-monitor.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable usb-permissions-monitor.service
sudo systemctl start usb-permissions-monitor.service

print_status "Reloading udev rules to clear any conflicts..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "✅ USB permissions fix complete!"
echo ""
echo "🔧 How this works now:"
echo "• Desktop environment handles ALL USB auto-mounting"
echo "• Application dynamically detects USB drives regardless of numbered suffixes"
echo "• Background service monitors and fixes permissions automatically"
echo "• NO directories created - uses whatever the desktop environment provides"
echo ""
echo "🔌 Next steps:"
echo "1. Unplug any USB drives that are currently connected"
echo "2. Wait 5 seconds"
echo "3. Plug them back in"
echo "4. Check with: ls -la /media/pi/ (should only see what desktop creates)"
echo ""
echo "🔧 Troubleshooting commands:"
echo "• Check permission monitor: sudo systemctl status usb-permissions-monitor.service"
echo "• View monitor logs: sudo journalctl -u usb-permissions-monitor.service -f"
echo "• Check current mounts: mount | grep /media/pi"
echo "• List all USB drives: ls -la /media/pi/"
echo ""
print_warning "If you still have issues, try rebooting the system: sudo reboot" 