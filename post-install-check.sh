#!/bin/bash

echo "🔍 Post-Installation Validation Check"
echo "====================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_ok() {
    echo -e "   ${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "   ${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "   ${RED}❌${NC} $1"
}

print_info() {
    echo -e "   ${BLUE}ℹ️${NC} $1"
}

echo ""
echo "🐍 Python Environment Check:"

# Check if venv exists and has the right packages
if [ -d "venv" ]; then
    print_ok "Virtual environment exists"
    
    # Activate venv and check packages
    source venv/bin/activate 2>/dev/null
    if pip list | grep -q "flask"; then
        print_ok "Flask installed"
    else
        print_error "Flask missing"
    fi
    
    if pip list | grep -q "python-vlc"; then
        print_ok "VLC Python bindings installed"
    else
        print_error "VLC Python bindings missing"
    fi
    
    if pip list | grep -q "mutagen"; then
        print_ok "Mutagen (metadata) installed"
    else
        print_warning "Mutagen missing (album art may not work)"
    fi
    
else
    print_error "Virtual environment not found"
fi

echo ""
echo "🎵 Audio System Check:"

# Check VLC installation
if command -v vlc >/dev/null 2>&1; then
    print_ok "VLC media player installed"
else
    print_error "VLC not found"
fi

# Check audio group membership
if groups | grep -q audio; then
    print_ok "User is in audio group"
else
    print_warning "User not in audio group"
fi

# Check ALSA tools
if command -v amixer >/dev/null 2>&1; then
    print_ok "ALSA tools available"
else
    print_warning "ALSA tools missing"
fi

# Check PulseAudio
if command -v pulseaudio >/dev/null 2>&1; then
    print_ok "PulseAudio available"
    if pgrep -x "pulseaudio" > /dev/null; then
        print_ok "PulseAudio is running"
    else
        print_warning "PulseAudio not running"
    fi
else
    print_warning "PulseAudio not installed"
fi

echo ""
echo "🔧 Helper Scripts Check:"

# Check helper scripts
scripts=("clean-macos-files.sh" "fix-audio-setup.sh" "kill-bind-mount-service.sh" "emergency-unmount.sh")
for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_ok "$script is executable"
    elif [ -f "$script" ]; then
        print_warning "$script exists but not executable"
    else
        print_warning "$script not found"
    fi
done

echo ""
echo "📁 Code Files Check:"

# Check main application files
files=("app.py" "music_player.py" "web_interface.py" "usb_monitor.py" "config.py" "utils.py")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        print_ok "$file present"
    else
        print_error "$file missing"
    fi
done

echo ""
echo "🔌 USB Mount Points Check:"

# Check USB mount directories
if [ -d "/media/pi" ]; then
    print_ok "/media/pi directory exists"
else
    print_warning "/media/pi not found (USB auto-mounting may not work)"
fi

# Check for any existing USB drives
usb_drives=$(ls /media/pi/ 2>/dev/null | wc -l)
if [ $usb_drives -gt 0 ]; then
    print_info "Found $usb_drives USB drive(s) in /media/pi/"
    ls /media/pi/ | while read drive; do
        print_info "  - $drive"
    done
else
    print_info "No USB drives currently mounted"
fi

echo ""
echo "🚀 Service Check:"

# Check systemd service
if systemctl is-enabled usb-music-player.service >/dev/null 2>&1; then
    print_ok "Service is enabled"
    
    if systemctl is-active usb-music-player.service >/dev/null 2>&1; then
        print_ok "Service is running"
    else
        print_warning "Service is not running"
        print_info "Try: sudo systemctl start usb-music-player.service"
    fi
else
    print_error "Service not found or not enabled"
fi

echo ""
echo "🌐 Web Interface Check:"

# Check if web server is responding
if curl -s http://localhost:5000/health >/dev/null 2>&1; then
    print_ok "Web interface is responding"
else
    print_warning "Web interface not responding on port 5000"
fi

echo ""
echo "📋 Installation Summary:"

# Overall status
all_good=true

# Critical checks
if [ ! -d "venv" ]; then all_good=false; fi
if ! systemctl is-enabled usb-music-player.service >/dev/null 2>&1; then all_good=false; fi
if [ ! -f "app.py" ]; then all_good=false; fi

if [ "$all_good" = true ]; then
    echo -e "${GREEN}🎉 Installation looks good!${NC}"
    echo ""
    echo "🔌 Next steps:"
    echo "1. Insert USB drives labeled 'MUSIC' and 'PLAY_CARD'"
    echo "2. Access web interface at http://$(hostname -I | awk '{print $1}'):5000"
    echo "3. If music doesn't play, run: ./clean-macos-files.sh"
    echo "4. Check service logs: sudo journalctl -u usb-music-player.service -f"
else
    echo -e "${RED}⚠️ Some issues detected${NC}"
    echo ""
    echo "🔧 Try these fixes:"
    echo "1. Re-run the installer: ./install.sh"
    echo "2. Check the service: sudo systemctl status usb-music-player.service"
    echo "3. View logs: sudo journalctl -u usb-music-player.service -f"
fi

echo ""
echo "💡 Troubleshooting commands:"
echo "• Fix audio: ./fix-audio-setup.sh"
echo "• Clean macOS files: ./clean-macos-files.sh" 
echo "• View logs: sudo journalctl -u usb-music-player.service -f"
echo "• Restart service: sudo systemctl restart usb-music-player.service" 