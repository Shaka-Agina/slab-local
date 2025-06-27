#!/bin/bash

# USB Music Player One-Click Installation Script for Raspberry Pi

set -e

# Set non-interactive mode to prevent prompts
export DEBIAN_FRONTEND=noninteractive

# Configure automatic service restarts
echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

# Configure needrestart to not prompt
sudo mkdir -p /etc/needrestart/conf.d
echo '$nrconf{restart} = "a";' | sudo tee /etc/needrestart/conf.d/50-auto.conf > /dev/null

echo "=== USB Music Player One-Click Installation ==="
echo "This script will clone the repository, build the application, and deploy everything."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Timeout function to prevent hanging
run_with_timeout() {
    local timeout=$1
    shift
    timeout $timeout "$@"
}

# Progress indicator for long operations
show_progress() {
    local pid=$1
    local message=$2
    local spinner='|/-\'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${GREEN}[INFO]${NC} $message ${spinner:$i:1}"
        i=$(((i+1)%4))
        sleep 0.5
    done
    printf "\r${GREEN}[INFO]${NC} $message... Done!\n"
}

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    print_warning "This script is designed for Raspberry Pi. Continuing anyway..."
fi

# Check if running on desktop environment
if [ -n "$DISPLAY" ] || systemctl is-active --quiet graphical.target 2>/dev/null; then
    print_status "Desktop environment detected - will use built-in USB auto-mounting"
else
    print_warning "No desktop environment detected. USB auto-mounting may not work."
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

# Step 1: Update system
print_step "1/8 - Updating system packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update

# Fix any broken VLC packages before upgrading system
print_status "Checking for package conflicts before system upgrade..."
if dpkg -l | grep -q vlc; then
    print_status "VLC packages detected. Preventing conflicts during upgrade..."
    
    # Fix any currently broken packages
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y || true
    
    # Hold VLC packages to prevent conflicts during upgrade
    sudo apt-mark hold vlc vlc-bin vlc-plugin-base vlc-plugin-qt vlc-plugin-skins2 2>/dev/null || true
    
    # Perform system upgrade
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    # Unhold VLC packages after upgrade
    sudo apt-mark unhold vlc vlc-bin vlc-plugin-base vlc-plugin-qt vlc-plugin-skins2 2>/dev/null || true
    
    print_status "System upgrade completed. VLC packages preserved."
else
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
fi

# Step 2: Install system dependencies
print_step "2/8 - Installing system dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git curl nodejs npm python3-pip python3-venv

# Step 3: Install Docker
print_step "3/8 - Installing Docker..."
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_status "Docker installed successfully"
else
    print_status "Docker is already installed"
    # Ensure user is in docker group
    if ! groups $USER | grep -q docker; then
        print_status "Adding user to Docker group..."
        sudo usermod -aG docker $USER
    fi
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose
    print_status "Docker Compose installed successfully"
else
    print_status "Docker Compose is already installed"
fi

# Activate Docker group permissions immediately
print_status "Activating Docker group permissions..."

# Start Docker service if it's not running
if ! systemctl is-active --quiet docker; then
    print_status "Starting Docker service..."
    sudo systemctl start docker
    sleep 3
fi

# Test Docker permissions without using newgrp (which can hang)
print_status "Testing Docker access permissions..."

# Test without sudo first (with timeout)
if run_with_timeout 10 docker ps >/dev/null 2>&1; then
    print_status "Docker access working without sudo"
    USE_SUDO_DOCKER="no"
# Test with sudo (with timeout)
elif run_with_timeout 10 sudo docker ps >/dev/null 2>&1; then
    print_warning "Docker requires sudo access (group permissions not active yet)"
    print_status "This is normal for fresh installations - will use sudo for Docker commands"
    USE_SUDO_DOCKER="yes"
else
    print_error "Docker is not responding properly. Checking Docker service status..."
    sudo systemctl status docker --no-pager || true
    print_error "Please check Docker installation and try again."
    exit 1
fi

# Step 4: Install/check VLC
print_step "4/8 - Checking VLC installation..."
if command -v vlc &> /dev/null; then
    print_status "VLC is already installed"
    
    # Test VLC functionality
    if vlc --version >/dev/null 2>&1; then
        print_status "VLC is working correctly"
    else
        print_warning "VLC installation may be broken. Attempting repair..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -f
        sudo DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y vlc-bin vlc-plugin-base
    fi
else
    print_status "Installing VLC..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -f  # Fix any broken packages first
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y vlc vlc-plugin-base
fi

# Step 5: Clone repository
print_step "5/8 - Cloning repository..."
INSTALL_DIR="$HOME/slab-local"

if [ -d "$INSTALL_DIR" ]; then
    print_warning "Directory $INSTALL_DIR already exists. Updating..."
    cd "$INSTALL_DIR"
    git pull origin main || print_warning "Failed to update repository"
else
    print_status "Cloning repository to $INSTALL_DIR..."
    git clone https://github.com/Shaka-Agina/slab-local.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Step 6: Build frontend
print_step "6/8 - Building frontend application..."
cd frontend

print_status "Installing frontend dependencies..."
npm install

print_status "Building frontend for production..."
npm run build

print_status "Frontend build completed successfully"
cd ..

# Step 7: Set up USB mount points (for desktop auto-mounting)
print_step "7/8 - Setting up USB mount points..."
sudo mkdir -p /media/pi/MUSIC
sudo mkdir -p /media/pi/PLAY_CARD
sudo chown pi:pi /media/pi/MUSIC /media/pi/PLAY_CARD
print_status "USB mount points created (will be used by desktop auto-mounting)"

