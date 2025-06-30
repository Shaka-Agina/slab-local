#!/usr/bin/env python3
"""
Main entry point for the USB Music Player
Updated for event-driven architecture with proper separation of concerns
"""

import os
import sys
import signal
import threading
import time
from config import WEB_PORT
from utils import log_message
from music_player import MusicPlayer
from usb_monitor import USBMonitor
from web_interface import create_app

# Global references for cleanup
music_player = None
usb_monitor = None
web_app = None

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    log_message("Received shutdown signal. Cleaning up...")
    
    global music_player, usb_monitor
    
    # Stop USB monitoring
    if usb_monitor:
        usb_monitor.stop_monitoring()
        log_message("USB monitoring stopped")
    
    # Stop music player
    if music_player:
        music_player.stop_playback()
        log_message("Music player stopped")
    
    log_message("Shutdown complete")
    sys.exit(0)

def main():
    """Main application entry point"""
    global music_player, usb_monitor, web_app
    
    log_message("Starting USB Music Player with event-driven architecture")
    
    # Set up signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        # Create music player instance
        music_player = MusicPlayer()
        log_message("Music player initialized")
        
        # Define USB event handlers
        def on_music_usb_change(new_path, old_path):
            """Handle music USB changes"""
            if new_path:
                log_message(f"Music USB connected: {new_path}")
                music_player.set_music_source(new_path)
            else:
                log_message("Music USB disconnected")
                music_player.set_music_source(None)
        
        def on_control_usb_change(new_path, old_path):
            """Handle control USB changes"""
            if new_path:
                log_message(f"Control USB connected: {new_path}")
                music_player.set_control_source(new_path)
            else:
                log_message("Control USB disconnected")
                music_player.set_control_source(None)
        
        # Create and start USB monitor
        usb_monitor = USBMonitor(
            on_music_usb_change=on_music_usb_change,
            on_control_usb_change=on_control_usb_change
        )
        
        log_message("Starting USB monitoring...")
        usb_monitor.start_monitoring()
        
        # Create Flask app with dependency injection
        web_app = create_app(music_player, usb_monitor)
        
        # Start web interface
        log_message(f"Starting web interface on port {WEB_PORT}")
        log_message(f"Web interface available at: http://localhost:{WEB_PORT}")
        
        # Run the Flask app
        web_app.run(
            host='0.0.0.0',
            port=WEB_PORT,
            debug=False,
            threaded=True,
            use_reloader=False  # Disable reloader to avoid double startup
        )
        
    except KeyboardInterrupt:
        log_message("Received keyboard interrupt")
        signal_handler(signal.SIGINT, None)
    except Exception as e:
        log_message(f"Fatal error: {str(e)}")
        import traceback
        log_message(f"Traceback: {traceback.format_exc()}")
        signal_handler(signal.SIGTERM, None)

if __name__ == "__main__":
    main() 