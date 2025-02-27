#!/usr/bin/env python3
# main.py

import os
import time
import threading
import glob
from config import CONTROL_USB_MOUNT, CONTROL_FILE_NAME, MUSIC_USB_MOUNT
from player import player
from web_interface import start_flask_app
from utils import log_message, usb_is_mounted, find_album_folder

def main_loop():
    """
    Monitor the control USB:
      - On a fresh mount event (transition from unmounted to mounted),
        always stop current playback and re-read the control file to start new playback.
      - On unmount, always stop playback.
    """
    previously_mounted = False
    while True:
        if usb_is_mounted(CONTROL_USB_MOUNT):
            if not previously_mounted:
                log_message("Control USB mounted. Restarting playback from control file.")
                previously_mounted = True
                player.stop()
                control_file_path = os.path.join(CONTROL_USB_MOUNT, CONTROL_FILE_NAME)
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
                        escaped_track = glob.escape(track_name)
                        matching_tracks = glob.glob(
                            os.path.join(MUSIC_USB_MOUNT, "**", f"{escaped_track}*"),
                            recursive=True
                        )
                        if matching_tracks:
                            player.play_single(matching_tracks[0])
                        else:
                            log_message(f"No matching track named '{track_name}' found in {MUSIC_USB_MOUNT}.")
                    else:
                        log_message("Error: playMusic.txt not in valid format. Use 'Album: <folder>' or 'Track: <filename>'.")
                else:
                    log_message(f"{CONTROL_FILE_NAME} not found on Control USB.")
        else:
            if previously_mounted:
                log_message("Control USB unmounted. Stopping playback.")
                previously_mounted = False
                player.stop()
        time.sleep(2)

if __name__ == "__main__":
    log_message("Starting Raspberry Pi Music Player")
    
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