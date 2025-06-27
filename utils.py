#!/usr/bin/env python3
# utils.py

import os
import time
import glob
import subprocess
from urllib.parse import unquote
from config import MUSIC_USB_MOUNT, CONTROL_USB_MOUNT, CONTROL_FILE_NAME

# Global log variable
log_messages = []

def log_message(msg):
    """Log a message with a timestamp."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] {msg}"
    log_messages.append(message)
    print(message)

def usb_is_mounted(mount_path):
    """Return True if mount_path is accessible and has content, else False."""
    try:
        # First check if the path exists
        if not os.path.exists(mount_path):
            return False
        
        # Check if we can list the directory contents
        # This works better in Docker than os.path.ismount()
        contents = os.listdir(mount_path)
        
        # For USB drives, we expect at least some content or ability to write
        # An empty directory might indicate the USB is not mounted
        # But we'll be more permissive and just check if the path is accessible
        log_message(f"Mount check for {mount_path}: accessible with {len(contents)} items")
        return True
        
    except (OSError, PermissionError) as e:
        log_message(f"Mount check for {mount_path}: not accessible - {str(e)}")
        return False

def find_control_usb():
    """Find mounted USB device for control files."""
    log_message(f"Checking for control USB at {CONTROL_USB_MOUNT}")
    
    if usb_is_mounted(CONTROL_USB_MOUNT):
        # Additional check: verify the control file exists
        control_file_path = os.path.join(CONTROL_USB_MOUNT, CONTROL_FILE_NAME)
        if os.path.isfile(control_file_path):
            log_message(f"Control USB found at {CONTROL_USB_MOUNT} with control file")
            return CONTROL_USB_MOUNT
        else:
            log_message(f"Control USB directory exists at {CONTROL_USB_MOUNT} but no control file found")
            return None
    
    log_message(f"Control USB not found at {CONTROL_USB_MOUNT}")
    return None

def format_track_name(filename):
    """Decode URL-encoded filename and return its basename without extension."""
    decoded = unquote(filename)
    base = os.path.basename(decoded)
    base_without_ext, _ = os.path.splitext(base)
    return base_without_ext

def find_album_folder(album_name):
    """Recursively search MUSIC_USB_MOUNT for a folder whose name starts with album_name."""
    # Check if MUSIC_USB_MOUNT exists first
    if not usb_is_mounted(MUSIC_USB_MOUNT):
        log_message(f"Music USB not mounted at {MUSIC_USB_MOUNT}")
        return None
        
    escaped_album = f"{glob.escape(album_name)}*"
    pattern = os.path.join(MUSIC_USB_MOUNT, "**", escaped_album)
    matching_dirs = glob.glob(pattern, recursive=True)
    for d in matching_dirs:
        if os.path.isdir(d):
            return d
    return None 