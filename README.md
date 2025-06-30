# 🎵 USB Music Player for Raspberry Pi

A modern, event-driven music player with automatic USB detection and web interface control.

## ✨ New Event-Driven Architecture

**Major improvements in this version:**
- **⚡ Event-Driven USB Detection** - Uses `udevadm` events instead of polling (instant response!)
- **🎧 VLC Audio Engine** - Professional audio with full codec support
- **🔄 Real-Time Control** - Instant file-based command processing
- **🏗️ Clean Architecture** - Modular design with proper separation of concerns
- **📈 Better Performance** - Zero CPU usage when idle, instant USB detection

## 🚀 Quick Install

**One-command installation:**

```bash
git clone https://github.com/yourusername/slab-local.git
cd slab-local
chmod +x deploy-native-pi.sh
./deploy-native-pi.sh
```

This will:
- ✅ Install VLC and all dependencies
- ✅ Set up user permissions (plugdev, audio groups)
- ✅ Configure event-driven USB monitoring
- ✅ Test all components
- ✅ Optionally create systemd service

## 🔌 USB Setup

### Music USB Drive
- **Label**: `MUSIC` (or `MUSIC1`, `MUSIC_DRIVE`, etc.)
- **Content**: Your music files in any format (MP3, FLAC, WAV, M4A, AAC, OGG)
- **Structure**: Any folder organization - albums auto-detected

### Control USB Drive  
- **Label**: `PLAY_CARD` (or `PLAY_CARD1`, etc.)
- **Content**: Create a `control.txt` file with commands

### Control Commands

Create `/media/pi/PLAY_CARD/control.txt` with one of these commands:

```
Album: Pink Floyd - Dark Side of the Moon
Track: Bohemian Rhapsody
play
pause
stop
next
previous
volume: 75
```

**How it works:**
- The system monitors the control file for changes
- When you edit and save the file, the command executes immediately
- No need to create/delete files - just edit the content

## 🏗️ Architecture Overview

### Event-Driven Design
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   USB Monitor   │───▶│   Music Player   │───▶│  Web Interface  │
│ (Event-driven)  │    │  (VLC-based)     │    │    (Flask)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ udev Events     │    │ Control File     │    │ REST API        │
│ USB Detection   │    │ Monitoring       │    │ Web UI          │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components

1. **USBMonitor** - Event-driven USB detection using udev
2. **MusicPlayer** - VLC-based audio engine with control file monitoring  
3. **WebInterface** - Flask web server with REST API
4. **Main Application** - Orchestrates all components with proper cleanup

## 🌐 Web Interface

Access at: **http://your-pi-ip:5000**

### Features
- 🎵 **Real-time status** - Live updates without page refresh
- 🎨 **Album art display** - Extracted from metadata or folder images
- 🎛️ **Playback controls** - Play/pause/skip (requires control USB)
- 🔊 **Volume control** - Real-time volume adjustment
- 📊 **USB monitoring** - Live status of connected drives
- 🐛 **Debug info** - Troubleshooting endpoint at `/debug/usb`

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/player_state` | GET | Current player status |
| `/api/toggle_play_pause` | POST | Play/pause control |
| `/api/next_track` | POST | Skip to next track |
| `/api/prev_track` | POST | Skip to previous track |
| `/api/set_volume/<int>` | POST | Set volume (0-100) |
| `/health` | GET | Health check |
| `/debug/usb` | GET | USB debug information |

## 🔧 Usage

### Starting the Player
```bash
# Manual start
cd /path/to/slab-local
python3 main.py

# Or via systemd service
sudo systemctl start usb-music-player.service
```

### Playing Music
1. **Insert USB drives** - Music and control drives auto-detected
2. **Create control file** - Edit `control.txt` on PLAY_CARD drive
3. **Web interface** - Access at http://your-pi-ip:5000
4. **Real-time control** - Changes happen instantly

### Example Workflow
```bash
# 1. Insert MUSIC USB with your music
# 2. Insert PLAY_CARD USB  
# 3. Create control file:
echo "Album: Your Favorite Album" > /media/pi/PLAY_CARD/control.txt

# Music starts playing immediately!
# Edit the file to change commands:
echo "next" > /media/pi/PLAY_CARD/control.txt
echo "volume: 50" > /media/pi/PLAY_CARD/control.txt
```

## 🛠️ Troubleshooting

### USB Detection Issues
```bash
# Test USB detection
python3 test-native-direct.py

# Monitor USB events in real-time
udevadm monitor --property --subsystem-match=block

# Check mounted drives
ls -la /media/pi/

# Check user permissions
groups  # Should include 'plugdev' and 'audio'
```

### Audio Issues
```bash
# Test VLC
vlc --version
python3 -c "import vlc; print('VLC OK')"

# Test audio output
aplay /usr/share/sounds/alsa/Front_Left.wav

# Check audio devices
aplay -l
pactl list short sinks
```

### Service Issues
```bash
# Check service status
sudo systemctl status usb-music-player.service

# View real-time logs
journalctl -u usb-music-player.service -f

# Debug mode (manual start)
cd /path/to/slab-local
python3 main.py
```

### Performance Monitoring
```bash
# Check CPU usage (should be near 0% when idle)
top -p $(pgrep -f main.py)

# Monitor USB events
# Old: Continuous polling every 2-3 seconds
# New: Event-driven, zero CPU when idle
```

## 📊 Performance Comparison

### Before (Polling-Based)
- ❌ **Continuous CPU usage** from polling loops
- ❌ **2-3 second detection delay**
- ❌ **Resource waste** checking unchanged state
- ❌ **Complex USB permission handling**

### After (Event-Driven)
- ✅ **Zero CPU usage** when idle
- ✅ **Instant USB detection** via udev events
- ✅ **Efficient resource usage** - only react to changes
- ✅ **Clean permission handling** via user groups

## 🔄 Migration from Old Version

If upgrading from the polling-based version:

```bash
# Backup current setup
cp -r /path/to/old-version /path/to/backup

# Stop old services
sudo systemctl stop old-usb-music-player.service

# Deploy new version
git pull origin main
./deploy-native-pi.sh

# Test new version
python3 test-native-direct.py
```

## 📖 Documentation

- **[NATIVE_DEPLOYMENT.md](NATIVE_DEPLOYMENT.md)** - Complete deployment guide
- **[architecture-comparison.md](architecture-comparison.md)** - Technical comparison
- **Web Debug**: http://your-pi-ip:5000/debug/usb - Live system status

## 🎯 System Requirements

- **Raspberry Pi** 3B+ or newer (tested on Pi 4)
- **Raspberry Pi OS** Bullseye or newer with desktop
- **USB ports** for music and control drives
- **Audio output** (3.5mm, HDMI, or USB audio)
- **Python 3.7+** with pip
- **VLC media player** (installed by deployment script)

## 🤝 Contributing

This project uses a clean, modular architecture that's easy to extend:

- **USB detection** - Modify `usb_monitor.py`
- **Audio playback** - Modify `music_player.py`  
- **Web interface** - Modify `web_interface.py`
- **Control logic** - Modify `main.py`

Each component is independent and can be tested separately.

## 📜 License

MIT License - see LICENSE file for details.

---

**🎵 Enjoy your music with zero-latency USB detection and professional audio quality! 🎵**
