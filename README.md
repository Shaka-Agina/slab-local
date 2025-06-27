# Raspberry Pi USB Music Player

A USB-triggered music player for Raspberry Pi that automatically plays music when USB drives are inserted.

## 🚀 One-Command Installation (Recommended)

Get up and running in minutes with our automated installer:

```bash
curl -fsSL https://raw.githubusercontent.com/Shaka-Agina/slab-local/main/deploy-docker.sh | bash
```

This command will:
- ✅ Install Docker and Docker Compose
- ✅ Set up USB automounting for labeled drives
- ✅ Configure system dependencies
- ✅ Build and deploy the music player container
- ✅ Set up audio permissions
- ✅ Optionally configure auto-start on boot

**Requirements:**
- Raspberry Pi running Raspberry Pi OS
- Internet connection for initial setup
- USB drives labeled `MUSIC` and `PLAY_CARD`

---

## Features

- 🎵 **Auto-play from USB**: Plug in a USB drive and music starts automatically
- 📱 **Web Interface**: Control playbook through a modern web interface
- 🔄 **Album/Track Control**: Play entire albums or individual tracks
- 🔊 **Volume Control**: Adjust volume through the web interface
- 📡 **WiFi Hotspot**: Creates its own WiFi network for easy access
- 🎨 **Album Art**: Displays album artwork when available
- 🔁 **Repeat Mode**: Toggle repeat playback
- 🐳 **Docker Support**: Easy deployment with Docker containers

## Alternative Installation Methods

### Desktop Environment Setup

This setup is designed for Raspberry Pi OS with Desktop Environment, which includes:
- Built-in USB auto-mounting (no manual fstab configuration needed)
- VLC pre-installed
- Automatic boot-up service

#### Manual Installation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Shaka-Agina/slab-local.git
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

### Docker Deployment (Manual)

For advanced users who want more control:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Shaka-Agina/slab-local.git
   cd slab-local
   ```

2. **Run the Docker deployment script:**
   ```bash
   chmod +x deploy-docker.sh
   ./deploy-docker.sh
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

The system will automatically mount labeled drives to these locations.

## Web Interface Access

After installation, the music player creates a WiFi hotspot:

1. **Connect to WiFi**: Look for network named "S L A B - XXXX" 
2. **Password**: `slabmusic`
3. **Web Interface**: Open browser and go to `http://slab.local:5000` or `http://192.168.4.1:5000`

Alternatively, if connected to your local network:
- `http://localhost:5000`
- `http://[your-pi-ip]:5000`

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
sudo systemctl start usb-music-player.service

# Stop the music player  
sudo systemctl stop usb-music-player.service

# Check service status
sudo systemctl status usb-music-player.service

# View logs
docker-compose logs -f
```

### Container Management:
```bash
# View logs
docker-compose logs -f

# Stop containers
docker-compose down

# Restart containers
docker-compose restart

# Rebuild containers
docker-compose build --no-cache
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
5. Check automount services: `sudo systemctl status media-pi-*.automount`

### Web Interface Not Accessible
1. Check if hotspot is running: `sudo systemctl status auto-hotspot.service`
2. Verify Docker service: `sudo systemctl status usb-music-player.service`
3. Check if ports are accessible: `sudo netstat -tlnp | grep 5000`
4. Check container status: `docker-compose ps`

### Audio Issues
1. Check audio devices: `aplay -l`
2. Verify VLC installation: `vlc --version`
3. Check PulseAudio: `pulseaudio --check`
4. Verify audio group membership: `groups $USER | grep audio`

### VLC Package Issues
If you encounter VLC dependency conflicts during installation:
1. Fix broken packages: `sudo apt-get install -f`
2. Update package lists: `sudo apt-get update`
3. Reinstall VLC components: `sudo apt-get install --reinstall vlc-bin vlc-plugin-base`
4. If completely broken, remove and reinstall: 
   ```bash
   sudo apt-get remove --purge vlc*
   sudo apt-get autoremove
   sudo apt-get install -y vlc
   ```

### Installation Issues
1. Ensure you have internet connection
2. Check if running as correct user (not root): `whoami`
3. Verify system compatibility: `uname -a`
4. Check available disk space: `df -h`

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

# Test automount services
sudo systemctl status media-pi-MUSIC.automount
sudo systemctl status media-pi-PLAY_CARD.automount
```

## File Structure

```
slab-local/
├── docker-compose.yml          # Docker container configuration
├── Dockerfile                  # Docker image build instructions
├── deploy-docker.sh            # One-command Docker deployment script
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

## Quick Start Guide

1. **Run the one-command installer:**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Shaka-Agina/slab-local/main/deploy-docker.sh | bash
   ```

2. **Prepare your USB drives:**
   - Label one USB drive as `MUSIC` and add your music files organized by album
   - Label another USB drive as `PLAY_CARD` and create a `playMusic.txt` file

3. **Connect and play:**
   - Insert both USB drives into your Raspberry Pi
   - Connect to the "S L A B - XXXX" WiFi network (password: `slabmusic`)
   - Open `http://slab.local:5000` in your browser
   - Enjoy your music!

---

**Note**: This system supports both desktop and headless Raspberry Pi OS installations. USB drives labeled `MUSIC` and `PLAY_CARD` will be automatically mounted and configured for seamless music playbook.
