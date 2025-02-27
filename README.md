# SLAB ONE Music Player

A modern music player for Raspberry Pi that plays music from a USB drive based on control files from another USB drive. Features a Spotify-inspired UI built with React and Mantine.

![Music Player Screenshot](https://via.placeholder.com/800x450.png?text=SLAB+ONE+Music+Player)

## Features

- Sleek, responsive Spotify-inspired UI
- Dark/Light mode toggle
- Mobile-friendly design with full-width player controls
- Album artwork display from file metadata or cover images
- Music playback controls (play/pause, next/previous, volume)
- Album track listing
- Repeat mode
- System logs in collapsible accordion

## Project Structure

The project is organized into the following components:

- `main.py`: The main entry point that starts the web interface and monitors USB drives
- `config.py`: Configuration handling and global settings
- `player.py`: The Player class that handles VLC media playback
- `utils.py`: Utility functions for file operations, logging, etc.
- `web_interface.py`: Flask web interface for controlling the player
- `frontend/`: React frontend with Mantine UI

## Requirements

- Python 3.6+
- VLC media player
- Flask
- python-vlc
- mutagen (for metadata extraction)
- Node.js and npm (for frontend development)

## Quick Installation

The easiest way to install is using the provided installation script:

```bash
./install.sh
```

This script will:
1. Update your system
2. Install required dependencies
3. Set up a Python virtual environment
4. Install Python packages
5. Build the React frontend
6. Optionally set up a systemd service for autostart

## Manual Installation

If you prefer to install manually:

1. Install required system packages:
   ```bash
   sudo apt-get update
   sudo apt-get install -y vlc python3-pip python3-venv git
   ```

2. Install Node.js:
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

3. Set up Python environment and install dependencies:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

4. Build the frontend:
   ```bash
   cd frontend
   npm install
   npm run build
   cd ..
   ```

5. Run the player:
   ```bash
   python main.py
   ```

## Configuration

The default configuration is stored in `config.ini` and includes:

- `MUSIC_USB_MOUNT`: Path where the music USB drive is mounted (default: `/media/pi/MUSIC`)
- `CONTROL_USB_MOUNT`: Path where the control USB drive is mounted (default: `/media/pi/PLAY_CARD`)
- `CONTROL_FILE_NAME`: Name of the control file (default: `playMusic.txt`)
- `WEB_PORT`: Port for the web interface (default: `5000`)
- `DEFAULT_VOLUME`: Default volume level (default: `70`)

## Usage

1. Connect a USB drive with music to the Raspberry Pi (mounted at `MUSIC_USB_MOUNT`)
2. Connect a control USB drive (mounted at `CONTROL_USB_MOUNT`)
3. Create a file named `playMusic.txt` on the control USB with one of these formats:
   - `Album: AlbumName` - Plays an album folder
   - `Track: TrackName` - Plays a specific track

4. Access the web interface at `http://<raspberry-pi-ip>:5000/` to control playback

## Album Artwork

The player will attempt to display album artwork from:
1. Embedded metadata in MP3/FLAC files (requires mutagen library)
2. Cover image files in the album directory (looks for cover.jpg, folder.jpg, etc.)

## Development

### Frontend Development

The frontend is built with React and Mantine UI. To develop the frontend:

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm start
   ```

4. The development server will run on port 3000 and proxy API requests to the Flask backend on port 5000.

5. After making changes, build the production version:
   ```bash
   npm run build
   ```

### Deploying Changes

- For frontend changes only: Build the frontend and transfer the `frontend/build` directory to the Pi
- For backend changes: Transfer the modified Python files to the Pi and restart the application

## License

This project is open source and available under the MIT License. 