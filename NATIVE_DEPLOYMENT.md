# USB Music Player - Native Deployment Guide

## New Event-Driven Architecture 🚀

This deployment uses a completely redesigned event-driven architecture that eliminates polling overhead and provides real-time USB detection.

### Key Improvements

- **Event-Driven USB Detection**: Uses `udevadm` events instead of continuous polling
- **VLC-Based Audio**: Replaced pygame with VLC for better audio support
- **Proper Separation of Concerns**: Modular design with clear interfaces
- **Real-Time Responsiveness**: Instant response to USB mount/unmount events
- **Better Resource Usage**: No CPU waste from constant polling

## Architecture Overview

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

## Components

### 1. USBMonitor (`usb_monitor.py`)
- **Event-driven detection** using `udevadm monitor`
- **Fallback polling** if udev is not available
- **Permission handling** with troubleshooting
- **Callback-based notifications** for USB changes

### 2. MusicPlayer (`music_player.py`)
- **VLC-based audio engine** with full codec support
- **Control file monitoring** for USB-based commands
- **Album and track management** with repeat modes
- **Real-time playback control** and status reporting

### 3. WebInterface (`web_interface.py`)
- **Dependency injection** design pattern
- **Real-time status updates** via REST API
- **Album art extraction** from metadata and files
- **Debug endpoints** for troubleshooting

### 4. Main Application (`main.py`)
- **Signal handling** for graceful shutdown
- **Component orchestration** with proper cleanup
- **Error handling** and logging

## Installation on Raspberry Pi

### 1. Install System Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install VLC and development tools
sudo apt install -y vlc python3-vlc python3-pip python3-dev

# Install udev tools (usually pre-installed)
sudo apt install -y udev

# Add user to required groups
sudo usermod -aG plugdev,audio $USER

# Logout and login again for group changes to take effect
```

### 2. Install Python Dependencies

```bash
cd /path/to/slab-local
pip3 install -r requirements.txt
```

### 3. Test the Installation

```bash
# Test USB detection and event monitoring
python3 test-native-direct.py

# Test core imports
python3 -c "from main import main; print('✅ All components ready')"
```

### 4. Run the Application

```bash
# Start the music player
python3 main.py
```

The application will:
- Start event-driven USB monitoring
- Launch the web interface on port 5000
- Wait for USB drives to be inserted

## USB Drive Setup

### Music USB Drive
- **Label**: `MUSIC` (any variation like `MUSIC1`, `MUSIC_DRIVE`)
- **Content**: Music files in any supported format (MP3, FLAC, WAV, M4A, etc.)
- **Structure**: Any folder structure - albums will be auto-detected

### Control USB Drive
- **Label**: `PLAY_CARD` (any variation like `PLAY_CARD1`)
- **Content**: Create a `control.txt` file with commands

### Control Commands

Create `/media/pi/PLAY_CARD/control.txt` with one of:

```
Album: Your Album Name
Track: Your Track Name
play
pause
stop
next
previous
volume: 75
```

## Web Interface

Access at `http://raspberry-pi-ip:5000`

### Features
- **Real-time status** updates
- **Album art** display
- **Track controls** (if control USB present)
- **Volume control**
- **USB status** monitoring
- **Debug information**

### API Endpoints

- `GET /api/player_state` - Current player status
- `POST /api/toggle_play_pause` - Play/pause control
- `POST /api/next_track` - Skip to next track
- `POST /api/prev_track` - Skip to previous track
- `POST /api/set_volume/<int>` - Set volume (0-100)
- `GET /health` - Health check
- `GET /debug/usb` - USB debug information

## Event-Driven Operation

### USB Detection Flow

1. **Initial Scan**: Detect already-mounted drives on startup
2. **udev Monitoring**: Listen for real-time USB events
3. **Event Processing**: Handle mount/unmount events immediately
4. **Callback Execution**: Notify music player of changes
5. **Fallback Mode**: Use polling if udev unavailable

### Control File Monitoring

1. **File Watch**: Monitor control file for modifications
2. **Command Processing**: Parse and execute commands
3. **Playback Control**: Start/stop/skip tracks as requested
4. **Status Updates**: Reflect changes in web interface

## Troubleshooting

### USB Permission Issues

```bash
# Check user groups
groups

# Add to required groups if missing
sudo usermod -aG plugdev,audio $USER

# Check USB accessibility
ls -la /media/pi/

# Manual permission fix (if needed)
sudo chown -R $USER:$USER /media/pi/MUSIC*
sudo chown -R $USER:$USER /media/pi/PLAY_CARD*
```

### VLC Issues

```bash
# Test VLC installation
vlc --version

# Test python-vlc
python3 -c "import vlc; print('VLC OK')"

# Check audio devices
aplay -l
```

### Event Monitoring Issues

```bash
# Test udev monitoring
udevadm monitor --property --subsystem-match=block

# Check for udev availability
which udevadm

# Manual USB detection test
python3 test-native-direct.py
```

### Debug Information

- **Logs**: Check console output for detailed logging
- **Web Debug**: Visit `/debug/usb` for USB status
- **Health Check**: Visit `/health` for system status

## Performance Benefits

### Before (Polling-Based)
- ❌ **Continuous CPU usage** from polling loops
- ❌ **Delayed detection** (2-3 second intervals)
- ❌ **Resource waste** checking unchanged state
- ❌ **Complex state management** with race conditions

### After (Event-Driven)
- ✅ **Zero CPU usage** when idle
- ✅ **Instant detection** via udev events
- ✅ **Efficient resource usage** - only react to changes
- ✅ **Clean architecture** with proper separation

## Systemd Service (Optional)

Create `/etc/systemd/system/usb-music-player.service`:

```ini
[Unit]
Description=USB Music Player (Event-Driven)
After=network.target sound.target

[Service]
Type=simple
User=pi
Group=pi
WorkingDirectory=/home/pi/slab-local
ExecStart=/usr/bin/python3 main.py
Restart=always
RestartSec=5
Environment=PYTHONPATH=/home/pi/slab-local

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable usb-music-player.service
sudo systemctl start usb-music-player.service
sudo systemctl status usb-music-player.service
```

## Migration from Docker

If migrating from the Docker deployment:

1. **Stop Docker services**:
   ```bash
   docker-compose down
   ```

2. **Clean up bind mounts** (if any):
   ```bash
   sudo ./cleanup-duplicate-usb-dirs.sh
   ```

3. **Install native version** following this guide

4. **Test functionality** with your existing USB drives

The native deployment is much simpler and more reliable than Docker for this use case! 