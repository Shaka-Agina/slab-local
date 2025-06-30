#!/bin/bash

echo "🔧 Fixing USB Double Mount Issue"
echo "================================="

# 1. Unmount static mount points
echo "1. Unmounting static mount points..."
sudo umount /home/pi/usb/music 2>/dev/null || echo "   - /home/pi/usb/music not mounted"
sudo umount /home/pi/usb/playcard 2>/dev/null || echo "   - /home/pi/usb/playcard not mounted"

# 2. Check and remove from /etc/fstab if present
echo "2. Checking /etc/fstab for static mount entries..."
if grep -q "/home/pi/usb" /etc/fstab; then
    echo "   - Found USB entries in /etc/fstab, creating backup..."
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    
    echo "   - Removing USB mount entries from /etc/fstab..."
    sudo grep -v "/home/pi/usb" /etc/fstab > /tmp/fstab.new
    sudo mv /tmp/fstab.new /etc/fstab
    echo "   - Static mount entries removed"
else
    echo "   - No USB entries found in /etc/fstab"
fi

# 3. Disable any systemd mount services
echo "3. Checking for systemd mount services..."
for service in $(systemctl list-units --type=mount | grep "home-pi-usb" | awk '{print $1}'); do
    echo "   - Disabling $service"
    sudo systemctl stop "$service"
    sudo systemctl disable "$service"
done

# 4. Check for any custom mount scripts
echo "4. Checking for custom mount scripts..."
if [ -f "/etc/systemd/system/usb-bind-mounts.service" ]; then
    echo "   - Found usb-bind-mounts.service, disabling..."
    sudo systemctl stop usb-bind-mounts.service
    sudo systemctl disable usb-bind-mounts.service
    sudo rm /etc/systemd/system/usb-bind-mounts.service
fi

# 5. Remove static directories if empty
echo "5. Cleaning up directories..."
if [ -d "/home/pi/usb/music" ] && [ -z "$(ls -A /home/pi/usb/music)" ]; then
    rmdir /home/pi/usb/music
    echo "   - Removed empty /home/pi/usb/music"
fi

if [ -d "/home/pi/usb/playcard" ] && [ -z "$(ls -A /home/pi/usb/playcard)" ]; then
    rmdir /home/pi/usb/playcard
    echo "   - Removed empty /home/pi/usb/playcard"
fi

if [ -d "/home/pi/usb" ] && [ -z "$(ls -A /home/pi/usb)" ]; then
    rmdir /home/pi/usb
    echo "   - Removed empty /home/pi/usb"
fi

# 6. Reload systemd
echo "6. Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "✅ Double mount fix completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Unplug and replug your USB drives"
echo "   2. Run 'lsblk' to verify single mounting"
echo "   3. Your drives should only appear at:"
echo "      - /media/pi/MUSIC"
echo "      - /media/pi/PLAY_CARD"
echo ""
echo "💡 The music player code will automatically find drives at /media/pi/" 