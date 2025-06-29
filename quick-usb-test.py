#!/usr/bin/env python3
"""
Quick USB Control File Test
Run this to quickly test control file detection
"""

import os
import sys
sys.path.append('.')

from config import CONTROL_USB_MOUNT, CONTROL_FILE_NAME
from utils import find_control_usb

def test_control_file():
    print("=== Quick USB Control File Test ===")
    print(f"Looking for control file: {CONTROL_FILE_NAME}")
    print(f"Configured mount: {CONTROL_USB_MOUNT}")
    print("")
    
    # Test the function
    result = find_control_usb()
    
    if result:
        print(f"✅ SUCCESS: Control USB found at: {result}")
        
        # Test reading the control file
        control_file_path = os.path.join(result, CONTROL_FILE_NAME)
        try:
            with open(control_file_path, 'r') as f:
                content = f.read().strip()
            print(f"✅ Control file content: '{content}'")
        except Exception as e:
            print(f"❌ Error reading control file: {e}")
            
        # Show directory contents
        try:
            contents = os.listdir(result)
            print(f"📁 Directory contents: {contents}")
        except Exception as e:
            print(f"❌ Error listing directory: {e}")
    else:
        print("❌ FAILED: No control USB found")
        
        # Debug info
        print("\n🔍 Debug info:")
        
        # Check bind mount path
        bind_path = "/home/pi/usb/playcard"
        print(f"Bind mount path exists: {os.path.exists(bind_path)}")
        if os.path.exists(bind_path):
            try:
                contents = os.listdir(bind_path)
                print(f"Bind mount contents: {contents}")
            except Exception as e:
                print(f"Bind mount error: {e}")
        
        # Check configured path
        print(f"Configured path exists: {os.path.exists(CONTROL_USB_MOUNT)}")
        if os.path.exists(CONTROL_USB_MOUNT):
            try:
                contents = os.listdir(CONTROL_USB_MOUNT)
                print(f"Configured path contents: {contents}")
            except Exception as e:
                print(f"Configured path error: {e}")

if __name__ == "__main__":
    test_control_file() 