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