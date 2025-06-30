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

def wait_for_mount_ready(mount_path, max_wait=10):
    """Wait for a mount point to be fully ready with content."""
    for i in range(max_wait):
        try:
            if os.path.exists(mount_path) and os.path.ismount(mount_path):
                # Check if we can list contents and it's not empty
                contents = os.listdir(mount_path)
                if contents:  # Mount point has content
                    log_message(f"Mount point ready after {i}s: {mount_path} ({len(contents)} items)")
                    return True
            time.sleep(1)
        except (OSError, PermissionError):
            time.sleep(1)
            continue
    
    log_message(f"Mount point not ready after {max_wait}s: {mount_path}")
    return False

def find_usb_drives_by_label_pattern(label_pattern):
    """Find all mounted USB drives that match a label pattern (e.g., 'MUSIC*', 'PLAY_CARD*')."""
    mounted_drives = []
    
    try:
        # First check bind mount locations (preferred - stable paths with proper permissions)
        if label_pattern.startswith("MUSIC"):
            bind_mount_path = "/home/pi/usb/music"
            if os.path.exists(bind_mount_path):
                # Wait a bit for bind mount to be ready
                if wait_for_mount_ready(bind_mount_path, max_wait=5):
                    mounted_drives.append(bind_mount_path)
                    log_message(f"Found bind-mounted USB drive: {bind_mount_path}")
                    return mounted_drives
                elif usb_is_mounted(bind_mount_path):
                    # Fallback: even if not fully ready, try to use it
                    mounted_drives.append(bind_mount_path)
                    log_message(f"Found bind-mounted USB drive (not fully ready): {bind_mount_path}")
                    return mounted_drives
        
        if label_pattern.startswith("PLAY_CARD"):
            bind_mount_path = "/home/pi/usb/playcard"
            if os.path.exists(bind_mount_path):
                # For control USB, be more patient and check for control file
                if wait_for_mount_ready(bind_mount_path, max_wait=10):
                    # Additional check for control file
                    control_file_path = os.path.join(bind_mount_path, CONTROL_FILE_NAME)
                    if os.path.isfile(control_file_path):
                        mounted_drives.append(bind_mount_path)
                        log_message(f"Found bind-mounted control USB with control file: {bind_mount_path}")
                        return mounted_drives
                    else:
                        log_message(f"Bind-mounted USB found but no control file: {bind_mount_path}")
                elif usb_is_mounted(bind_mount_path):
                    # Fallback check
                    control_file_path = os.path.join(bind_mount_path, CONTROL_FILE_NAME)
                    if os.path.isfile(control_file_path):
                        mounted_drives.append(bind_mount_path)
                        log_message(f"Found bind-mounted control USB (slow mount): {bind_mount_path}")
                        return mounted_drives
        
        # Fallback: Look for mount points in /media/pi/ that match the pattern
        pattern_path = f"/media/pi/{label_pattern}"
        matching_paths = glob.glob(pattern_path)
        
        for path in matching_paths:
            if os.path.exists(path):
                # Wait for mount to be ready
                if wait_for_mount_ready(path, max_wait=5):
                    mounted_drives.append(path)
                    log_message(f"Found mounted USB drive: {path}")
                elif os.path.ismount(path):
                    # Fallback: try even if not fully ready
                    try:
                        os.listdir(path)  # Test access
                        mounted_drives.append(path)
                        log_message(f"Found mounted USB drive (not fully ready): {path}")
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
        contents = os.listdir(mount_path)
        
        # For bind mount paths, we need to be more strict about what constitutes "mounted"
        if mount_path.startswith("/home/pi/usb/"):
            # Bind mount directories exist even when USB is disconnected, but they're empty
            # A mounted USB should have at least some files
            if len(contents) == 0:
                log_message(f"Mount check for {mount_path}: accessible but empty (USB likely disconnected)")
                return False
            else:
                log_message(f"Mount check for {mount_path}: accessible with {len(contents)} items")
                return True
        else:
            # For traditional mount points (/media/pi/), just being accessible is enough
            log_message(f"Mount check for {mount_path}: accessible with {len(contents)} items")
            return True
        
    except (OSError, PermissionError) as e:
        log_message(f"Mount check for {mount_path}: not accessible - {str(e)}")
        return False

def find_control_usb_with_retry(max_retries=3, retry_delay=2):
    """Find control USB with retry logic for timing issues."""
    for attempt in range(max_retries):
        if attempt > 0:
            log_message(f"Retrying control USB detection (attempt {attempt + 1}/{max_retries})...")
            time.sleep(retry_delay)
        
        result = find_control_usb()
        if result:
            return result
    
    log_message(f"Failed to find control USB after {max_retries} attempts")
    return None

def find_control_usb():
    """Find mounted USB device for control files (including numbered variants like PLAY_CARD1)."""
    
    # FIRST: Check bind mount paths (preferred - stable paths with proper permissions)
    log_message("Checking bind mount paths first...")
    bind_mount_path = "/home/pi/usb/playcard"
    
    if os.path.exists(bind_mount_path):
        # Wait for bind mount to be ready
        if wait_for_mount_ready(bind_mount_path, max_wait=5) or usb_is_mounted(bind_mount_path):
            # Additional check: verify the control file exists
            control_file_path = os.path.join(bind_mount_path, CONTROL_FILE_NAME)
            if os.path.isfile(control_file_path):
                log_message(f"Control USB found at bind mount {bind_mount_path} with control file")
                return bind_mount_path
            else:
                log_message(f"Bind mount {bind_mount_path} exists but no control file found")
                # Try to wait a bit more for the file to appear
                for i in range(5):
                    time.sleep(1)
                    if os.path.isfile(control_file_path):
                        log_message(f"Control file appeared after {i+1}s wait: {control_file_path}")
                        return bind_mount_path
                log_message(f"Control file still not found after extended wait: {control_file_path}")
    
    # SECOND: Try the configured path (for backward compatibility)
    log_message(f"Checking configured path: {CONTROL_USB_MOUNT}")
    
    if usb_is_mounted(CONTROL_USB_MOUNT):
        # Additional check: verify the control file exists
        control_file_path = os.path.join(CONTROL_USB_MOUNT, CONTROL_FILE_NAME)
        if os.path.isfile(control_file_path):
            log_message(f"Control USB found at configured path {CONTROL_USB_MOUNT} with control file")
            return CONTROL_USB_MOUNT
    
    # THIRD: Search for any PLAY_CARD* drives dynamically
    log_message("Searching for PLAY_CARD USB drives with dynamic detection...")
    playcard_drives = find_usb_drives_by_label_pattern("PLAY_CARD*")
    
    for drive_path in playcard_drives:
        control_file_path = os.path.join(drive_path, CONTROL_FILE_NAME)
        if os.path.isfile(control_file_path):
            log_message(f"Control USB found at {drive_path} with control file")
            return drive_path
        else:
            log_message(f"PLAY_CARD drive found at {drive_path} but no control file")
    
    # FOURTH: Try to find ANY USB with a control.txt file (last resort)
    log_message("Last resort: searching all USB drives for control.txt...")
    try:
        for mount_point in glob.glob("/media/pi/*"):
            if os.path.isdir(mount_point) and os.path.ismount(mount_point):
                control_file_path = os.path.join(mount_point, CONTROL_FILE_NAME)
                if os.path.isfile(control_file_path):
                    log_message(f"Control file found on unlabeled USB: {mount_point}")
                    return mount_point
    except Exception as e:
        log_message(f"Error in last resort search: {str(e)}")
    
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