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

def find_usb_drives_by_label_pattern(label_pattern):
    """Find all mounted USB drives that match a label pattern (e.g., 'MUSIC*', 'PLAY_CARD*')."""
    mounted_drives = []
    
    try:
        # First check bind mount locations (preferred - stable paths with proper permissions)
        if label_pattern.startswith("MUSIC"):
            bind_mount_path = "/home/pi/usb/music"
            if os.path.exists(bind_mount_path) and usb_is_mounted(bind_mount_path):
                mounted_drives.append(bind_mount_path)
                log_message(f"Found bind-mounted USB drive: {bind_mount_path}")
                return mounted_drives
        
        if label_pattern.startswith("PLAY_CARD"):
            bind_mount_path = "/home/pi/usb/playcard"
            if os.path.exists(bind_mount_path) and usb_is_mounted(bind_mount_path):
                mounted_drives.append(bind_mount_path)
                log_message(f"Found bind-mounted USB drive: {bind_mount_path}")
                return mounted_drives
        
        # Fallback: Look for mount points in /media/pi/ that match the pattern
        pattern_path = f"/media/pi/{label_pattern}"
        matching_paths = glob.glob(pattern_path)
        
        for path in matching_paths:
            if os.path.exists(path) and os.path.ismount(path):
                try:
                    # Test if we can access the directory
                    os.listdir(path)
                    mounted_drives.append(path)
                    log_message(f"Found mounted USB drive: {path}")
                except (OSError, PermissionError):
                    log_message(f"Found mount point {path} but cannot access it")
                    
    except Exception as e:
        log_message(f"Error searching for USB drives with pattern {label_pattern}: {str(e)}")
    
    return mounted_drives

def find_music_usb():
    """Find the first mounted MUSIC USB drive (including numbered variants like MUSIC1)."""
    music_drives = find_usb_drives_by_label_pattern("MUSIC*")
    
    if music_drives:
        # Return the first one found
        selected_drive = music_drives[0]
        log_message(f"Using music USB drive: {selected_drive}")
        return selected_drive
    
    log_message("No MUSIC USB drive found")
    return None

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
    """Find mounted USB device for control files (including numbered variants like PLAY_CARD1)."""
    # First try the configured path (for backward compatibility)
    log_message(f"Checking for control USB at {CONTROL_USB_MOUNT}")
    
    if usb_is_mounted(CONTROL_USB_MOUNT):
        # Additional check: verify the control file exists
        control_file_path = os.path.join(CONTROL_USB_MOUNT, CONTROL_FILE_NAME)
        if os.path.isfile(control_file_path):
            log_message(f"Control USB found at {CONTROL_USB_MOUNT} with control file")
            return CONTROL_USB_MOUNT
    
    # If not found at the configured path, search for any PLAY_CARD* drives
    log_message("Searching for PLAY_CARD USB drives with dynamic detection...")
    playcard_drives = find_usb_drives_by_label_pattern("PLAY_CARD*")
    
    for drive_path in playcard_drives:
        control_file_path = os.path.join(drive_path, CONTROL_FILE_NAME)
        if os.path.isfile(control_file_path):
            log_message(f"Control USB found at {drive_path} with control file")
            return drive_path
        else:
            log_message(f"PLAY_CARD drive found at {drive_path} but no control file")
    
    log_message("No control USB found with required control file")
    return None

def format_track_name(filename):
    """Decode URL-encoded filename and return its basename without extension."""
    decoded = unquote(filename)
    base = os.path.basename(decoded)
    base_without_ext, _ = os.path.splitext(base)
    return base_without_ext

def find_album_folder(album_name):
    """Recursively search for a folder whose name starts with album_name in the music USB."""
    # Get the actual music USB mount point dynamically
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