#!/usr/bin/env python3
"""
Test USB reconnection scenarios
Run this to monitor control file detection during USB disconnect/reconnect
"""

import os
import sys
import time
import signal

# Add current directory to path so we can import our modules
sys.path.append('.')

from utils import find_control_usb, log_message

def signal_handler(sig, frame):
    print('\n\nExiting...')
    sys.exit(0)

def monitor_control_file():
    print("=== USB Reconnection Monitor ===")
    print("This script will continuously monitor control file detection.")
    print("Disconnect and reconnect your PLAY_CARD USB drive to test.")
    print("Press Ctrl+C to exit.")
    print("")
    
    signal.signal(signal.SIGINT, signal_handler)
    
    last_result = None
    count = 0
    
    while True:
        count += 1
        print(f"\n--- Check #{count} at {time.strftime('%H:%M:%S')} ---")
        
        # Test control file detection
        try:
            control_usb = find_control_usb()
            
            if control_usb != last_result:
                if control_usb:
                    print(f"✅ CHANGE DETECTED: Control USB now found at: {control_usb}")
                else:
                    print(f"❌ CHANGE DETECTED: Control USB no longer found")
                last_result = control_usb
            else:
                if control_usb:
                    print(f"✅ Control USB still found at: {control_usb}")
                else:
                    print(f"❌ Control USB still not found")
            
            # Additional checks if USB is found
            if control_usb:
                # Check if control file exists and is readable
                control_file_path = os.path.join(control_usb, "playMusic.txt")
                if os.path.isfile(control_file_path):
                    try:
                        with open(control_file_path, 'r') as f:
                            content = f.read().strip()
                        print(f"   📄 Control file content: '{content}'")
                    except Exception as e:
                        print(f"   ❌ Error reading control file: {e}")
                else:
                    print(f"   ❌ Control file does not exist at: {control_file_path}")
                
                # Check directory contents
                try:
                    contents = os.listdir(control_usb)
                    print(f"   📁 Directory contents: {contents}")
                except Exception as e:
                    print(f"   ❌ Error listing directory: {e}")
        
        except Exception as e:
            print(f"❌ ERROR during detection: {e}")
        
        # Wait before next check
        time.sleep(3)

if __name__ == "__main__":
    monitor_control_file() 