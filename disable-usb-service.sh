#!/bin/bash

echo "Disabling USB bind monitor service (going fully native)..."

# Stop and disable the service
sudo systemctl stop usb-bind-monitor 2>/dev/null || true
sudo systemctl disable usb-bind-monitor 2>/dev/null || true

# Remove the service file
sudo rm -f /etc/systemd/system/usb-bind-monitor.service

# Remove the script
sudo rm -f /usr/local/bin/usb-bind-monitor.sh

# Remove static mount points
sudo rm -rf /home/pi/usb/music /home/pi/usb/playcard 2>/dev/null || true

# Reload systemd
sudo systemctl daemon-reload

echo "✅ USB bind monitor service disabled"
echo "🔄 System now uses native desktop auto-mounting only"
echo "📍 USB drives will be detected directly in /media/pi/" 