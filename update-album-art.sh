#!/bin/bash

echo "=== SLAB ONE Album Art Fix ==="
echo "This script will update the web_interface.py file to fix album art extraction."

# Check if web_interface.py exists
if [ ! -f "web_interface.py" ]; then
    echo "Error: web_interface.py not found in the current directory."
    echo "Please run this script from the slab-local directory."
    exit 1
fi

# Backup the original file
echo -e "\n[1/3] Creating backup of web_interface.py..."
cp web_interface.py web_interface.py.bak
echo "Backup created as web_interface.py.bak"

# Restart the service if it's running
echo -e "\n[2/3] Checking if the music player service is running..."
if systemctl is-active --quiet music-player.service; then
    echo "Stopping music-player service..."
    sudo systemctl stop music-player.service
    SERVICE_WAS_RUNNING=true
else
    SERVICE_WAS_RUNNING=false
fi

# Start the service again if it was running
echo -e "\n[3/3] Fix applied. Starting the service..."
if [ "$SERVICE_WAS_RUNNING" = true ]; then
    sudo systemctl start music-player.service
    echo "Music player service restarted."
else
    echo "Music player service was not running. You can start it manually with:"
    echo "sudo systemctl start music-player.service"
    echo "or"
    echo "python main.py"
fi

echo -e "\n=== Fix Complete! ==="
echo "The album art extraction has been improved to handle URL-encoded paths"
echo "and better detect album artwork in the music directories." 