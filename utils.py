#!/usr/bin/env python3
# utils.py

import os
import time
import glob
from urllib.parse import unquote
from config import MUSIC_USB_MOUNT, CONTROL_USB_MOUNT

# Global log variable
log_messages = []

def log_message(msg):
    """Log a message with a timestamp."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] {msg}"
    log_messages.append(message)
    print(message)

def usb_is_mounted(mount_path):
    """Return True if mount_path is mounted, else False."""
    if not os.path.ismount(mount_path):
        return False
    try:
        os.listdir(mount_path)
        return True
    except OSError:
        return False

def find_control_usb():
    """Find mounted USB device for control files."""
    if usb_is_mounted(CONTROL_USB_MOUNT):
        return CONTROL_USB_MOUNT
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