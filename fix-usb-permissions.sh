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

print_status "Removing any existing static USB directories..."
sudo rm -rf /media/pi/MUSIC /media/pi/PLAY_CARD 2>/dev/null || true

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
    # Check if MUSIC USB is mounted and fix permissions
    if mountpoint -q /media/pi/MUSIC 2>/dev/null; then
        current_owner=$(stat -c '%U' /media/pi/MUSIC 2>/dev/null || echo "unknown")
        if [ "$current_owner" != "pi" ]; then
            chown -R pi:pi /media/pi/MUSIC 2>/dev/null || true
            echo "$(date): Fixed MUSIC USB permissions (was: $current_owner, now: pi)"
        fi
    fi
    
    # Check if PLAY_CARD USB is mounted and fix permissions
    if mountpoint -q /media/pi/PLAY_CARD 2>/dev/null; then
        current_owner=$(stat -c '%U' /media/pi/PLAY_CARD 2>/dev/null || echo "unknown")
        if [ "$current_owner" != "pi" ]; then
            chown -R pi:pi /media/pi/PLAY_CARD 2>/dev/null || true
            echo "$(date): Fixed PLAY_CARD USB permissions (was: $current_owner, now: pi)"
        fi
    fi
    
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

print_status "Fixing any currently mounted USB drives..."
# If USB drives are currently mounted with wrong permissions, fix them
if mountpoint -q /media/pi/MUSIC 2>/dev/null; then
    print_status "Fixing MUSIC USB permissions..."
    sudo chown -R pi:pi /media/pi/MUSIC
fi

if mountpoint -q /media/pi/PLAY_CARD 2>/dev/null; then
    print_status "Fixing PLAY_CARD USB permissions..."
    sudo chown -R pi:pi /media/pi/PLAY_CARD
fi

echo ""
echo "✅ USB permissions fix complete!"
echo ""
echo "🔧 How this works now:"
echo "• Desktop environment handles USB auto-mounting (no conflicts)"
echo "• Background service monitors and fixes permissions automatically"
echo "• USB drives will mount to /media/pi/MUSIC and /media/pi/PLAY_CARD"
echo "• Permissions are automatically corrected to pi:pi ownership"
echo ""
echo "🔌 Next steps:"
echo "1. Unplug any USB drives that are currently connected"
echo "2. Wait 5 seconds"
echo "3. Plug them back in"
echo "4. Check permissions with: ls -la /media/pi/"
echo ""
echo "🔧 Troubleshooting commands:"
echo "• Check permission monitor: sudo systemctl status usb-permissions-monitor.service"
echo "• View monitor logs: sudo journalctl -u usb-permissions-monitor.service -f"
echo "• Check current mounts: mount | grep /media/pi"
echo "• Check permissions: ls -la /media/pi/"
echo ""
print_warning "If you still have issues, try rebooting the system: sudo reboot" 