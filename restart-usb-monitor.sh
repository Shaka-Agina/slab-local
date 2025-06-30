#!/bin/bash

echo "Restarting USB monitoring with simplified static mount approach..."

# Stop the old service
sudo systemctl stop usb-bind-monitor 2>/dev/null || true

# Apply the new simplified script from install.sh
sudo cp /usr/local/bin/usb-bind-monitor.sh /usr/local/bin/usb-bind-monitor.sh.backup 2>/dev/null || true

# The new script is already in install.sh, so we need to extract and apply it
echo "Installing new simplified USB monitor script..."

# Create the new simplified script directly
sudo bash -c 'cat > /usr/local/bin/usb-bind-monitor.sh << '"'"'EOL'"'"'
#!/bin/bash

# Simple USB Bind Mount Monitor - Static Mount Points
LOG_FILE="/var/log/usb-bind-mounts.log"
MUSIC_BIND="/home/pi/usb/music"
CONTROL_BIND="/home/pi/usb/playcard"

log_message() {
    echo "$(date '"'"'+%Y-%m-%d %H:%M:%S'"'"') - $1" | tee -a "$LOG_FILE"
}

# Create static mount points (always exist)
setup_static_mounts() {
    mkdir -p "$MUSIC_BIND" "$CONTROL_BIND"
    chown pi:pi "$MUSIC_BIND" "$CONTROL_BIND"
    log_message "Static mount points created: $MUSIC_BIND, $CONTROL_BIND"
}

# Simple function to bind mount if not already mounted
bind_usb_to_static() {
    local source="$1"
    local target="$2"
    local label="$3"
    
    # Check if target is already bind mounted
    if mountpoint -q "$target"; then
        # Check if it'"'"'s the same source
        current_source=$(findmnt -n -o SOURCE "$target" 2>/dev/null)
        if [ "$current_source" = "$source" ]; then
            return 0  # Already correctly mounted
        else
            log_message "Unmounting old bind mount: $target (was: $current_source)"
            umount "$target" 2>/dev/null || true
        fi
    fi
    
    # Wait a moment for USB to be fully ready
    sleep 2
    
    # Check if source is accessible and has content
    if [ -d "$source" ] && mountpoint -q "$source" && [ -n "$(ls -A "$source" 2>/dev/null)" ]; then
        if mount --bind "$source" "$target"; then
            log_message "SUCCESS: Bind mounted $source -> $target ($label)"
            
            # Verify specific content for control USB
            if [ "$label" = "control" ] && [ -f "$target/control.txt" ]; then
                log_message "VERIFIED: Control file found at $target/control.txt"
            elif [ "$label" = "control" ]; then
                log_message "WARNING: Control USB mounted but no control.txt file found"
            fi
            
            return 0
        else
            log_message "FAILED: Could not bind mount $source -> $target"
            return 1
        fi
    else
        log_message "SKIPPED: Source not ready or empty: $source"
        return 1
    fi
}

# Clean up orphaned mounts (only unmount if source USB is gone)
cleanup_orphaned_mounts() {
    for target in "$MUSIC_BIND" "$CONTROL_BIND"; do
        if mountpoint -q "$target"; then
            source=$(findmnt -n -o SOURCE "$target" 2>/dev/null)
            if [ -n "$source" ]; then
                # Check if the original USB mount point still exists and is mounted
                if ! mountpoint -q "$source" 2>/dev/null; then
                    log_message "Cleaning up orphaned bind mount: $target (source $source no longer mounted)"
                    umount "$target" 2>/dev/null || true
                fi
            fi
        fi
    done
}

# Scan for USB drives and bind mount them to static points
scan_and_bind_usb() {
    log_message "Scanning for USB drives to bind mount..."
    
    # Look for mounted USB drives in /media/pi/
    for usb_mount in /media/pi/*; do
        if [ -d "$usb_mount" ] && mountpoint -q "$usb_mount"; then
            usb_label=$(basename "$usb_mount")
            log_message "Found USB drive: $usb_mount (label: $usb_label)"
            
            # Check for music USB (MUSIC or MUSIC with numbers, or has music files)
            if [[ "$usb_label" =~ ^MUSIC[0-9]*$ ]] || [ "$usb_label" = "MUSIC" ]; then
                log_message "Detected MUSIC USB: $usb_mount"
                bind_usb_to_static "$usb_mount" "$MUSIC_BIND" "music"
            elif find "$usb_mount" -maxdepth 2 -type f \( -iname '"'"'*.mp3'"'"' -o -iname '"'"'*.wav'"'"' -o -iname '"'"'*.flac'"'"' -o -iname '"'"'*.m4a'"'"' \) -print -quit | grep -q .; then
                log_message "Detected music files in: $usb_mount"
                bind_usb_to_static "$usb_mount" "$MUSIC_BIND" "music"
            fi
            
            # Check for control USB (PLAY_CARD or has control.txt)
            if [[ "$usb_label" =~ ^PLAY_CARD[0-9]*$ ]] || [ "$usb_label" = "PLAY_CARD" ]; then
                log_message "Detected PLAY_CARD USB: $usb_mount"
                bind_usb_to_static "$usb_mount" "$CONTROL_BIND" "control"
            elif [ -f "$usb_mount/control.txt" ]; then
                log_message "Detected control.txt in: $usb_mount"
                bind_usb_to_static "$usb_mount" "$CONTROL_BIND" "control"
            fi
        fi
    done
    
    # Clean up any orphaned mounts
    cleanup_orphaned_mounts
}

# Main monitoring function
monitor_usb() {
    log_message "Starting simple USB bind mount monitor"
    
    # Set up static mount points
    setup_static_mounts
    
    # Initial scan
    scan_and_bind_usb
    
    # Monitor /media/pi for changes
    inotifywait -m -e create,delete,moved_to,moved_from /media/pi 2>/dev/null | while read path action file; do
        log_message "USB event: $action $file"
        
        # Wait for mount to stabilize
        sleep 3
        
        # Re-scan after any change
        scan_and_bind_usb
    done
}

# Start monitoring
monitor_usb
EOL'

sudo chmod +x /usr/local/bin/usb-bind-monitor.sh

# Restart the service
sudo systemctl daemon-reload
sudo systemctl start usb-bind-monitor

echo "✅ USB monitoring restarted with simplified static mount approach"
echo "📊 Check status: sudo systemctl status usb-bind-monitor"
echo "📝 Check logs: sudo tail -f /var/log/usb-bind-mounts.log" 