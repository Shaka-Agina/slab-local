# Raspberry Pi USB Music Player

A USB-triggered music player for Raspberry Pi that automatically plays music when USB drives are inserted.

## Features

- 🎵 **Auto-play from USB**: Plug in a USB drive and music starts automatically
- 📱 **Web Interface**: Control playbook through a modern web interface
- 🔄 **Album/Track Control**: Play entire albums or individual tracks
- 🔊 **Volume Control**: Adjust volume through the web interface
- 📡 **WiFi Hotspot**: Creates its own WiFi network for easy access
- 🎨 **Album Art**: Displays album artwork when available
- 🔁 **Repeat Mode**: Toggle repeat playback
- 🐳 **Docker Support**: Easy deployment with Docker containers

## Desktop Environment Setup (Recommended)

This setup is designed for Raspberry Pi OS with Desktop Environment, which includes:
- Built-in USB auto-mounting (no manual fstab configuration needed)
- VLC pre-installed
- Automatic boot-up service

### Quick Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd slab-local
   ```

2. **Run the installation script:**
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

3. **Reboot your Raspberry Pi:**
   ```bash
   sudo reboot
   ```

## How It Works

### USB Setup
- **Music USB**: Label your USB drive as `MUSIC` and put your music files in folders by album
- **Control USB**: Label a small USB drive as `PLAY_CARD` and create a `playMusic.txt` file

### Control File Format
Create a `playMusic.txt` file on your control USB with one of these formats:

```
Album: YourAlbumName
```
or
```
Track: YourTrackName
```

### USB Mount Points
The application expects USB drives to be mounted at:
- **Music USB**: `/media/pi/MUSIC`
- **Control USB**: `/media/pi/PLAY_CARD`

The desktop environment will automatically mount labeled drives to these locations.

## Web Interface Access

After installation, the music player creates a WiFi hotspot:

1. **Connect to WiFi**: Look for network named "S L A B - XXXX" 
2. **Password**: `slabmusic`
3. **Web Interface**: Open browser and go to `http://slab.local:5000` or `http://192.168.4.1:5000`

## Configuration

The application uses environment variables for configuration:

- `MUSIC_USB_MOUNT`: Path where music USB drives are mounted (default: `/media/pi/MUSIC`)
- `CONTROL_USB_MOUNT`: Path where control USB drives are mounted (default: `/media/pi/PLAY_CARD`)
- `CONTROL_FILE_NAME`: Name of the control file (default: `playMusic.txt`)
- `WEB_PORT`: Web interface port (default: `5000`)
- `DEFAULT_VOLUME`: Default volume level (default: `70`)

## Service Management

### Docker Service Commands:
```bash
# Start the music player
sudo systemctl start music-player-docker.service

# Stop the music player  
sudo systemctl stop music-player-docker.service

# Check service status
sudo systemctl status music-player-docker.service

# View logs
docker-compose logs -f
```

### Hotspot Service Commands:
```bash
# Start/stop hotspot
sudo systemctl start auto-hotspot.service
sudo systemctl stop auto-hotspot.service
```

## Troubleshooting

### USB Drives Not Detected
1. Check if drives are properly mounted: `ls -la /media/pi/`
2. Ensure drives are labeled correctly (`MUSIC` and `PLAY_CARD`)
3. Try removing and reinserting the USB drives
4. Check mount status: `mount | grep /media/pi`

### Web Interface Not Accessible
1. Check if hotspot is running: `sudo systemctl status auto-hotspot.service`
2. Verify Docker service: `sudo systemctl status music-player-docker.service`
3. Check if ports are accessible: `sudo netstat -tlnp | grep 5000`

### Audio Issues
1. Check audio devices: `aplay -l`
2. Verify VLC installation: `vlc --version`
3. Check PulseAudio: `pulseaudio --check`

## Manual Testing

You can test the system manually:

```bash
# Test Docker build
docker-compose build

# Test Docker run
docker-compose up

# Test USB detection
ls -la /media/pi/

# Test mount points
mount | grep /media/pi

# Test audio
vlc /path/to/test/audio/file.mp3
```

## File Structure

```
slab-local/
├── docker-compose.yml          # Docker container configuration
├── Dockerfile                  # Docker image build instructions
├── install.sh                  # Desktop environment setup script
├── main.py                     # Main application entry point
├── player.py                   # Music player logic
├── web_interface.py            # Web interface and API
├── config.py                   # Configuration management
├── utils.py                    # Utility functions
├── requirements.txt            # Python dependencies
└── frontend/                   # React web interface
    ├── src/
    └── build/
```

## Legacy Headless Setup

For headless Raspberry Pi setups without desktop environment, see `DOCKER_DEPLOYMENT.md` for manual USB mounting configuration.

---

**Note**: This version is optimized for Raspberry Pi OS with Desktop Environment. USB drives labeled `MUSIC` and `PLAY_CARD` will be automatically mounted to `/media/pi/MUSIC` and `/media/pi/PLAY_CARD` respectively. 