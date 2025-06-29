#!/bin/bash

# Quick fix script for USB mounting conflicts
# Run this if you're getting PLAY_CARD1 instead of PLAY_CARD

echo "=== USB Conflict Fix ==="
echo "This script will remove conflicting udev rules and restart services."
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
    echo "Usage: ./fix-usb-conflicts-now.sh"
    exit 1
fi

print_status "Step 1: Removing conflicting udev rules..."
sudo rm -f /etc/udev/rules.d/99-usb-automount.rules
sudo rm -f /etc/udev/rules.d/99-usb-music.rules

print_status "Step 2: Reloading udev rules..."
sudo udevadm control --reload-rules

print_status "Step 3: Checking for USB permission monitor service..."
if systemctl is-active --quiet usb-permissions-monitor.service; then
    print_status "USB permission monitor is running - good!"
else
    print_warning "USB permission monitor is not running. Restarting..."
    sudo systemctl restart usb-permissions-monitor.service
fi

print_status "Step 4: Current USB mounts:"
ls -la /media/pi/ 2>/dev/null || echo "No USB drives currently mounted"

echo ""
print_status "✅ Conflict fix complete!"
echo ""
echo "🔄 Next steps:"
echo "1. Unplug your USB drives"
echo "2. Wait 5 seconds"
echo "3. Plug them back in"
echo "4. Check the mount points: ls -la /media/pi/"
echo ""
echo "Expected result: Your PLAY_CARD should now mount as /media/pi/PLAY_CARD (no number suffix)"
echo ""
echo "If you still see PLAY_CARD1, there might be a directory conflict."
echo "Check: ls -la /media/pi/PLAY_CARD*" 