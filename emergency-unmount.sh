#!/bin/bash

echo "🚨 EMERGENCY: Stopping Mount Loop"
echo "================================="

# 1. Stop any running services that might be causing this
echo "1. Stopping potential culprit services..."
sudo systemctl stop udisks2 2>/dev/null || echo "   - udisks2 not running"
sudo systemctl stop automount 2>/dev/null || echo "   - automount not running" 
sudo systemctl stop autofs 2>/dev/null || echo "   - autofs not running"

# 2. Kill any mount processes
echo "2. Killing mount processes..."
sudo pkill -f "mount.*usb" 2>/dev/null || echo "   - No USB mount processes found"

# 3. Unmount ALL instances of the USB drive
echo "3. Unmounting all USB instances..."
for i in {1..10}; do
    # Try to unmount all possible mount points
    sudo umount /home/pi/usb/playcard 2>/dev/null && echo "   - Unmounted /home/pi/usb/playcard (attempt $i)"
    sudo umount /media/pi/PLAY_CARD 2>/dev/null && echo "   - Unmounted /media/pi/PLAY_CARD (attempt $i)"
    
    # Check if any are still mounted
    if ! mount | grep -q "/home/pi/usb/playcard\|/media/pi/PLAY_CARD"; then
        echo "   ✅ All mounts cleared!"
        break
    fi
    
    sleep 1
done

# 4. Force unmount if still mounted
echo "4. Force unmounting if needed..."
sudo umount -f /home/pi/usb/playcard 2>/dev/null
sudo umount -f /media/pi/PLAY_CARD 2>/dev/null

# 5. Remove the problematic directory
echo "5. Removing problematic directories..."
sudo rm -rf /home/pi/usb 2>/dev/null && echo "   - Removed /home/pi/usb directory"

# 6. Restart udisks2 properly
echo "6. Restarting mount services..."
sudo systemctl start udisks2

echo ""
echo "✅ Emergency cleanup completed!"
echo ""
echo "📋 Next steps:"
echo "   1. UNPLUG the USB drive now"
echo "   2. Wait 10 seconds"
echo "   3. Run the udev rule checker: ./check-udev-rules.sh"
echo "   4. Fix any problematic rules it finds"
echo "   5. THEN plug the USB back in"
echo ""
echo "⚠️  DO NOT plug the USB back in until we find what's causing the loop!" 