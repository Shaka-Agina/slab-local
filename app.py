#!/usr/bin/env python3
"""
USB Music Player - Native Deployment Entry Point
Event-driven USB detection with proper permission handling
"""

import os
import sys
import signal
import time
import threading
from pathlib import Path

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from utils import log_message
from config import WEB_PORT, DEFAULT_VOLUME
from usb_monitor import USBMonitor
from player import MusicPlayer
from web_interface import create_app

class USBMusicPlayerApp:
    def __init__(self):
        self.usb_monitor = None
        self.music_player = None
        self.web_app = None
        self.web_thread = None
        self.running = False
        
    def start(self):
        """Start the USB music player application"""
        try:
            log_message("🎵 Starting USB Music Player (Native Deployment)")
            log_message("=" * 50)
            
            # Initialize music player
            self.music_player = MusicPlayer()
            
            # Initialize USB monitor with callbacks
            self.usb_monitor = USBMonitor(
                on_music_usb_change=self._on_music_usb_change,
                on_control_usb_change=self._on_control_usb_change
            )
            
            # Start USB monitoring (event-driven)
            self.usb_monitor.start_monitoring()
            
            # Create and start web interface
            self.web_app = create_app(self.music_player, self.usb_monitor)
            self.web_thread = threading.Thread(
                target=self._run_web_server,
                daemon=True
            )
            self.web_thread.start()
            
            # Set up signal handlers for graceful shutdown
            signal.signal(signal.SIGINT, self._signal_handler)
            signal.signal(signal.SIGTERM, self._signal_handler)
            
            self.running = True
            log_message(f"✅ USB Music Player started successfully")
            log_message(f"🌐 Web interface: http://localhost:{WEB_PORT}")
            log_message("🔌 Insert USB drives labeled 'MUSIC' and 'PLAY_CARD'")
            log_message("📝 Create control files on PLAY_CARD drive to control playback")
            log_message("⚡ Using event-driven USB detection (no polling!)")
            log_message("🛑 Press Ctrl+C to stop")
            
            # Main loop - just wait for signals
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            log_message("Received keyboard interrupt")
        except Exception as e:
            log_message(f"Error starting application: {e}")
            import traceback
            traceback.print_exc()
        finally:
            self.stop()
            
    def stop(self):
        """Stop the application gracefully"""
        if not self.running:
            return
            
        log_message("🛑 Stopping USB Music Player...")
        self.running = False
        
        # Stop USB monitoring
        if self.usb_monitor:
            self.usb_monitor.stop_monitoring()
            
        # Stop music player
        if self.music_player:
            self.music_player.stop()
            
        # Web server will stop when main thread exits (daemon thread)
        
        log_message("✅ USB Music Player stopped")
        
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        log_message(f"Received signal {signum}")
        self.running = False
        
    def _run_web_server(self):
        """Run the web server in a separate thread"""
        try:
            log_message(f"Starting web server on port {WEB_PORT}")
            self.web_app.run(
                host='0.0.0.0',
                port=WEB_PORT,
                debug=False,
                use_reloader=False,
                threaded=True
            )
        except Exception as e:
            log_message(f"Error running web server: {e}")
            
    def _on_music_usb_change(self, new_music_usb, old_music_usb):
        """Handle music USB mount/unmount events"""
        if new_music_usb:
            log_message(f"🎵 Music USB available: {new_music_usb}")
            if self.music_player:
                self.music_player.set_music_source(new_music_usb)
        else:
            log_message("🎵 Music USB unavailable")
            if self.music_player:
                self.music_player.stop()
                self.music_player.set_music_source(None)
                
    def _on_control_usb_change(self, new_control_usb, old_control_usb):
        """Handle control USB mount/unmount events"""
        if new_control_usb:
            log_message(f"🎛️ Control USB available: {new_control_usb}")
            if self.music_player:
                self.music_player.set_control_source(new_control_usb)
        else:
            log_message("🎛️ Control USB unavailable")
            if self.music_player:
                self.music_player.set_control_source(None)

def main():
    """Main entry point"""
    # Check if we're running as root (not recommended)
    if os.geteuid() == 0:
        log_message("⚠️  Running as root - this is not recommended for security")
        log_message("💡 Consider running as a regular user in the 'plugdev' group")
        
    # Check required groups
    try:
        import subprocess
        result = subprocess.run(['groups'], capture_output=True, text=True)
        groups = result.stdout.strip()
        
        if 'plugdev' not in groups:
            log_message("⚠️  User not in 'plugdev' group - USB access may fail")
            log_message("💡 Run: sudo usermod -aG plugdev $USER")
            log_message("💡 Then logout and login again")
            
        if 'audio' not in groups:
            log_message("⚠️  User not in 'audio' group - audio may not work")
            log_message("💡 Run: sudo usermod -aG audio $USER")
            log_message("💡 Then logout and login again")
            
    except Exception as e:
        log_message(f"Could not check user groups: {e}")
    
    # Create and start the application
    app = USBMusicPlayerApp()
    app.start()

if __name__ == "__main__":
    main() 