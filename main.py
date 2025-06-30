#!/usr/bin/env python3
# main.py

import os
import time
import threading
import glob
from config import CONTROL_FILE_NAME, MUSIC_USB_MOUNT
from player import player
from web_interface import start_flask_app
from utils import log_message, find_album_folder, find_control_usb_with_retry, usb_is_mounted
from audio_player import AudioPlayer

class PlaycardController:
    def __init__(self):
        self.player = AudioPlayer()
        self.control_file_path = None
        self.last_control_content = None

    def check_for_control_usb(self):
        """Check if control USB is available and update control file path."""
        control_usb = find_control_usb_with_retry()
        if control_usb:
            potential_path = os.path.join(control_usb, CONTROL_FILE_NAME)
            if os.path.isfile(potential_path):
                if self.control_file_path != potential_path:
                    log_message(f"Control file detected: {potential_path}")
                    self.control_file_path = potential_path
                return True
        
        if self.control_file_path:
            log_message("Control USB disconnected")
            self.control_file_path = None
        return False

def main_loop():
    """
    Monitor the control USB:
      - On a fresh mount event (transition from unmounted to mounted),
        always stop current playback and re-read the control file to start new playback.
      - On unmount, always stop playback.
    """
    previously_mounted = False
    log_message("Starting USB monitoring loop...")
    
    controller = PlaycardController()
    
    while True:
        if controller.check_for_control_usb():
            control_file_path = controller.control_file_path
            if not previously_mounted:
                log_message(f"Control USB mounted at {control_file_path}. Restarting playback from control file.")
                previously_mounted = True
                player.stop()
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
                    
                    # Get the actual music USB mount point dynamically
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
                    log_message("Error: playMusic.txt not in valid format. Use 'Album: <folder>' or 'Track: <filename>'.")
            # If already mounted, only log occasionally to reduce spam
            elif int(time.time()) % 30 == 0:  # Log every 30 seconds when mounted
                log_message(f"Control USB still mounted at {control_file_path}")
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