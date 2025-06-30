#!/usr/bin/env python3
"""
USB Music Player - Native Deployment Entry Point
Main application that starts both the web interface and USB monitoring
"""

import os
import sys
import time
import threading
import glob
import signal
from pathlib import Path

# Add current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import CONTROL_FILE_NAME
from player import player
from web_interface import start_flask_app
from utils import log_message, find_album_folder, find_control_usb_with_retry, find_music_usb

class MusicPlayerApp:
    def __init__(self):
        self.running = True
        self.previously_mounted = False
        self.last_control_path = None
        
    def signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        log_message(f"Received signal {signum}, shutting down...")
        self.running = False
        player.stop()
        sys.exit(0)
        
    def monitor_usb_loop(self):
        """
        Monitor USB drives for control files and music playback
        Optimized for native deployment with proper permissions
        """
        consecutive_failures = 0
        log_message("Starting native USB monitoring loop...")
        
        while self.running:
            try:
                # Check for control USB - native detection is more reliable
                control_usb = find_control_usb_with_retry(max_retries=1, retry_delay=0.5)
                
                if control_usb:
                    # Reset failure counter on success
                    consecutive_failures = 0
                    
                    # Check if this is a new mount
                    is_new_mount = not self.previously_mounted or (self.last_control_path != control_usb)
                    
                    if is_new_mount:
                        log_message(f"Control USB {'remounted' if self.previously_mounted else 'mounted'} at {control_usb}")
                        if self.previously_mounted and self.last_control_path != control_usb:
                            log_message(f"USB path changed from {self.last_control_path} to {control_usb}")
                        
                        self.previously_mounted = True
                        self.last_control_path = control_usb
                        player.stop()
                        
                        self.process_control_file(control_usb)
                    
                    # Periodic status check (less frequent logging)
                    elif int(time.time()) % 60 == 0:  # Every minute when mounted
                        log_message(f"Control USB active at {control_usb}")
                        
                else:
                    # No control USB found
                    consecutive_failures += 1
                    
                    if self.previously_mounted:
                        log_message(f"Control USB unmounted (was at {self.last_control_path}). Stopping playback.")
                        self.previously_mounted = False
                        self.last_control_path = None
                        player.stop()
                    elif int(time.time()) % 60 == 0:  # Log every minute when not mounted
                        if consecutive_failures < 3:
                            log_message("Control USB not detected")
                        elif consecutive_failures == 3:
                            log_message("Control USB not detected (reducing log frequency)")
                            
            except Exception as e:
                log_message(f"Error in USB monitoring loop: {str(e)}")
                
            # Native deployment can use longer intervals for better performance
            time.sleep(2.0)
            
    def process_control_file(self, control_usb):
        """Process the control file and start appropriate playback"""
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
                    # For simple control files, just start playing
                    log_message("Simple control file detected - starting music playback")
                    music_usb_path = find_music_usb()
                    if music_usb_path:
                        # Find first album or just play all music
                        music_path = Path(music_usb_path)
                        album_dirs = [d for d in music_path.iterdir() if d.is_dir()]
                        if album_dirs:
                            player.play_album(str(album_dirs[0]))
                        else:
                            # Play all music files in the root
                            music_files = []
                            for ext in ['*.mp3', '*.wav', '*.flac', '*.m4a']:
                                music_files.extend(music_path.glob(ext))
                            if music_files:
                                player.play_single(str(music_files[0]))
                            else:
                                log_message("No music files found on USB drive")
                    else:
                        log_message("No music USB drive found")
                        
            except Exception as e:
                log_message(f"Error reading control file {control_file_path}: {str(e)}")
        else:
            log_message(f"Control file not found: {control_file_path}")
            # Still try to play music if control USB is inserted
            music_usb_path = find_music_usb()
            if music_usb_path:
                log_message("No control file, but music USB detected - starting playback")
                music_path = Path(music_usb_path)
                album_dirs = [d for d in music_path.iterdir() if d.is_dir()]
                if album_dirs:
                    player.play_album(str(album_dirs[0]))

    def run(self):
        """Main application entry point"""
        # Set up signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
        
        log_message("Starting USB Music Player (Native Deployment)")
        log_message(f"Working directory: {os.getcwd()}")
        log_message(f"Python path: {sys.executable}")
        
        # Start Flask web interface in a separate thread
        log_message("Starting web interface...")
        flask_thread = threading.Thread(target=start_flask_app, daemon=True)
        flask_thread.start()
        
        # Give Flask a moment to start
        time.sleep(2)
        log_message("Web interface started")
        
        # Start the main USB monitoring loop
        try:
            self.monitor_usb_loop()
        except KeyboardInterrupt:
            log_message("Keyboard interrupt received")
        except Exception as e:
            log_message(f"Application error: {str(e)}")
        finally:
            log_message("Shutting down...")
            player.stop()
            log_message("Application stopped")

def main():
    """Entry point for the application"""
    app = MusicPlayerApp()
    app.run()

if __name__ == "__main__":
    main() 