#!/usr/bin/env python3
"""
Complete System Test for USB Music Player
Event-driven architecture with VLC and udev monitoring

Tests all components in integration to ensure they work together properly.
"""

import sys
import time
import threading
import tempfile
import os
import json
from pathlib import Path

# Import our components
try:
    from usb_monitor import USBMonitor
    from music_player import MusicPlayer
    from web_interface import create_app
    import requests
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("💡 Make sure all dependencies are installed: pip3 install -r requirements.txt")
    sys.exit(1)

class SystemTester:
    def __init__(self):
        self.results = []
        self.web_app = None
        self.web_thread = None
        
    def log_result(self, test_name, success, message=""):
        """Log a test result"""
        status = "✅" if success else "❌"
        self.results.append({
            'test': test_name,
            'success': success,
            'message': message
        })
        print(f"{status} {test_name}: {message}")
        
    def test_imports(self):
        """Test that all required modules can be imported"""
        try:
            import vlc
            self.log_result("VLC Python bindings", True, "VLC module imported successfully")
        except ImportError:
            self.log_result("VLC Python bindings", False, "python-vlc not available")
            
        try:
            import flask
            self.log_result("Flask import", True, "Flask available")
        except ImportError:
            self.log_result("Flask import", False, "Flask not available")
            
        try:
            import watchdog
            self.log_result("Watchdog import", True, "File monitoring available")
        except ImportError:
            self.log_result("Watchdog import", False, "Watchdog not available")
            
    def test_usb_monitor(self):
        """Test USB monitoring functionality"""
        try:
            monitor = USBMonitor()
            
            # Test initialization
            self.log_result("USB Monitor init", True, "USBMonitor created successfully")
            
            # Test scanning (should work even without USB drives)
            monitor.scan_usb_drives()
            self.log_result("USB scan", True, f"Found {len(monitor.music_drives)} music drives, {len(monitor.control_drives)} control drives")
            
            # Test udev availability
            import subprocess
            try:
                result = subprocess.run(['udevadm', '--version'], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    self.log_result("udev availability", True, f"udevadm version: {result.stdout.strip()}")
                else:
                    self.log_result("udev availability", False, "udevadm command failed")
            except Exception as e:
                self.log_result("udev availability", False, f"udevadm not available: {e}")
                
        except Exception as e:
            self.log_result("USB Monitor test", False, f"Error: {e}")
            
    def test_music_player(self):
        """Test music player functionality"""
        try:
            player = MusicPlayer()
            
            # Test initialization
            self.log_result("Music Player init", True, "MusicPlayer created successfully")
            
            # Test state
            state = player.get_state()
            self.log_result("Player state", True, f"State: {state['status']}")
            
            # Test VLC instance
            if hasattr(player, 'vlc_instance'):
                self.log_result("VLC instance", True, "VLC instance created")
            else:
                self.log_result("VLC instance", False, "VLC instance not found")
                
        except Exception as e:
            self.log_result("Music Player test", False, f"Error: {e}")
            
    def test_web_interface(self):
        """Test web interface"""
        try:
            app = create_app()
            self.log_result("Web app creation", True, "Flask app created successfully")
            
            # Test that we can create a test client
            with app.test_client() as client:
                # Test health endpoint
                response = client.get('/health')
                if response.status_code == 200:
                    self.log_result("Health endpoint", True, "Health check passed")
                else:
                    self.log_result("Health endpoint", False, f"Status: {response.status_code}")
                    
                # Test API endpoint
                response = client.get('/api/player_state')
                if response.status_code == 200:
                    data = response.get_json()
                    self.log_result("API endpoint", True, f"Player status: {data.get('status', 'unknown')}")
                else:
                    self.log_result("API endpoint", False, f"Status: {response.status_code}")
                    
        except Exception as e:
            self.log_result("Web interface test", False, f"Error: {e}")
            
    def test_file_monitoring(self):
        """Test file monitoring functionality"""
        try:
            from watchdog.observers import Observer
            from watchdog.events import FileSystemEventHandler
            
            # Create a temporary directory and file
            with tempfile.TemporaryDirectory() as temp_dir:
                test_file = Path(temp_dir) / "test_control.txt"
                
                # Create test file
                test_file.write_text("test")
                
                observer = Observer()
                
                class TestHandler(FileSystemEventHandler):
                    def __init__(self):
                        self.events = []
                        
                    def on_modified(self, event):
                        if not event.is_directory:
                            self.events.append(event)
                
                handler = TestHandler()
                observer.schedule(handler, temp_dir, recursive=False)
                observer.start()
                
                # Wait a moment for observer to start
                time.sleep(0.1)
                
                # Modify the file
                test_file.write_text("modified")
                
                # Wait for event
                time.sleep(0.2)
                
                observer.stop()
                observer.join()
                
                if handler.events:
                    self.log_result("File monitoring", True, f"Detected {len(handler.events)} file events")
                else:
                    self.log_result("File monitoring", False, "No file events detected")
                    
        except Exception as e:
            self.log_result("File monitoring test", False, f"Error: {e}")
            
    def test_integration(self):
        """Test integration between components"""
        try:
            # Create components
            monitor = USBMonitor()
            player = MusicPlayer()
            
            # Test that they can work together
            monitor.scan_usb_drives()
            state = player.get_state()
            
            self.log_result("Component integration", True, 
                          f"Monitor found {len(monitor.music_drives)} drives, player status: {state['status']}")
            
        except Exception as e:
            self.log_result("Integration test", False, f"Error: {e}")
            
    def test_system_requirements(self):
        """Test system requirements"""
        import subprocess
        import sys
        
        # Test Python version
        if sys.version_info >= (3, 7):
            self.log_result("Python version", True, f"Python {sys.version.split()[0]}")
        else:
            self.log_result("Python version", False, f"Python {sys.version.split()[0]} (need 3.7+)")
            
        # Test udev
        try:
            result = subprocess.run(['which', 'udevadm'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                self.log_result("udev tools", True, "udevadm available")
            else:
                self.log_result("udev tools", False, "udevadm not found")
        except Exception as e:
            self.log_result("udev tools", False, f"Error checking udevadm: {e}")
            
        # Test VLC
        try:
            result = subprocess.run(['vlc', '--version'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                version = result.stdout.split('\n')[0]
                self.log_result("VLC media player", True, version)
            else:
                self.log_result("VLC media player", False, "VLC not found or failed")
        except Exception as e:
            self.log_result("VLC media player", False, f"Error checking VLC: {e}")
            
        # Test user groups
        try:
            import grp
            import os
            
            user_groups = [g.gr_name for g in grp.getgrall() if os.getenv('USER', 'pi') in g.gr_mem]
            
            if 'plugdev' in user_groups:
                self.log_result("plugdev group", True, "User in plugdev group")
            else:
                self.log_result("plugdev group", False, "User NOT in plugdev group")
                
            if 'audio' in user_groups:
                self.log_result("audio group", True, "User in audio group")
            else:
                self.log_result("audio group", False, "User NOT in audio group")
                
        except Exception as e:
            self.log_result("User groups", False, f"Error checking groups: {e}")
            
    def run_all_tests(self):
        """Run all tests"""
        print("🧪 USB Music Player - Complete System Test")
        print("==========================================")
        print("")
        
        print("📋 Testing system requirements...")
        self.test_system_requirements()
        print("")
        
        print("📦 Testing imports...")
        self.test_imports()
        print("")
        
        print("🔌 Testing USB monitor...")
        self.test_usb_monitor()
        print("")
        
        print("🎵 Testing music player...")
        self.test_music_player()
        print("")
        
        print("🌐 Testing web interface...")
        self.test_web_interface()
        print("")
        
        print("📁 Testing file monitoring...")
        self.test_file_monitoring()
        print("")
        
        print("🔗 Testing integration...")
        self.test_integration()
        print("")
        
        # Summary
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r['success'])
        failed_tests = total_tests - passed_tests
        
        print("📊 Test Summary")
        print("===============")
        print(f"Total tests: {total_tests}")
        print(f"✅ Passed: {passed_tests}")
        print(f"❌ Failed: {failed_tests}")
        print(f"Success rate: {(passed_tests/total_tests)*100:.1f}%")
        
        if failed_tests == 0:
            print("")
            print("🎉 All tests passed! System is ready to use.")
            print("")
            print("🚀 Next steps:")
            print("   1. Insert your MUSIC and PLAY_CARD USB drives")
            print("   2. Run: python3 main.py")
            print("   3. Access web interface at http://localhost:5000")
        else:
            print("")
            print("⚠️  Some tests failed. Please check the issues above.")
            print("")
            print("💡 Common fixes:")
            print("   • Install missing packages: pip3 install -r requirements.txt")
            print("   • Add user to groups: sudo usermod -aG plugdev,audio $USER")
            print("   • Install VLC: sudo apt install vlc python3-vlc")
            print("   • Logout and login again for group changes")
        
        return failed_tests == 0

def main():
    """Main test function"""
    tester = SystemTester()
    success = tester.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main() 