#!/bin/bash

# SLAB ONE Frontend Deployment Script
# This script builds the frontend and helps deploy it to a Raspberry Pi

echo "=== SLAB ONE Frontend Deployment ==="

# Build the frontend
echo -e "\n[1/3] Building the frontend..."
cd frontend
npm run build
cd ..

echo -e "\n[2/3] Frontend build complete!"

# Ask for Raspberry Pi details
echo -e "\n[3/3] Deploy to Raspberry Pi?"
read -p "Do you want to deploy to a Raspberry Pi? (y/n): " deploy_choice

if [[ $deploy_choice == "y" || $deploy_choice == "Y" ]]; then
    read -p "Enter Raspberry Pi IP address: " pi_ip
    read -p "Enter username (default: pi): " pi_user
    pi_user=${pi_user:-pi}
    read -p "Enter path to project on Pi (default: ~/slab-local): " pi_path
    pi_path=${pi_path:-"~/slab-local"}
    
    echo -e "\nDeploying to ${pi_user}@${pi_ip}:${pi_path}/frontend/build..."
    
    # Use rsync to transfer only changed files
    rsync -avz --progress frontend/build/ ${pi_user}@${pi_ip}:${pi_path}/frontend/build/
    
    echo -e "\nDeployment complete!"
    echo "You may need to restart the Flask application on the Pi if it's already running."
    echo "SSH command: ssh ${pi_user}@${pi_ip}"
    echo "Restart command: sudo systemctl restart music-player.service"
else
    echo -e "\nSkipping deployment. The built files are in the frontend/build directory."
fi

echo -e "\n=== Done! ===" 