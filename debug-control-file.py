#!/usr/bin/env python3
"""
Debug script to test control file detection
Run this to see exactly what's happening with USB detection
"""

import os
import sys
import glob

# Add current directory to path so we can import our modules
sys.path.append('.')

from config import CONTROL_USB_MOUNT, CONTROL_FILE_NAME
from utils import find_control_usb, find_usb_drives_by_label_pattern, usb_is_mounted, log_message

def debug_control_file_detection():
    print("=== Control File Detection Debug ===")
    print(f"Expected control file name: {CONTROL_FILE_NAME}")
    print(f"Configured control USB mount: {CONTROL_USB_MOUNT}")
    print("")
    
    print("1. Checking bind mount paths:")
    bind_mount_path = "/home/pi/usb/playcard"
    print(f"   Bind mount path: {bind_mount_path}")
    print(f"   Path exists: {os.path.exists(bind_mount_path)}")
    
    if os.path.exists(bind_mount_path):
        try:
            contents = os.listdir(bind_mount_path)
            print(f"   Directory contents: {contents}")
            print(f"   Directory accessible: Yes")
            
            # Check for control file
            control_file_path = os.path.join(bind_mount_path, CONTROL_FILE_NAME)
            print(f"   Control file path: {control_file_path}")
            print(f"   Control file exists: {os.path.isfile(control_file_path)}")
            
            if os.path.isfile(control_file_path):
                try:
                    with open(control_file_path, 'r') as f:
                        content = f.read().strip()
                    print(f"   Control file content: '{content}'")
                except Exception as e:
                    print(f"   Error reading control file: {e}")
            
        except Exception as e:
            print(f"   Error accessing directory: {e}")
    
    print("")
    print("2. Checking original mount paths:")
    original_mounts = glob.glob("/media/pi/PLAY_CARD*")
    print(f"   Original mount paths found: {original_mounts}")
    
    for mount_path in original_mounts:
        print(f"   Checking {mount_path}:")
        print(f"     Path exists: {os.path.exists(mount_path)}")
        print(f"     Is mount point: {os.path.ismount(mount_path)}")
        
        if os.path.exists(mount_path):
            try:
                contents = os.listdir(mount_path)
                print(f"     Directory contents: {contents}")
                
                control_file_path = os.path.join(mount_path, CONTROL_FILE_NAME)
                print(f"     Control file exists: {os.path.isfile(control_file_path)}")
                
                if os.path.isfile(control_file_path):
                    try:
                        with open(control_file_path, 'r') as f:
                            content = f.read().strip()
                        print(f"     Control file content: '{content}'")
                    except Exception as e:
                        print(f"     Error reading control file: {e}")
                        
            except Exception as e:
                print(f"     Error accessing directory: {e}")
    
    print("")
    print("3. Testing utils.py functions:")
    
    # Test find_usb_drives_by_label_pattern
    print("   Testing find_usb_drives_by_label_pattern('PLAY_CARD*'):")
    playcard_drives = find_usb_drives_by_label_pattern("PLAY_CARD*")
    print(f"   Found drives: {playcard_drives}")
    
    # Test usb_is_mounted for bind mount
    print(f"   Testing usb_is_mounted('{bind_mount_path}'):")
    is_mounted = usb_is_mounted(bind_mount_path)
    print(f"   Result: {is_mounted}")
    
    # Test find_control_usb
    print("   Testing find_control_usb():")
    control_usb = find_control_usb()
    print(f"   Result: {control_usb}")
    
    print("")
    print("4. Environment variables in container:")
    print(f"   MUSIC_USB_MOUNT: {os.environ.get('MUSIC_USB_MOUNT', 'Not set')}")
    print(f"   CONTROL_USB_MOUNT: {os.environ.get('CONTROL_USB_MOUNT', 'Not set')}")
    print(f"   CONTROL_FILE_NAME: {os.environ.get('CONTROL_FILE_NAME', 'Not set')}")
    
    print("")
    print("5. All mount points:")
    try:
        with open('/proc/mounts', 'r') as f:
            mounts = f.readlines()
        
        usb_mounts = [line for line in mounts if '/home/pi/usb' in line or '/media/pi' in line]
        print("   USB-related mounts:")
        for mount in usb_mounts:
            print(f"     {mount.strip()}")
    except Exception as e:
        print(f"   Error reading mounts: {e}")

if __name__ == "__main__":
    debug_control_file_detection() 