#!/usr/bin/env python3
# utils.py - Unified USB detection for both native and Docker deployments

import os
import time
import glob
import subprocess
from urllib.parse import unquote
from config import CONTROL_FILE_NAME
from datetime import datetime

# Global log variable
log_messages = []

def log_message(message):
    """Log a message with timestamp."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

def is_usb_accessible(mount_path):
    """Check if a USB path is actually accessible and has content."""
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
    """
    Find music USB drive with architecture-aware path selection.
    
    Priority order:
    1. Environment variable override (MUSIC_USB_MOUNT)
    2. Native bind mount (/home/pi/usb/music)
    3. Docker shared mount (/shared/usb/music)
    4. Direct desktop mounts (/media/pi/MUSIC*)
    5. Legacy mounts (/home/pi/usb, /mnt/usb)
    """
    
    # Priority 1: Environment variable override
    env_path = os.environ.get('MUSIC_USB_MOUNT')
    if env_path:
        is_accessible, reason = is_usb_accessible(env_path)
        if is_accessible:
            log_message(f"Music USB found via environment: {env_path}")
            return env_path
        else:
            log_message(f"Environment music path not accessible: {env_path} - {reason}")
    
    # Priority 2: Native bind mount (native deployment)
    native_paths = ["/home/pi/usb/music"]
    for path in native_paths:
        is_accessible, reason = is_usb_accessible(path)
        if is_accessible:
            log_message(f"Music USB found via native bind mount: {path}")
            return path
        else:
            log_message(f"Native bind mount not accessible: {path} - {reason}")
    
    # Priority 3: Docker shared mount (hybrid deployment)
    docker_paths = ["/shared/usb/music"]
    for path in docker_paths:
        is_accessible, reason = is_usb_accessible(path)
        if is_accessible:
            log_message(f"Music USB found via Docker shared mount: {path}")
            return path
        else:
            log_message(f"Docker shared mount not accessible: {path} - {reason}")
    
    # Priority 4: Direct desktop mounts
    if os.path.exists("/media/pi"):
        try:
            media_items = os.listdir("/media/pi")
            for item in media_items:
                if item.startswith("MUSIC"):
                    mount_path = f"/media/pi/{item}"
                    is_accessible, reason = is_usb_accessible(mount_path)
                    if is_accessible:
                        log_message(f"Music USB found via direct mount: {mount_path}")
                        return mount_path
                    else:
                        log_message(f"Direct mount not accessible: {mount_path} - {reason}")
        except Exception as e:
            log_message(f"Error scanning /media/pi: {e}")
    
    # Priority 5: Legacy mounts
    legacy_paths = ["/home/pi/usb", "/mnt/usb"]
    for path in legacy_paths:
        is_accessible, reason = is_usb_accessible(path)
        if is_accessible:
            log_message(f"Music USB found via legacy mount: {path}")
            return path
        else:
            log_message(f"Legacy mount not accessible: {path} - {reason}")
    
    log_message("No accessible music USB drive found in any location")
    return None

def find_control_usb():
    """
    Find control USB drive with architecture-aware path selection.
    
    Priority order:
    1. Environment variable override (CONTROL_USB_MOUNT)
    2. Native bind mount (/home/pi/usb/playcard)
    3. Docker shared mount (/shared/usb/playcard)
    4. Direct desktop mounts (/media/pi/PLAY_CARD*)
    5. Same as music USB (if control file exists there)
    """
    
    # Priority 1: Environment variable override
    env_path = os.environ.get('CONTROL_USB_MOUNT')
    if env_path:
        is_accessible, reason = is_usb_accessible(env_path)
        control_file = os.path.join(env_path, CONTROL_FILE_NAME)
        if is_accessible and os.path.isfile(control_file):
            log_message(f"Control USB found via environment: {env_path}")
            return env_path
        else:
            log_message(f"Environment control path not accessible or missing control file: {env_path}")
    
    # Priority 2: Native bind mount (native deployment)
    native_paths = ["/home/pi/usb/playcard"]
    for path in native_paths:
        is_accessible, reason = is_usb_accessible(path)
        control_file = os.path.join(path, CONTROL_FILE_NAME)
        if is_accessible and os.path.isfile(control_file):
            log_message(f"Control USB found via native bind mount: {path}")
            return path
        else:
            log_message(f"Native control bind mount issue: {path} - {reason if not is_accessible else 'no control file'}")
    
    # Priority 3: Docker shared mount (hybrid deployment)
    docker_paths = ["/shared/usb/playcard"]
    for path in docker_paths:
        is_accessible, reason = is_usb_accessible(path)
        control_file = os.path.join(path, CONTROL_FILE_NAME)
        if is_accessible and os.path.isfile(control_file):
            log_message(f"Control USB found via Docker shared mount: {path}")
            return path
        else:
            log_message(f"Docker control shared mount issue: {path} - {reason if not is_accessible else 'no control file'}")
    
    # Priority 4: Direct desktop mounts
    if os.path.exists("/media/pi"):
        try:
            media_items = os.listdir("/media/pi")
            for item in media_items:
                if item.startswith("PLAY_CARD"):
                    mount_path = f"/media/pi/{item}"
                    is_accessible, reason = is_usb_accessible(mount_path)
                    control_file = os.path.join(mount_path, CONTROL_FILE_NAME)
                    if is_accessible and os.path.isfile(control_file):
                        log_message(f"Control USB found via direct mount: {mount_path}")
                        return mount_path
                    else:
                        log_message(f"Direct control mount issue: {mount_path} - {reason if not is_accessible else 'no control file'}")
        except Exception as e:
            log_message(f"Error scanning /media/pi for control USB: {e}")
    
    # Priority 5: Check if control file is on music USB
    music_usb = find_music_usb()
    if music_usb:
        control_file = os.path.join(music_usb, CONTROL_FILE_NAME)
        if os.path.isfile(control_file):
            log_message(f"Control file found on music USB: {music_usb}")
            return music_usb
    
    log_message("No accessible control USB drive found in any location")
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
    """Return True if mount_path is accessible and has content."""
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

def get_mount_info():
    """Get information about current mount points for debugging."""
    info = {
        "music_usb": find_music_usb(),
        "control_usb": find_control_usb(),
        "available_mounts": []
    }
    
    # Check various mount locations
    check_paths = [
        "/media/pi",
        "/home/pi/usb",
        "/shared/usb",
        "/mnt"
    ]
    
    for base_path in check_paths:
        if os.path.exists(base_path):
            try:
                items = os.listdir(base_path)
                for item in items:
                    item_path = os.path.join(base_path, item)
                    if os.path.isdir(item_path):
                        is_accessible, reason = is_usb_accessible(item_path)
                        info["available_mounts"].append({
                            "path": item_path,
                            "accessible": is_accessible,
                            "reason": reason
                        })
            except Exception as e:
                info["available_mounts"].append({
                    "path": base_path,
                    "accessible": False,
                    "reason": f"Error scanning: {e}"
                })
    
    return info

def run_command(command, timeout=10):
    """Run a system command with timeout."""
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            capture_output=True, 
            text=True, 
            timeout=timeout
        )
        return result.returncode == 0, result.stdout.strip(), result.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e) 