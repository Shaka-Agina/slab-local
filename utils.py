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

def find_music_usb():
    """Find the music USB using static bind mount point."""
    # First check the static bind mount point
    static_path = "/home/pi/usb/music"
    
    if os.path.exists(static_path):
        try:
            # Check if it has content (meaning a USB is bound to it)
            contents = os.listdir(static_path)
            if contents:  # Has files/folders
                log_message(f"Music USB found at static mount: {static_path} ({len(contents)} items)")
                return static_path
            else:
                log_message(f"Static mount point exists but empty: {static_path}")
        except (OSError, PermissionError) as e:
            log_message(f"Cannot access static mount point: {static_path} - {str(e)}")
    
    # Fallback: Look for traditional mount points
    for mount_point in glob.glob("/media/pi/MUSIC*"):
        if os.path.isdir(mount_point) and os.path.ismount(mount_point):
            try:
                contents = os.listdir(mount_point)
                if contents:
                    log_message(f"Music USB found at traditional mount: {mount_point}")
                    return mount_point
            except (OSError, PermissionError):
                continue
    
    log_message("No music USB found")
    return None

def usb_is_mounted(mount_path):
    """Return True if mount_path has content, else False."""
    try:
        if not os.path.exists(mount_path):
            return False
        
        # Check if we can list the directory and it has content
        contents = os.listdir(mount_path)
        has_content = len(contents) > 0
        
        if has_content:
            log_message(f"USB mounted and accessible: {mount_path} ({len(contents)} items)")
        else:
            log_message(f"Mount point exists but empty: {mount_path}")
        
        return has_content
        
    except (OSError, PermissionError) as e:
        log_message(f"Mount point not accessible: {mount_path} - {str(e)}")
        return False

def find_control_usb():
    """Find control USB using static bind mount point."""
    # First check the static bind mount point
    static_path = "/home/pi/usb/playcard"
    
    if os.path.exists(static_path):
        try:
            # Check if it has content (meaning a USB is bound to it)
            contents = os.listdir(static_path)
            if contents:  # Has files/folders
                # Additional check: verify the control file exists
                control_file_path = os.path.join(static_path, CONTROL_FILE_NAME)
                if os.path.isfile(control_file_path):
                    log_message(f"Control USB found at static mount with control file: {static_path}")
                    return static_path
                else:
                    log_message(f"Static mount has content but no control file: {static_path}")
            else:
                log_message(f"Static control mount point exists but empty: {static_path}")
        except (OSError, PermissionError) as e:
            log_message(f"Cannot access static control mount: {static_path} - {str(e)}")
    
    # Fallback: Check the configured path (backward compatibility)
    if usb_is_mounted(CONTROL_USB_MOUNT):
        control_file_path = os.path.join(CONTROL_USB_MOUNT, CONTROL_FILE_NAME)
        if os.path.isfile(control_file_path):
            log_message(f"Control USB found at configured path: {CONTROL_USB_MOUNT}")
            return CONTROL_USB_MOUNT
    
    # Fallback: Look for traditional PLAY_CARD mount points
    for mount_point in glob.glob("/media/pi/PLAY_CARD*"):
        if os.path.isdir(mount_point) and os.path.ismount(mount_point):
            control_file_path = os.path.join(mount_point, CONTROL_FILE_NAME)
            if os.path.isfile(control_file_path):
                log_message(f"Control USB found at traditional mount: {mount_point}")
                return mount_point
    
    # Last resort: Look for ANY USB with control.txt
    for mount_point in glob.glob("/media/pi/*"):
        if os.path.isdir(mount_point) and os.path.ismount(mount_point):
            control_file_path = os.path.join(mount_point, CONTROL_FILE_NAME)
            if os.path.isfile(control_file_path):
                log_message(f"Control file found on unlabeled USB: {mount_point}")
                return mount_point
    
    log_message("No control USB found")
    return None

def find_control_usb_with_retry(max_retries=3, retry_delay=1):
    """Find control USB with simple retry for static mounts."""
    for attempt in range(max_retries):
        if attempt > 0:
            log_message(f"Retrying control USB detection (attempt {attempt + 1}/{max_retries})...")
            time.sleep(retry_delay)
        
        result = find_control_usb()
        if result:
            return result
    
    log_message(f"Failed to find control USB after {max_retries} attempts")
    return None

def format_track_name(filename):
    """Decode URL-encoded filename and return its basename without extension."""
    decoded = unquote(filename)
    base = os.path.basename(decoded)
    base_without_ext, _ = os.path.splitext(base)
    return base_without_ext

def find_album_folder(album_name):
    """Recursively search for a folder whose name starts with album_name in the music USB."""
    # Get the actual music USB mount point
    music_usb_path = find_music_usb()
    
    if not music_usb_path:
        log_message("No music USB drive found")
        return None
        
    log_message(f"Searching for album '{album_name}' in {music_usb_path}")
    escaped_album = f"{glob.escape(album_name)}*"
    pattern = os.path.join(music_usb_path, "**", escaped_album)
    matching_dirs = glob.glob(pattern, recursive=True)
    for d in matching_dirs:
        if os.path.isdir(d):
            log_message(f"Found album folder: {d}")
            return d
    
    log_message(f"No album folder found matching '{album_name}'")
    return None 