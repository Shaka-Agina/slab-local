# 🎵 USB Music Player for Raspberry Pi

A modern web-based music player that automatically detects USB drives and provides both web interface and physical control via USB files.

## ✨ Features

- **🔌 Automatic USB Detection** - Plug and play with MUSIC and PLAY_CARD labeled drives
- **🌐 Web Interface** - Modern, responsive control panel
- **📁 File-based Control** - Create simple text files on USB to control playback
- **🎛️ Volume Control** - Web and file-based volume adjustment
- **🔄 Playlist Management** - Automatic playlist generation from USB music
- **📱 Mobile Friendly** - Works great on phones and tablets
- **🚀 Native Performance** - Direct hardware access, no container overhead
- **🔧 Easy Development** - Simple Python Flask application

## 🚀 Quick Install (Recommended)

**One-command installation with native deployment:**

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/slab-local/main/install.sh | bash
```

**Or manual installation:**

```bash
git clone https://github.com/yourusername/slab-local.git
cd slab-local
chmod +x install.sh
./install.sh
```

The installer will ask you to choose between:
1. **Native (Recommended)** - Best performance, no USB permission issues
2. **Docker** - Containerized deployment (legacy option)

## 🔄 Migration from Docker

If you're already using the Docker version and want to migrate to native:

```bash
chmod +x migrate-to-native.sh
./migrate-to-native.sh
```

This will:
- ✅ Backup your current configuration
- ✅ Stop Docker services
- ✅ Set up native deployment
- ✅ Preserve all your settings
- ✅ Create rollback option

## 🏗️ Architecture

### Native Deployment (Recommended)
```
USB Drive → Desktop Auto-mount → Direct Access by Python App
/media/pi/MUSIC* → Direct Access (pi user permissions via groups)
```

**Benefits:**
- ✅ No USB permission issues (pi user in plugdev group)
- ✅ Better audio performance  
- ✅ Faster startup and operation
- ✅ Easier debugging and development
- ✅ Direct hardware access
- ✅ Simplified architecture

### Docker Deployment (Legacy)
```
USB Drive → Desktop Auto-mount → Docker Volume → Container App
/media/pi/MUSIC* → Docker mount → Permission complexity
```

## 📦 System Requirements

- Raspberry Pi (3B+ or newer recommended)
- Raspberry Pi OS (Bullseye or newer)
- USB ports for music and control drives
- Audio output (3.5mm jack, HDMI, or USB)

## 🔌 USB Setup

### Label Your USB Drives
- **Music USB**: Label as `MUSIC` (contains your music files)
- **Control USB**: Label as `PLAY_CARD` (contains control files)

### Control Files
Create these files on your `PLAY_CARD` USB drive to control playback:

| File Name | Function |
|-----------|----------|
| `playMusic.txt` | Start/stop playback |
| `nextTrack.txt` | Skip to next track |
| `prevTrack.txt` | Go to previous track |
| `volumeUp.txt` | Increase volume |
| `volumeDown.txt` | Decrease volume |

**File contents don't matter** - the player just checks if the file exists.

## 🌐 Web Interface

Access your music player at:
- **http://your-pi-ip:5000**
- **http://raspberrypi.local:5000** (if mDNS is working)

### Web Features
- 🎵 Play/pause/stop controls
- ⏭️ Next/previous track
- 🔊 Volume slider
- 📋 Current playlist view
- 📁 Browse music library
- 📊 Real-time status updates

## 🔧 Service Management

### Native Deployment
```bash
# Check status
sudo systemctl status usb-music-player.service

# View logs
sudo journalctl -u usb-music-player.service -f

# Restart service
sudo systemctl restart usb-music-player.service

# Stop service
sudo systemctl stop usb-music-player.service
```

### Development Mode
```bash
cd /home/pi/slab-local
source venv/bin/activate
export FLASK_ENV=development  # Enables auto-reload
python app.py
```

### Docker Deployment (if using legacy mode)
```bash
# Check status
docker-compose ps

# View logs  
docker-compose logs -f

# Restart
docker-compose restart

# Stop
docker-compose down
```

## 🛠️ Troubleshooting

### USB Drives Not Detected
```bash
# Check if drives are mounted by desktop environment
ls -la /media/pi/

# Check USB permissions
groups $USER  # Should include 'plugdev' group

# Check mount status
mount | grep /media/pi

# Monitor USB events
sudo udevadm monitor --property --subsystem-match=block
```

### Audio Issues
```bash
# Test audio output
aplay /usr/share/sounds/alsa/Front_Left.wav

# Check PulseAudio (native deployment)
pulseaudio --check -v
systemctl --user status pulseaudio

# List audio devices
pactl list short sinks
```

### Permission Issues
```bash
# Add user to plugdev group (if not already)
sudo usermod -aG plugdev $USER

# Check current groups
groups $USER

# Logout and login again to apply group changes
```

### Service Won't Start
```bash
# Check detailed logs
sudo journalctl -u usb-music-player.service -f --since "5 minutes ago"

# Check Python environment
cd /home/pi/slab-local
source venv/bin/activate
python -c "import flask, pygame, mutagen; print('All imports OK')"

# Manual start for debugging
python app.py
```

## 📁 Directory Structure

```
/media/pi/MUSIC           # Desktop auto-mount → Direct access by app
/media/pi/PLAY_CARD       # Desktop auto-mount → Direct access by app
```

**Native deployment is much simpler!** No bind mounts or permission complexity.

## ⚙️ Configuration

### Environment Variables
Edit `/etc/systemd/system/usb-music-player.service`:

```ini
Environment=CONTROL_FILE_NAME=playMusic.txt
Environment=WEB_PORT=5000
Environment=DEFAULT_VOLUME=70
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse
```

### Audio Configuration
```bash
# Select audio output device
sudo raspi-config
# Advanced Options → Audio → Choose output

# Or manually set audio device
export PULSE_SERVER=unix:/run/user/1000/pulse/native
```

## 🚀 Performance Comparison

| Feature | Native | Docker |
|---------|--------|---------|
| **Startup Time** | ~3 seconds | ~15 seconds |
| **USB Detection** | Instant | Can be problematic |
| **Audio Latency** | Minimal | Higher |
| **Memory Usage** | ~50MB | ~200MB |
| **Development** | Direct editing | Rebuild required |
| **Debugging** | Native tools | Container tools |
| **Permission Issues** | None | Common |

## 🔄 Rollback to Docker

If you need to rollback from native to Docker:

```bash
# Stop native services
sudo systemctl stop usb-music-player.service
sudo systemctl disable usb-music-player.service

# Use backup from migration
cd backup-YYYYMMDD-HHMMSS/  # Your backup directory
docker-compose up -d
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test with both native and Docker deployments
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Wiki**: Detailed setup guides and tutorials

---

**Made with ❤️ for the Raspberry Pi community**
