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
    Monitor the control USB using native detection:
      - On a fresh mount event (transition from unmounted to mounted),
        always stop current playback and re-read the control file to start new playback.
      - On unmount, always stop playback.
    """
    previously_mounted = False
    log_message("Starting native USB monitoring loop...")
    
    while True:
        # Check for control USB using native detection
        control_usb = find_control_usb_with_retry(max_retries=1, retry_delay=0.5)  # Quick check
        
        if control_usb:
            control_file_path = os.path.join(control_usb, CONTROL_FILE_NAME)
            
            if not previously_mounted:
                log_message(f"Control USB mounted at {control_usb}. Restarting playback from control file.")
                previously_mounted = True
                player.stop()
                
                if os.path.isfile(control_file_path):
                    with open(control_file_path, "r") as f:
                        request_line = f.read().strip()
                    log_message(f"Requested line: {request_line}")
                    
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
                else:
                    log_message(f"Control file not found: {control_file_path}")
            
            # If already mounted, only log occasionally to reduce spam
            elif int(time.time()) % 30 == 0:  # Log every 30 seconds when mounted
                log_message(f"Control USB still mounted at {control_usb}")
        else:
            if previously_mounted:
                log_message("Control USB unmounted. Stopping playback.")
                previously_mounted = False
                player.stop()
            # If not mounted, only log occasionally to reduce spam  
            elif int(time.time()) % 30 == 0:  # Log every 30 seconds when not mounted
                log_message("Control USB not detected")
                
        time.sleep(2)

if __name__ == "__main__":
    log_message("Starting Raspberry Pi Music Player with Native USB Detection")
    
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