# Create necessary directories for Docker volumes
print_status "Creating Docker volume directories..."
mkdir -p ./config
mkdir -p ./logs

# Set up audio group permissions
print_status "Setting up audio permissions..."
sudo usermod -aG audio $USER

# Step 8: Build and deploy Docker container
print_step "8/8 - Building and deploying application..."

# Define Docker command prefix based on permissions
if [ "$USE_SUDO_DOCKER" = "yes" ]; then
    DOCKER_CMD="sudo docker-compose"
    print_status "Using sudo for Docker commands due to group permission issue"
else
    DOCKER_CMD="docker-compose"
fi

# Stop any existing container
run_with_timeout 30 $DOCKER_CMD down 2>/dev/null || true

# Build the image
print_status "Building Docker image (this may take several minutes)..."
$DOCKER_CMD build &
BUILD_PID=$!

# Show progress while building
show_progress $BUILD_PID "Building Docker image"

# Wait for build to complete and check result
if ! wait $BUILD_PID; then
    print_error "Docker build failed. This might be due to:"
    echo "  • Slow internet connection"
    echo "  • Docker daemon issues"
    echo "  • Insufficient disk space"
    echo "  • Missing dependencies"
    print_status "Checking Docker service status..."
    sudo systemctl status docker --no-pager || true
    exit 1
fi

# Start the container
print_status "Starting container..."
if ! run_with_timeout 60 $DOCKER_CMD up -d; then
    print_error "Failed to start container. Checking logs..."
    $DOCKER_CMD logs || true
    exit 1
fi

# Wait for container to be ready
print_status "Waiting for container to start..."
sleep 10

# Check container status
print_status "Checking container status..."
if run_with_timeout 15 $DOCKER_CMD ps | grep -q "Up"; then
    print_status "Container started successfully!"
    
    echo ""
    echo "==============================================="
    echo "🎉 INSTALLATION COMPLETE! 🎉"
    echo "==============================================="
    echo ""
    echo "📍 Installation Directory: $INSTALL_DIR"
    echo ""
    echo "🌐 Access the web interface at:"
    echo "   • http://localhost:5000"
    echo "   • http://$(hostname -I | awk '{print $1}'):5000"
    echo ""
    echo "💾 USB Drive Setup:"
    echo "   • Label your music USB drive as 'MUSIC'"
    echo "   • Label your control USB drive as 'PLAY_CARD'"
    echo "   • Create a file named 'playMusic.txt' on the PLAY_CARD drive"
    echo ""
    echo "⚙️  Container Management:"
    if [ "$USE_SUDO_DOCKER" = "yes" ]; then
        echo "   • View logs: cd $INSTALL_DIR && sudo docker-compose logs -f"
        echo "   • Stop: cd $INSTALL_DIR && sudo docker-compose down"
        echo "   • Restart: cd $INSTALL_DIR && sudo docker-compose restart"
        echo "   • Rebuild: cd $INSTALL_DIR && sudo docker-compose build --no-cache"
    else
        echo "   • View logs: cd $INSTALL_DIR && docker-compose logs -f"
        echo "   • Stop: cd $INSTALL_DIR && docker-compose down"
        echo "   • Restart: cd $INSTALL_DIR && docker-compose restart"
        echo "   • Rebuild: cd $INSTALL_DIR && docker-compose build --no-cache"
    fi
    echo ""
else
    print_error "Container failed to start. Check logs with: cd $INSTALL_DIR && $DOCKER_CMD logs"
    exit 1
fi

# Set up systemd service for auto-start
print_status "Setting up auto-start service..."

# Create the systemd service with conditional sudo
if [ "$USE_SUDO_DOCKER" = "yes" ]; then
    sudo tee /etc/systemd/system/usb-music-player.service > /dev/null << EOL
[Unit]
Description=USB Music Player Docker Container
Requires=docker.service
After=docker.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOL
else
    sudo tee /etc/systemd/system/usb-music-player.service > /dev/null << EOL
[Unit]
Description=USB Music Player Docker Container
Requires=docker.service
After=docker.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOL
fi

sudo systemctl daemon-reload
sudo systemctl enable usb-music-player.service

print_status "Auto-start service enabled"

echo ""
echo "🔄 The music player will start automatically on boot!"
echo ""
echo "💡 Tips:"
echo "   • Reboot to test auto-start: sudo reboot"
echo "   • Check service status: sudo systemctl status usb-music-player.service"
echo "   • USB drives will be automatically mounted when inserted"
echo ""

# Note about Docker group
if [ "$USE_SUDO_DOCKER" = "yes" ]; then
    print_warning "Docker commands require sudo due to group permission timing"
    echo "💭 After a reboot, Docker should work without sudo. For now:"
    echo "   • All Docker commands need 'sudo' prefix"
    echo "   • The systemd service is configured to handle this automatically"
    echo "   • To manually fix: log out and back in, then run:"
    echo "     cd $INSTALL_DIR && docker-compose restart"
else
    if groups $USER | grep -q docker; then
        print_status "Docker group permissions are working correctly"
    else
        print_warning "You may need to log out and back in for Docker group permissions to take effect"
        echo "💭 If you encounter Docker permission issues later, log out and back in, then run:"
        echo "   cd $INSTALL_DIR && docker-compose restart"
    fi
fi

print_status "🚀 One-click installation completed successfully!" 