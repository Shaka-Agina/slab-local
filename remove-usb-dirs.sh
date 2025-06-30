#!/bin/bash

echo "🗑️  Removing USB Directories"
echo "============================"

# 1. Unmount first to be safe
echo "1. Unmounting any active mounts..."
sudo umount /home/pi/usb/music 2>/dev/null && echo "   - Unmounted /home/pi/usb/music" || echo "   - /home/pi/usb/music not mounted"
sudo umount /home/pi/usb/playcard 2>/dev/null && echo "   - Unmounted /home/pi/usb/playcard" || echo "   - /home/pi/usb/playcard not mounted"

# 2. Remove directories
echo "2. Removing directories..."

if [ -d "/home/pi/usb/music" ]; then
    sudo rm -rf /home/pi/usb/music
    echo "   - ✅ Removed /home/pi/usb/music"
else
    echo "   - ⚠️  /home/pi/usb/music doesn't exist"
fi

if [ -d "/home/pi/usb/playcard" ]; then
    sudo rm -rf /home/pi/usb/playcard
    echo "   - ✅ Removed /home/pi/usb/playcard"
else
    echo "   - ⚠️  /home/pi/usb/playcard doesn't exist"
fi

# 3. Remove parent directory if empty
if [ -d "/home/pi/usb" ]; then
    if [ -z "$(ls -A /home/pi/usb 2>/dev/null)" ]; then
        rmdir /home/pi/usb
        echo "   - ✅ Removed empty /home/pi/usb"
    else
        echo "   - ⚠️  /home/pi/usb not empty, keeping it"
        echo "     Contents: $(ls /home/pi/usb)"
    fi
fi

echo ""
echo "✅ USB directories removed!"
echo ""
echo "📋 Next steps:"
echo "   1. Unplug your USB drives"
echo "   2. Plug them back in" 
echo "   3. Run 'lsblk' to check mounting"
echo "   4. Should only see /media/pi/MUSIC and /media/pi/PLAY_CARD" 