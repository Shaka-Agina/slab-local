#!/bin/bash

echo "🚨 KILLING BIND MOUNT SERVICE"
echo "============================="

# 1. Stop the service immediately
echo "1. Stopping usb-bind-mount-monitor service..."
sudo systemctl stop usb-bind-mount-monitor.service 2>/dev/null || echo "   - Service not running"

# 2. Disable it permanently
echo "2. Disabling service..."
sudo systemctl disable usb-bind-mount-monitor.service 2>/dev/null || echo "   - Service not enabled"

# 3. Remove service files
echo "3. Removing service files..."
sudo rm -f /etc/systemd/system/usb-bind-mount-monitor.service && echo "   - ✅ Removed service file"
sudo rm -f /usr/local/bin/usb-bind-mount-monitor.sh && echo "   - ✅ Removed script file"

# 4. Kill any running processes
echo "4. Killing any running bind mount processes..."
sudo pkill -f "usb-bind-mount-monitor" 2>/dev/null && echo "   - ✅ Killed running processes" || echo "   - No processes found"

# 5. Force unmount everything
echo "5. Force unmounting all USB mounts..."
for i in {1..5}; do
    sudo umount -f /home/pi/usb/playcard 2>/dev/null && echo "   - Unmounted /home/pi/usb/playcard (attempt $i)"
    sudo umount -f /media/pi/PLAY_CARD 2>/dev/null && echo "   - Unmounted /media/pi/PLAY_CARD (attempt $i)"
done

# 6. Remove directories completely
echo "6. Removing USB directories..."
sudo rm -rf /home/pi/usb 2>/dev/null && echo "   - ✅ Removed /home/pi/usb directory"

# 7. Reload systemd
echo "7. Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "✅ BIND MOUNT SERVICE ELIMINATED!"
echo ""
echo "🔍 Checking if service is really gone..."
if systemctl list-units --all | grep -q "usb-bind-mount"; then
    echo "❌ Service still exists - manual cleanup needed"
else
    echo "✅ Service completely removed"
fi

echo ""
echo "📋 Next steps:"
echo "   1. UNPLUG your USB drive"
echo "   2. Wait 10 seconds"
echo "   3. Plug it back in"
echo "   4. Run 'lsblk' - should only see single mount at /media/pi/PLAY_CARD"
echo ""
echo "💡 From now on, use NATIVE deployment mode (no bind mounts needed)" 