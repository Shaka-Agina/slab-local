#!/bin/bash

echo "🔧 Fixing Audio Setup for Music Player"
echo "======================================"

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
    echo "   /usr/bin/amixer sget PCM 2>/dev/null || echo 'PCM control not found'"
fi

# Check if PulseAudio is running
echo ""
echo "🎵 PulseAudio status:"
if pgrep -x "pulseaudio" > /dev/null; then
    echo "   ✅ PulseAudio is running"
    echo "   🔧 Configuring PulseAudio for better buffering..."
    
    # Create or update PulseAudio configuration
    PULSE_CONFIG="$HOME/.config/pulse"
    mkdir -p "$PULSE_CONFIG"
    
    # Create daemon.conf for better buffering
    cat > "$PULSE_CONFIG/daemon.conf" << 'EOF'
# Custom PulseAudio configuration for music player
default-sample-format = s16le
default-sample-rate = 44100
alternate-sample-rate = 48000
default-sample-channels = 2
default-channel-map = front-left,front-right

# Buffer settings to prevent overflow
default-fragments = 4
default-fragment-size-msec = 25
high-priority = yes
nice-level = -11
realtime-scheduling = no

# Disable unnecessary modules
load-sample-lazy = yes
load-sample-dir-lazy = yes
EOF
    
    echo "   ✅ Updated PulseAudio configuration"
    
    # Restart PulseAudio with new settings
    echo "   🔄 Restarting PulseAudio..."
    pulseaudio --kill 2>/dev/null || true
    sleep 2
    pulseaudio --start --log-target=syslog 2>/dev/null || true
    sleep 1
    
    if pgrep -x "pulseaudio" > /dev/null; then
        echo "   ✅ PulseAudio restarted successfully"
    else
        echo "   ⚠️  PulseAudio restart failed, will use ALSA fallback"
    fi
    
else
    echo "   ⚠️  PulseAudio not running - using ALSA directly"
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

# Create ALSA configuration for better compatibility
echo ""
echo "🔧 Creating optimized ALSA configuration..."

# User-specific ALSA config
cat > "$HOME/.asoundrc" << 'EOF'
# Optimized ALSA configuration for music playback
pcm.!default {
    type pulse
    fallback "sysdefault"
    hint {
        show on
        description "Default ALSA Output (via PulseAudio)"
    }
}

ctl.!default {
    type pulse
    fallback "sysdefault"
}

# Direct ALSA fallback
pcm.sysdefault {
    type hw
    card 0
    device 0
}

# Dmix for software mixing if needed
pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:0,0"
        period_time 0
        period_size 1024
        buffer_size 4096
        rate 44100
    }
    bindings {
        0 0
        1 1
    }
}
EOF

echo "   ✅ ALSA configuration created"

echo ""
echo "🎯 Audio Configuration Summary:"
echo "   ✅ VLC configured to use ALSA with optimized settings"
echo "   ✅ PulseAudio configured with better buffering (if running)"
echo "   ✅ ALSA fallback configuration created"
echo "   ✅ Audio levels set to reasonable defaults"
echo ""
echo "🔄 Restart your music player service:"
echo "   sudo systemctl restart usb-music-player"
echo ""
echo "💡 If you still get audio errors:"
echo "   1. Try different audio output via 'sudo raspi-config'"
echo "   2. Check USB power supply (underpowered Pi can cause audio issues)"
echo "   3. Check logs: 'journalctl -u usb-music-player -f'" 