#!/bin/bash

echo "=== SLAB ONE Installation Fix ==="
echo "This script will fix the Flask and Werkzeug version compatibility issue."

# Activate the virtual environment
echo -e "\n[1/3] Activating virtual environment..."
cd "$(dirname "$0")"
source venv/bin/activate

# Uninstall current Flask and Werkzeug
echo -e "\n[2/3] Uninstalling current Flask and Werkzeug..."
pip uninstall -y flask werkzeug

# Install specific versions
echo -e "\n[3/3] Installing compatible versions..."
pip install Flask==2.0.1 Werkzeug==2.0.1 Flask-CORS==3.0.10

echo -e "\n=== Fix Complete! ==="
echo "You can now start the application with: python main.py"
echo "Or restart the service with: sudo systemctl restart music-player.service" 