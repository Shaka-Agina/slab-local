#!/bin/bash

# USB Music Player - Native Pi Deployment Script
# Event-driven architecture with VLC and udev monitoring

set -e

echo "🎵 USB Music Player - Native Pi Deployment"
echo "=========================================="
echo ""

# Check if running on Raspberry Pi OS
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Raspberry Pi OS"
    echo "   It may work on other Debian-based systems, but YMMV"
    echo ""
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should NOT be run as root"
   echo "💡 Run as regular user: ./deploy-native-pi.sh"
   exit 1
fi

echo "📋 Step 1: Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

echo ""
echo "📦 Step 2: Installing system dependencies..."

# Install VLC and audio support
sudo apt install -y \
    vlc \
    python3-vlc \
    python3-pip \
    python3-dev \
    python3-venv \
    udev \
    alsa-utils \
    pulseaudio

echo ""
echo "👥 Step 3: Adding user to required groups..."

# Add user to audio and plugdev groups
sudo usermod -aG plugdev,audio $USER

echo "✅ User $USER added to 'plugdev' and 'audio' groups"
echo "⚠️  You'll need to logout and login again for group changes to take effect"

echo ""
echo "🐍 Step 4: Installing Python dependencies..."

# Install Python requirements
pip3 install -r requirements.txt

echo ""
echo "🧪 Step 5: Testing installation..."

# Test VLC installation
echo "Testing VLC..."
if vlc --version > /dev/null 2>&1; then
    echo "✅ VLC installed successfully"
else
    echo "❌ VLC installation failed"
    exit 1
fi

# Test python-vlc (this will fail on non-Pi systems without VLC libs)
echo "Testing python-vlc..."
if python3 -c "import vlc; print('VLC Python bindings OK')" 2>/dev/null; then
    echo "✅ Python VLC bindings working"
else
    echo "⚠️  Python VLC bindings may have issues - will test on actual run"
fi

# Test udev
echo "Testing udev..."
if which udevadm > /dev/null 2>&1; then
    echo "✅ udev tools available"
else
    echo "❌ udev tools not found"
    exit 1
fi

# Test core imports (excluding VLC-dependent ones)
echo "Testing core components..."
if python3 -c "from usb_monitor import USBMonitor; from web_interface import create_app; print('Core components OK')" 2>/dev/null; then
    echo "✅ Core components import successfully"
else
    echo "❌ Core component import failed"
    exit 1
fi

echo ""
echo "🔧 Step 6: Setting up directories and permissions..."

# Create log directory
mkdir -p logs
chmod 755 logs

# Ensure /media/pi exists (should be automatic on Pi OS with desktop)
if [[ ! -d "/media/pi" ]]; then
    echo "⚠️  /media/pi directory doesn't exist"
    echo "   This is unusual for Raspberry Pi OS with desktop"
    echo "   USB auto-mounting may not work as expected"
fi

echo ""
echo "🎯 Step 7: Testing USB detection..."

# Run USB detection test
echo "Running USB detection test..."
python3 test-native-direct.py || echo "⚠️  USB test completed with warnings (expected if no USB drives inserted)"

echo ""
echo "🚀 Step 8: Creating systemd service (optional)..."

# Ask if user wants to create systemd service
read -p "Create systemd service for auto-start? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    sudo tee /etc/systemd/system/usb-music-player.service > /dev/null <<EOF
[Unit]
Description=USB Music Player (Event-Driven)
After=network.target sound.target graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/python3 main.py
Restart=always
RestartSec=5
Environment=PYTHONPATH=$SCRIPT_DIR
Environment=DISPLAY=:0

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable usb-music-player.service
    
    echo "✅ Systemd service created and enabled"
    echo "   Start with: sudo systemctl start usb-music-player.service"
    echo "   Check status: sudo systemctl status usb-music-player.service"
    echo "   View logs: journalctl -u usb-music-player.service -f"
else
    echo "Skipping systemd service creation"
fi

echo ""
echo "🎉 Installation Complete!"
echo "======================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. 🔄 LOGOUT and LOGIN again for group changes to take effect"
echo ""
echo "2. 💿 Prepare your USB drives:"
echo "   • Music USB: Label as 'MUSIC' with your music files"
echo "   • Control USB: Label as 'PLAY_CARD' with control.txt file"
echo ""
echo "3. 🎵 Start the music player:"
echo "   python3 main.py"
echo ""
echo "4. 🌐 Access web interface:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo "   or http://localhost:5000"
echo ""
echo "📖 Documentation:"
echo "   • Full guide: NATIVE_DEPLOYMENT.md"
echo "   • Architecture: README.md"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Test USB: python3 test-native-direct.py"
echo "   • Check groups: groups"
echo "   • Debug endpoint: http://localhost:5000/debug/usb"
echo ""
echo "✨ Features of the new architecture:"
echo "   • Event-driven USB detection (no polling!)"
echo "   • VLC-based audio with full codec support"
echo "   • Real-time control file monitoring"
echo "   • Clean modular design"
echo "   • Better error handling and logging"
echo ""

# Check current groups
echo "🔍 Current user groups:"
groups | tr ' ' '\n' | sort | sed 's/^/   • /'

if groups | grep -q "plugdev" && groups | grep -q "audio"; then
    echo ""
    echo "✅ User already has required groups - you can start immediately!"
else
    echo ""
    echo "⚠️  Please logout and login again for group changes to take effect"
fi

echo ""
echo "🎵 Ready to rock! Insert your USB drives and run: python3 main.py" 