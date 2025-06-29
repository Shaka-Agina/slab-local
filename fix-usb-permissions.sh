#!/bin/bash

# Fix USB Mounting Permissions Script
# Run this if you're getting "permission denied" errors with USB drives

set -e

echo "=== USB Permissions Fix Script ==="
echo "This script will fix USB mounting permissions for the music player."
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
sudo apt-get update
sudo apt-get install -y udisks2 exfat-fuse exfatprogs

print_status "Setting up base directory permissions..."
sudo mkdir -p /media/pi
sudo chown pi:pi /media/pi

print_status "Creating udev rules for proper USB mounting..."
sudo tee /etc/udev/rules.d/99-usb-automount.rules > /dev/null << 'EOL'
# USB automount rules for music player
# When USB drives with specific labels are plugged in, mount them with correct permissions

# Rule for MUSIC USB drive
SUBSYSTEM=="block", ATTRS{idVendor}=="*", ENV{ID_FS_LABEL}=="MUSIC", ACTION=="add", RUN+="/bin/mkdir -p /media/pi/MUSIC", RUN+="/bin/mount -o uid=1000,gid=1000,umask=0022 /dev/%k /media/pi/MUSIC"

# Rule for PLAY_CARD USB drive  
SUBSYSTEM=="block", ATTRS{idVendor}=="*", ENV{ID_FS_LABEL}=="PLAY_CARD", ACTION=="add", RUN+="/bin/mkdir -p /media/pi/PLAY_CARD", RUN+="/bin/mount -o uid=1000,gid=1000,umask=0022 /dev/%k /media/pi/PLAY_CARD"

# Cleanup on removal
SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="MUSIC", ACTION=="remove", RUN+="/bin/umount /media/pi/MUSIC", RUN+="/bin/rmdir /media/pi/MUSIC"
SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="PLAY_CARD", ACTION=="remove", RUN+="/bin/umount /media/pi/PLAY_CARD", RUN+="/bin/rmdir /media/pi/PLAY_CARD"
EOL

print_status "Creating USB mount helper script..."
sudo tee /usr/local/bin/usb-mount-helper.sh > /dev/null << 'EOL'
#!/bin/bash
# USB mount helper for music player

DEVICE=$1
LABEL=$2
ACTION=$3

case "$ACTION" in
    "add")
        case "$LABEL" in
            "MUSIC")
                mkdir -p /media/pi/MUSIC
                mount -o uid=1000,gid=1000,umask=0022 "$DEVICE" /media/pi/MUSIC
                chown pi:pi /media/pi/MUSIC
                ;;
            "PLAY_CARD")
                mkdir -p /media/pi/PLAY_CARD
                mount -o uid=1000,gid=1000,umask=0022 "$DEVICE" /media/pi/PLAY_CARD
                chown pi:pi /media/pi/PLAY_CARD
                ;;
        esac
        ;;
    "remove")
        case "$LABEL" in
            "MUSIC")
                umount /media/pi/MUSIC 2>/dev/null || true
                rmdir /media/pi/MUSIC 2>/dev/null || true
                ;;
            "PLAY_CARD")
                umount /media/pi/PLAY_CARD 2>/dev/null || true
                rmdir /media/pi/PLAY_CARD 2>/dev/null || true
                ;;
        esac
        ;;
esac
EOL

sudo chmod +x /usr/local/bin/usb-mount-helper.sh

print_status "Reloading udev rules..."
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
echo "🔌 Next steps:"
echo "1. Unplug any USB drives that are currently connected"
echo "2. Wait 5 seconds"
echo "3. Plug them back in"
echo "4. Check permissions with: ls -la /media/pi/"
echo ""
echo "🔧 Troubleshooting commands:"
echo "• Check current mounts: mount | grep /media/pi"
echo "• Monitor USB events: sudo udevadm monitor --property --subsystem-match=block"
echo "• Check permissions: ls -la /media/pi/"
echo ""
print_warning "If you still have issues, try rebooting the system: sudo reboot" 