#!/bin/bash

# Cleanup script to remove duplicate USB directories
# Run this once to clean up any directories created by previous versions

echo "=== USB Directory Cleanup ==="
echo "This script will remove any duplicate USB directories created by previous versions."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR]${NC} Please run this script as a regular user (not root/sudo)"
    echo "Usage: ./cleanup-duplicate-usb-dirs.sh"
    exit 1
fi

print_status "Checking for duplicate USB directories in /media/pi..."

# Check what's currently in /media/pi
if [ -d "/media/pi" ]; then
    current_contents=$(ls -la /media/pi 2>/dev/null || true)
    echo "Current contents of /media/pi:"
    echo "$current_contents"
    echo ""
    
    # Look for empty directories (not mount points)
    empty_dirs=()
    for dir in /media/pi/MUSIC* /media/pi/PLAY_CARD*; do
        if [ -d "$dir" ] && ! mountpoint -q "$dir" 2>/dev/null; then
            # Check if directory is empty
            if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
                empty_dirs+=("$dir")
            fi
        fi
    done
    
    if [ ${#empty_dirs[@]} -gt 0 ]; then
        print_warning "Found empty USB directories (not mount points):"
        for dir in "${empty_dirs[@]}"; do
            echo "  - $dir"
        done
        echo ""
        
        read -p "Remove these empty directories? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            for dir in "${empty_dirs[@]}"; do
                print_status "Removing empty directory: $dir"
                sudo rm -rf "$dir"
            done
            print_status "Empty directories removed."
        else
            print_status "Skipping directory removal."
        fi
    else
        print_status "No empty USB directories found. All directories appear to be proper mount points."
    fi
else
    print_status "/media/pi directory does not exist."
fi

echo ""
print_status "Cleanup complete!"
echo ""
echo "💡 Going forward:"
echo "• The application will automatically detect USB drives wherever they're mounted"
echo "• No directories will be created - only using what the desktop environment provides"
echo "• Unplug and replug your USB drives to see the clean mounting behavior" 