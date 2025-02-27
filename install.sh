#!/bin/bash

# Music Player Installation Script

echo "=== Raspberry Pi Music Player Installation ==="
echo "This script will install all dependencies and set up the music player."

# Update system
echo -e "\n[1/6] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo -e "\n[2/6] Installing system dependencies..."
sudo apt-get install -y vlc python3-pip python3-venv git

# Install Node.js
echo -e "\n[3/6] Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js is already installed."
fi

# Set up Python virtual environment
echo -e "\n[4/6] Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo -e "\n[5/6] Installing Python dependencies..."
pip install -r requirements.txt

# Build frontend
echo -e "\n[6/6] Building the frontend..."
cd frontend
npm install
npm run build
cd ..

# Create systemd service
echo -e "\n[Optional] Setting up systemd service..."
read -p "Do you want to set up the music player to start automatically on boot? (y/n): " setup_service

if [[ $setup_service == "y" || $setup_service == "Y" ]]; then
    SERVICE_PATH="/etc/systemd/system/music-player.service"
    CURRENT_DIR=$(pwd)
    
    sudo bash -c "cat > $SERVICE_PATH << EOL
[Unit]
Description=Raspberry Pi Music Player
After=network.target

[Service]
User=$USER
WorkingDirectory=$CURRENT_DIR
ExecStart=$CURRENT_DIR/venv/bin/python $CURRENT_DIR/main.py
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL"

    sudo systemctl daemon-reload
    sudo systemctl enable music-player.service
    sudo systemctl start music-player.service
    
    echo "Service installed and started. Check status with: sudo systemctl status music-player.service"
else
    echo "Skipping service setup. You can start the player manually with: python main.py"
fi

echo -e "\n=== Installation Complete! ==="
echo "You can access the web interface at: http://$(hostname -I | awk '{print $1}'):5000/"
echo "To start the player manually: source venv/bin/activate && python main.py" 