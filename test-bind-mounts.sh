#!/bin/bash

# Test Bind Mount Setup Script
# Quick test to verify bind mounts are working

echo "=== USB Bind Mount Test ==="
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

print_status "Checking current USB mounts..."
echo "Original USB mounts in /media/pi/:"
ls -la /media/pi/ 2>/dev/null || echo "  No USB drives found in /media/pi/"

echo ""
echo "Bind mounts in /home/pi/usb/:"
ls -la /home/pi/usb/ 2>/dev/null || echo "  No bind mounts found in /home/pi/usb/"

echo ""
print_status "Checking bind mount service status..."
if systemctl is-active --quiet usb-bind-mount-monitor.service; then
    echo "✅ USB bind mount service is running"
else
    print_warning "❌ USB bind mount service is not running"
    echo "Try: sudo systemctl start usb-bind-mount-monitor.service"
fi

echo ""
print_status "Testing Docker container access..."
if docker-compose ps | grep -q "usb-music-player.*Up"; then
    echo "✅ Docker container is running"
    
    echo ""
    echo "Container view of bind mounts:"
    docker-compose exec music-player ls -la /home/pi/usb/ 2>/dev/null || echo "  Container cannot access /home/pi/usb/"
    
    echo ""
    echo "Container view of original mounts (read-only fallback):"
    docker-compose exec music-player ls -la /media/pi/ 2>/dev/null || echo "  Container cannot access /media/pi/"
    
else
    print_warning "❌ Docker container is not running"
    echo "Try: docker-compose up -d"
fi

echo ""
print_status "Manual bind mount test..."
if [ -d "/media/pi/MUSIC" ] && mountpoint -q "/media/pi/MUSIC" 2>/dev/null; then
    print_status "MUSIC USB found at /media/pi/MUSIC"
    
    if mountpoint -q "/home/pi/usb/music" 2>/dev/null; then
        echo "✅ Bind mount exists: /home/pi/usb/music"
        echo "Permissions: $(ls -ld /home/pi/usb/music | awk '{print $1, $3, $4}')"
    else
        print_warning "❌ No bind mount for MUSIC USB"
        echo "The service should create this automatically..."
    fi
else
    print_warning "No MUSIC USB drive detected"
fi

if [ -d "/media/pi/PLAY_CARD" ] && mountpoint -q "/media/pi/PLAY_CARD" 2>/dev/null; then
    print_status "PLAY_CARD USB found at /media/pi/PLAY_CARD"
    
    if mountpoint -q "/home/pi/usb/playcard" 2>/dev/null; then
        echo "✅ Bind mount exists: /home/pi/usb/playcard"
        echo "Permissions: $(ls -ld /home/pi/usb/playcard | awk '{print $1, $3, $4}')"
    else
        print_warning "❌ No bind mount for PLAY_CARD USB"
        echo "The service should create this automatically..."
    fi
else
    print_warning "No PLAY_CARD USB drive detected"
fi

echo ""
print_status "Recent bind mount service logs:"
sudo journalctl -u usb-bind-mount-monitor.service --no-pager -n 10 2>/dev/null || echo "No logs available"

echo ""
echo "🔧 If bind mounts are missing:"
echo "1. Check service: sudo systemctl status usb-bind-mount-monitor.service"
echo "2. Restart service: sudo systemctl restart usb-bind-mount-monitor.service"
echo "3. Check logs: sudo journalctl -u usb-bind-mount-monitor.service -f"
echo "4. Unplug/replug USB drives to trigger detection" 