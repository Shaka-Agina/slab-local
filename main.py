#!/usr/bin/env python3
# main.py

import os
import time
import threading
import glob
from config import CONTROL_FILE_NAME
from player import player
from web_interface import start_flask_app
from utils import log_message, find_album_folder, find_control_usb_with_retry, find_music_usb

def main_loop():
    """
    Monitor the control USB using native detection (Docker-optimized):
      - On a fresh mount event (transition from unmounted to mounted),
        always stop current playback and re-read the control file to start new playback.
      - On unmount, always stop playback.
      - Uses more aggressive detection for Docker containers.
    """
    previously_mounted = False
    last_control_path = None
    consecutive_failures = 0
    log_message("Starting native USB monitoring loop (Docker-optimized)...")
    
    while True:
        # Check for control USB using native detection with more retries in Docker
        control_usb = find_control_usb_with_retry(max_retries=2, retry_delay=1)
        
        if control_usb:
            # Reset failure counter on success
            consecutive_failures = 0
            
            # Check if this is a new mount (different path or first time)
            is_new_mount = not previously_mounted or (last_control_path != control_usb)
            
            if is_new_mount:
                log_message(f"Control USB {'remounted' if previously_mounted else 'mounted'} at {control_usb}")
                if previously_mounted and last_control_path != control_usb:
                    log_message(f"USB path changed from {last_control_path} to {control_usb}")
                
                previously_mounted = True
                last_control_path = control_usb
                player.stop()
                
                control_file_path = os.path.join(control_usb, CONTROL_FILE_NAME)
                
                if os.path.isfile(control_file_path):
                    try:
                        with open(control_file_path, "r") as f:
                            request_line = f.read().strip()
                        log_message(f"Control file content: '{request_line}'")
                        
                        if request_line.startswith("Album:"):
                            album_name = request_line.replace("Album:", "").strip()
                            log_message(f"Album requested: {album_name}")
                            target_folder = find_album_folder(album_name)
                            if target_folder:
                                player.play_album(target_folder)
                            else:
                                log_message(f"No matching album folder named '{album_name}' found.")
                        elif request_line.startswith("Track:"):
                            track_name = request_line.replace("Track:", "").strip()
                            log_message(f"Track requested: {track_name}")
                            
                            # Get the actual music USB mount point using native detection
                            music_usb_path = find_music_usb()
                            if music_usb_path:
                                escaped_track = glob.escape(track_name)
                                matching_tracks = glob.glob(
                                    os.path.join(music_usb_path, "**", f"{escaped_track}*"),
                                    recursive=True
                                )
                                if matching_tracks:
                                    player.play_single(matching_tracks[0])
                                else:
                                    log_message(f"No matching track named '{track_name}' found in {music_usb_path}.")
                            else:
                                log_message("No music USB drive found for track search.")
                        else:
                            log_message("Error: control.txt not in valid format. Use 'Album: <folder>' or 'Track: <filename>'.")
                    except Exception as e:
                        log_message(f"Error reading control file {control_file_path}: {str(e)}")
                else:
                    log_message(f"Control file not found: {control_file_path}")
            
            # If already mounted and same path, only log occasionally to reduce spam
            elif int(time.time()) % 30 == 0:  # Log every 30 seconds when mounted
                log_message(f"Control USB still mounted at {control_usb}")
        else:
            # No control USB found
            consecutive_failures += 1
            
            if previously_mounted:
                log_message(f"Control USB unmounted (was at {last_control_path}). Stopping playback.")
                previously_mounted = False
                last_control_path = None
                player.stop()
            # If not mounted, only log occasionally to reduce spam  
            elif int(time.time()) % 30 == 0:  # Log every 30 seconds when not mounted
                if consecutive_failures < 5:  # Don't spam if consistently failing
                    log_message("Control USB not detected")
                elif consecutive_failures == 5:
                    log_message("Control USB not detected (suppressing further messages for 30s)")
                
        # More frequent checking in Docker for better USB detection
        time.sleep(1.5)

if __name__ == "__main__":
    log_message("Starting Raspberry Pi Music Player with Native USB Detection (Docker-optimized)")
    
    # Start Flask web interface in a separate thread
    flask_thread = threading.Thread(target=start_flask_app, daemon=True)
    flask_thread.start()
    
    # Start the main loop for USB monitoring
    try:
        main_loop()
    except KeyboardInterrupt:
        log_message("Shutting down...")
    except Exception as e:
        log_message(f"Error: {str(e)}")
    finally:
        player.stop()
        log_message("Player stopped.") 