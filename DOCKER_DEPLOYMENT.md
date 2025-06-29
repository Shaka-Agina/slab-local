# USB Music Player - Docker Deployment Guide

This guide will help you deploy your USB Music Player on a Raspberry Pi using Docker, making the setup process much faster and more reliable.

## Prerequisites

- Raspberry Pi (3B+ or newer recommended)
- Raspberry Pi OS (Bullseye or newer)
- Internet connection for initial setup
- Two USB drives:
  - One labeled `MUSIC` (contains your music files)
  - One labeled `PLAY_CARD` (contains control file)

## Quick Deployment

### Option 1: Automated Deployment (Recommended)

1. **Clone or copy your project to the Raspberry Pi:**
   ```bash
   git clone <your-repo-url>
   cd <your-project-directory>
   ```

2. **Run the automated deployment script:**
   ```bash
   chmod +x deploy-docker.sh
   ./deploy-docker.sh
   ```

   This script will:
   - Install Docker and Docker Compose
   - Set up USB automounting
   - Build and start the container
   - Optionally set up auto-start on boot

### Option 2: Manual Deployment

1. **Install Docker:**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   ```

2. **Install Docker Compose:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker-compose
   ```

3. **Set up USB mounting:**
   ```bash
   sudo apt-get install -y exfat-fuse exfatprogs
   sudo mkdir -p /media/pi
   sudo chown pi:pi /media/pi
   
   # The deployment script will automatically detect your environment:
   # - Desktop systems: Uses built-in auto-mounting (clean paths like /media/pi/PLAY_CARD)
   # - Headless systems: Creates custom udev rules for mounting
   ```

4. **Build and start the container:**
   ```bash
   docker-compose up -d --build
   ```

## USB Drive Setup

### Music USB Drive (MUSIC)
- Label: `MUSIC`
- Format: exFAT (recommended) or FAT32
- Structure: Organize your music in folders by album/artist

### Control USB Drive (PLAY_CARD)
- Label: `PLAY_CARD`
- Format: exFAT (recommended) or FAT32
- Contains: `playMusic.txt` file with playback instructions

### Control File Format (`playMusic.txt`)
```
Album: <album_folder_name>
```
or
```
Track: <track_filename>
```

## Accessing the Web Interface

Once deployed, access the music player at:
- **Local access:** http://localhost:5000
- **Network access:** http://[raspberry-pi-ip]:5000
- **Hotspot access:** http://192.168.4.1:5000 (if hotspot is configured)

## Container Management

### View logs:
```bash
docker-compose logs -f
```

### Stop the container:
```bash
docker-compose down
```

### Restart the container:
```bash
docker-compose restart
```

### Rebuild after code changes:
```bash
docker-compose build --no-cache
docker-compose up -d
```

### Check container status:
```bash
docker-compose ps
```

## Troubleshooting

### Container won't start
1. Check logs: `docker-compose logs`
2. Verify USB drives are properly mounted: `ls -la /media/pi/`
3. Check audio permissions: `groups $USER` (should include `audio`)

### No audio output
1. Ensure audio device is not muted: `alsamixer`
2. Check PulseAudio: `pulseaudio --check -v`
3. Verify container has audio access: `docker-compose logs | grep audio`

### USB drives not detected
1. Check drive labels: `lsblk -f`
2. Manually mount: `sudo mount /dev/sda1 /media/pi/MUSIC`
3. Check systemd mount services: `systemctl status media-pi-*.mount`

### Web interface not accessible
1. Check if container is running: `docker-compose ps`
2. Verify port 5000 is not blocked: `netstat -tlnp | grep 5000`
3. Check container health: `docker-compose exec music-player curl http://localhost:5000/health`

## Configuration

### Environment Variables
Modify `docker-compose.yml` to change:
- `WEB_PORT`: Web interface port (default: 5000)
- `DEFAULT_VOLUME`: Initial volume level (default: 70)
- `MUSIC_USB_MOUNT`: Music USB mount point
- `CONTROL_USB_MOUNT`: Control USB mount point

### Persistent Configuration
Configuration files are stored in `./config/` and persist across container restarts.

## Auto-Start on Boot

The deployment script can set up a systemd service for auto-start:

```bash
sudo systemctl status usb-music-player.service
sudo systemctl enable usb-music-player.service
sudo systemctl start usb-music-player.service
```

## Benefits of Docker Deployment

1. **Faster Setup**: No need to install individual dependencies
2. **Consistency**: Same environment every time
3. **Isolation**: Doesn't interfere with system packages
4. **Easy Updates**: Rebuild container for updates
5. **Portability**: Works on any Docker-capable system
6. **Rollback**: Easy to revert to previous versions

## Performance Notes

- First build may take 10-15 minutes on Raspberry Pi
- Subsequent builds are faster due to Docker layer caching
- Container uses minimal resources when idle
- Audio latency is comparable to native installation

## Security Considerations

- Container runs with necessary privileges for USB and audio access
- Web interface is accessible on all network interfaces
- Consider firewall rules for production deployments
- USB automounting requires elevated privileges 