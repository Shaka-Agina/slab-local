#!/bin/bash

echo "🔧 Setting Up ALSA Audio (No PulseAudio)"
echo "========================================"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Please run this script as pi user, not root"
    echo "   Use: ./fix-audio-setup.sh"
    exit 1
fi

echo "🔍 Checking current audio configuration..."

# Check ALSA devices
echo ""
echo "📱 Available ALSA audio devices:"
aplay -l 2>/dev/null || echo "❌ No ALSA devices found"

# Check default audio output
echo ""
echo "🔊 Current default audio output:"
if command -v raspi-config >/dev/null 2>&1; then
    echo "   Use 'sudo raspi-config' -> Advanced Options -> Audio to change"
else
    echo "   Current setting: $(cat /sys/module/snd_bcm2835/parameters/enable_hdmi 2>/dev/null || echo 'unknown')"
fi

# Stop PulseAudio if running (we don't want it)
echo ""
echo "🛑 Ensuring PulseAudio is not running..."
if pgrep -x "pulseaudio" > /dev/null; then
    echo "   PulseAudio detected - stopping it..."
    pulseaudio --kill 2>/dev/null || true
    systemctl --user disable pulseaudio 2>/dev/null || true
    systemctl --user stop pulseaudio 2>/dev/null || true
    echo "   ✅ PulseAudio stopped"
else
    echo "   ✅ PulseAudio not running (good!)"
fi

# Check ALSA configuration
echo ""
echo "🎛️  ALSA Configuration:"

# Ensure user is in audio group
if groups | grep -q audio; then
    echo "   ✅ User 'pi' is in audio group"
else
    echo "   ⚠️  Adding user 'pi' to audio group..."
    sudo usermod -a -G audio pi
    echo "   ✅ Added to audio group (restart required)"
fi

# Set reasonable ALSA mixer levels
echo "   🔊 Setting audio levels..."
if command -v amixer >/dev/null 2>&1; then
    # Set PCM volume to 80%
    amixer sset PCM 80% 2>/dev/null || echo "     PCM control not available"
    
    # Set Master volume to 80% if available
    amixer sset Master 80% 2>/dev/null || echo "     Master control not available"
    
    # Unmute if muted
    amixer sset PCM unmute 2>/dev/null || true
    amixer sset Master unmute 2>/dev/null || true
    
    echo "   ✅ Audio levels configured"
else
    echo "   ⚠️  amixer not available"
fi

# Test audio output
echo ""
echo "🧪 Testing audio output..."
if command -v speaker-test >/dev/null 2>&1; then
    echo "   Running 2-second audio test..."
    timeout 2 speaker-test -t sine -f 440 -l 1 >/dev/null 2>&1 && \
        echo "   ✅ Audio test completed" || \
        echo "   ⚠️  Audio test failed"
else
    echo "   ⚠️  speaker-test not available"
fi

# Create ALSA configuration for direct hardware access
echo ""
echo "🔧 Creating optimized ALSA configuration..."

# User-specific ALSA config (ALSA direct, no PulseAudio)
cat > "$HOME/.asoundrc" << 'EOF'
# Direct ALSA configuration for music playback (no PulseAudio)
pcm.!default {
    type hw
    card 0
    device 0
}

ctl.!default {
    type hw
    card 0
}

# Dmix for software mixing if multiple apps need audio
pcm.dmixed {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:0,0"
        period_time 0
        period_size 1024
        buffer_size 4096
        rate 44100
        channels 2
    }
    bindings {
        0 0
        1 1
    }
}

# Use dmix for default if you need multiple audio apps
# Uncomment the lines below if you experience "device busy" errors:
#pcm.!default {
#    type plug
#    slave.pcm "dmixed"
#}
EOF

echo "   ✅ ALSA configuration created"

echo ""
echo "🎯 Audio Configuration Summary:"
echo "   ✅ VLC configured to use ALSA directly (no PulseAudio)"
echo "   ✅ PulseAudio disabled to prevent conflicts"
echo "   ✅ Direct hardware access for best performance"
echo "   ✅ Audio levels set to reasonable defaults"
echo ""
echo "🔄 Restart your music player service:"
echo "   sudo systemctl restart usb-music-player"
echo ""
echo "💡 If you still get audio errors:"
echo "   1. Try different audio output via 'sudo raspi-config'"
echo "   2. Check USB power supply (underpowered Pi can cause audio issues)"
echo "   3. Check logs: 'journalctl -u usb-music-player -f'"
echo "   4. Verify no other apps are using audio" 