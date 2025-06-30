#!/usr/bin/env python3
# utils.py

import os
import time
import glob
import subprocess
from urllib.parse import unquote
from config import CONTROL_FILE_NAME

# Global log variable
log_messages = []

def log_message(msg):
    """Log a message with a timestamp."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] {msg}"
    log_messages.append(message)
    print(message)

def is_usb_accessible(mount_path):
    """Check if a USB path is actually accessible and has content (Docker-friendly)."""
    try:
        if not os.path.exists(mount_path):
            return False, "Path does not exist"
        
        if not os.path.isdir(mount_path):
            return False, "Not a directory"
        
        # Try to list contents with timeout protection
        try:
            contents = os.listdir(mount_path)
        except (OSError, PermissionError) as e:
            return False, f"Cannot list directory: {str(e)}"
        
        if not contents:
            return False, "Directory is empty"
        
        # Additional test: try to access a file to ensure it's really mounted
        try:
            for item in contents[:3]:  # Test first 3 items
                item_path = os.path.join(mount_path, item)
                if os.path.isfile(item_path):
                    # Try to get file stats (this will fail if mount is stale)
                    os.stat(item_path)
                    break
        except (OSError, PermissionError) as e:
            return False, f"Mount appears stale: {str(e)}"
        
        return True, f"Accessible with {len(contents)} items"
        
    except Exception as e:
        return False, f"Unexpected error: {str(e)}"

def find_music_usb():
    """Find the music USB by scanning /media/pi/ directly (Docker-optimized)."""
    log_message("Scanning for music USB drives...")
    
    # Look for mounted USB drives in /media/pi/
    try:
        if not os.path.exists("/media/pi"):
            log_message("Desktop auto-mount directory /media/pi not found")
            return None
            
        items = os.listdir("/media/pi")
        if not items:
            log_message("No items found in /media/pi")
            return None
            
        for item in items:
            mount_path = f"/media/pi/{item}"
            
            if not os.path.isdir(mount_path):
                continue
                
            # Use our Docker-friendly accessibility check
            is_accessible, reason = is_usb_accessible(mount_path)
            log_message(f"Checking mounted drive: {mount_path} - {reason}")
            
            if not is_accessible:
                continue
            
            try:
                contents = os.listdir(mount_path)
                
                # Check if it's labeled as MUSIC (exact or with numbers)
                if item == "MUSIC" or (item.startswith("MUSIC") and item[5:].isdigit()):
                    log_message(f"Found MUSIC USB: {mount_path}")
                    return mount_path
                
                # Check if it contains music files
                music_files = []
                for root, dirs, files in os.walk(mount_path):
                    # Only check first 2 levels to avoid deep scanning
                    if root.count(os.sep) - mount_path.count(os.sep) > 2:
                        continue
                    for file in files:
                        if file.lower().endswith(('.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg')):
                            music_files.append(file)
                            break  # Found music, no need to scan more
                    if music_files:
                        break
                
                if music_files:
                    log_message(f"Found music files in {mount_path}, using as music USB")
                    return mount_path
                    
            except (OSError, PermissionError) as e:
                log_message(f"Cannot access {mount_path}: {str(e)}")
                continue
                
    except Exception as e:
        log_message(f"Error scanning for music USB: {str(e)}")
    
    log_message("No music USB found")
    return None

def find_control_usb():
    """Find control USB by scanning /media/pi/ directly for control.txt (Docker-optimized)."""
    log_message("Scanning for control USB drives...")
    
    # Look for mounted USB drives in /media/pi/
    try:
        if not os.path.exists("/media/pi"):
            log_message("Desktop auto-mount directory /media/pi not found")
            return None
            
        items = os.listdir("/media/pi")
        if not items:
            log_message("No items found in /media/pi")
            return None
            
        for item in items:
            mount_path = f"/media/pi/{item}"
            
            if not os.path.isdir(mount_path):
                continue
                
            # Use our Docker-friendly accessibility check
            is_accessible, reason = is_usb_accessible(mount_path)
            log_message(f"Checking mounted drive for control file: {mount_path} - {reason}")
            
            if not is_accessible:
                continue
            
            try:
                # Check for control.txt file
                control_file_path = os.path.join(mount_path, CONTROL_FILE_NAME)
                if os.path.isfile(control_file_path):
                    # Additional verification: try to read the file
                    try:
                        with open(control_file_path, 'r') as f:
                            content = f.read().strip()
                        log_message(f"Found control file: {control_file_path} (content: '{content}')")
                        return mount_path
                    except Exception as e:
                        log_message(f"Control file exists but cannot read: {control_file_path} - {str(e)}")
                        continue
                else:
                    log_message(f"No {CONTROL_FILE_NAME} in {mount_path}")
                    
            except (OSError, PermissionError) as e:
                log_message(f"Cannot access {mount_path}: {str(e)}")
                continue
                
    except Exception as e:
        log_message(f"Error scanning for control USB: {str(e)}")
    
    log_message("No control USB found")
    return None

def find_control_usb_with_retry(max_retries=3, retry_delay=2):
    """Find control USB with retry - increased delay for Docker mount detection."""
    log_message(f"Attempting to find control USB (max {max_retries} retries, {retry_delay}s delay)...")
    
    for attempt in range(max_retries):
        if attempt > 0:
            log_message(f"Retry {attempt} of {max_retries} for control USB detection...")
            time.sleep(retry_delay)
        
        result = find_control_usb()
        if result:
            log_message(f"Control USB found on attempt {attempt + 1}")
            return result
    
    log_message(f"Failed to find control USB after {max_retries} attempts")
    return None

def usb_is_mounted(mount_path):
    """Return True if mount_path is accessible and has content (Docker-friendly)."""
    is_accessible, reason = is_usb_accessible(mount_path)
    log_message(f"USB mount check for {mount_path}: {reason}")
    return is_accessible

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