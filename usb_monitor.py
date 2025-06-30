#!/usr/bin/env python3
"""
USB Monitor - Event-driven USB detection for native deployment
Uses udev events instead of continuous polling for better performance
"""

import os
import time
import threading
import subprocess
from pathlib import Path
from utils import log_message, is_usb_accessible
from config import CONTROL_FILE_NAME

class USBMonitor:
    def __init__(self, on_music_usb_change=None, on_control_usb_change=None):
        self.on_music_usb_change = on_music_usb_change
        self.on_control_usb_change = on_control_usb_change
        self.current_music_usb = None
        self.current_control_usb = None
        self.monitoring = False
        self.monitor_thread = None
        
    def start_monitoring(self):
        """Start event-driven USB monitoring"""
        if self.monitoring:
            return
            
        self.monitoring = True
        log_message("Starting event-driven USB monitoring...")
        
        # Initial scan for already mounted drives
        self._initial_scan()
        
        # Start udev monitoring in separate thread
        self.monitor_thread = threading.Thread(target=self._monitor_udev_events, daemon=True)
        self.monitor_thread.start()
        
    def stop_monitoring(self):
        """Stop USB monitoring"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2)
        log_message("USB monitoring stopped")
        
    def _initial_scan(self):
        """Scan for already mounted USB drives"""
        log_message("Performing initial USB scan...")
        
        music_usb = self._find_music_usb()
        control_usb = self._find_control_usb()
        
        if music_usb != self.current_music_usb:
            self._handle_music_usb_change(music_usb)
            
        if control_usb != self.current_control_usb:
            self._handle_control_usb_change(control_usb)
            
    def _monitor_udev_events(self):
        """Monitor udev events for USB changes"""
        try:
            # Use udevadm to monitor block device events
            cmd = ['udevadm', 'monitor', '--property', '--subsystem-match=block']
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                bufsize=1
            )
            
            log_message("Started udev event monitoring")
            
            while self.monitoring:
                try:
                    line = process.stdout.readline()
                    if not line:
                        break
                        
                    # Look for add/remove events
                    if 'ACTION=add' in line or 'ACTION=remove' in line:
                        # Give the system a moment to mount/unmount
                        time.sleep(1)
                        self._check_usb_changes()
                        
                except Exception as e:
                    if self.monitoring:  # Only log if we're still supposed to be monitoring
                        log_message(f"Error reading udev events: {e}")
                    break
                    
        except FileNotFoundError:
            log_message("udevadm not found, falling back to polling...")
            self._fallback_polling()
        except Exception as e:
            log_message(f"Error starting udev monitoring: {e}")
            self._fallback_polling()
            
    def _fallback_polling(self):
        """Fallback to polling if udev monitoring fails"""
        log_message("Using fallback polling method (checking every 3 seconds)")
        
        while self.monitoring:
            try:
                self._check_usb_changes()
                time.sleep(3)  # Much less frequent than before
            except Exception as e:
                if self.monitoring:
                    log_message(f"Error in USB polling: {e}")
                time.sleep(5)
                
    def _check_usb_changes(self):
        """Check for USB drive changes"""
        music_usb = self._find_music_usb()
        control_usb = self._find_control_usb()
        
        if music_usb != self.current_music_usb:
            self._handle_music_usb_change(music_usb)
            
        if control_usb != self.current_control_usb:
            self._handle_control_usb_change(control_usb)
            
    def _handle_music_usb_change(self, new_music_usb):
        """Handle music USB mount/unmount"""
        old_music_usb = self.current_music_usb
        self.current_music_usb = new_music_usb
        
        if old_music_usb and not new_music_usb:
            log_message(f"Music USB unmounted: {old_music_usb}")
        elif new_music_usb and not old_music_usb:
            log_message(f"Music USB mounted: {new_music_usb}")
        elif new_music_usb != old_music_usb:
            log_message(f"Music USB changed: {old_music_usb} → {new_music_usb}")
            
        if self.on_music_usb_change:
            self.on_music_usb_change(new_music_usb, old_music_usb)
            
    def _handle_control_usb_change(self, new_control_usb):
        """Handle control USB mount/unmount"""
        old_control_usb = self.current_control_usb
        self.current_control_usb = new_control_usb
        
        if old_control_usb and not new_control_usb:
            log_message(f"Control USB unmounted: {old_control_usb}")
        elif new_control_usb and not old_control_usb:
            log_message(f"Control USB mounted: {new_control_usb}")
        elif new_control_usb != old_control_usb:
            log_message(f"Control USB changed: {old_control_usb} → {new_control_usb}")
            
        if self.on_control_usb_change:
            self.on_control_usb_change(new_control_usb, old_control_usb)
            
    def _find_music_usb(self):
        """Find music USB with proper permission handling"""
        # Check environment override first
        env_path = os.environ.get('MUSIC_USB_MOUNT')
        if env_path and self._is_usb_accessible_with_permissions(env_path):
            return env_path
            
        # Check /media/pi for MUSIC drives
        media_pi = Path("/media/pi")
        if media_pi.exists():
            try:
                for item in media_pi.iterdir():
                    if item.name.startswith("MUSIC") and item.is_dir():
                        if self._is_usb_accessible_with_permissions(str(item)):
                            return str(item)
            except PermissionError:
                log_message("Permission denied accessing /media/pi - checking user groups")
                self._check_user_permissions()
            except Exception as e:
                log_message(f"Error scanning /media/pi: {e}")
                
        return None
        
    def _find_control_usb(self):
        """Find control USB with proper permission handling"""
        # Check environment override first
        env_path = os.environ.get('CONTROL_USB_MOUNT')
        if env_path:
            control_file = os.path.join(env_path, CONTROL_FILE_NAME)
            if self._is_usb_accessible_with_permissions(env_path) and os.path.isfile(control_file):
                return env_path
                
        # Check /media/pi for PLAY_CARD drives with priority order
        media_pi = Path("/media/pi")
        if media_pi.exists():
            try:
                # First, look for exact match "PLAY_CARD"
                play_card_exact = media_pi / "PLAY_CARD"
                if play_card_exact.exists() and play_card_exact.is_dir():
                    if self._is_usb_accessible_with_permissions(str(play_card_exact)):
                        control_file = play_card_exact / CONTROL_FILE_NAME
                        if control_file.is_file():
                            return str(play_card_exact)
                
                # Then look for numbered variants in order (PLAY_CARD1, PLAY_CARD2, etc.)
                candidates = []
                for item in media_pi.iterdir():
                    if item.name.startswith("PLAY_CARD") and item.is_dir():
                        if self._is_usb_accessible_with_permissions(str(item)):
                            control_file = item / CONTROL_FILE_NAME
                            if control_file.is_file():
                                candidates.append(str(item))
                
                # Sort candidates to prefer lower numbers
                candidates.sort(key=lambda x: (len(os.path.basename(x)), os.path.basename(x)))
                
                if candidates:
                    selected = candidates[0]
                    if len(candidates) > 1:
                        log_message(f"Multiple PLAY_CARD drives found, using: {os.path.basename(selected)}")
                    return selected
                    
            except PermissionError:
                log_message("Permission denied accessing /media/pi - checking user groups")
                self._check_user_permissions()
            except Exception as e:
                log_message(f"Error scanning /media/pi: {e}")
                
        # Fallback: check if control file is on music USB
        music_usb = self._find_music_usb()
        if music_usb:
            control_file = os.path.join(music_usb, CONTROL_FILE_NAME)
            if os.path.isfile(control_file):
                return music_usb
                
        return None
        
    def _is_usb_accessible_with_permissions(self, path):
        """Check USB accessibility with permission troubleshooting"""
        try:
            is_accessible, reason = is_usb_accessible(path)
            if is_accessible:
                return True
                
            # If not accessible due to permissions, try to fix
            if "Permission denied" in reason or "PermissionError" in reason:
                log_message(f"Permission issue with {path}: {reason}")
                self._try_fix_permissions(path)
                
                # Recheck after permission fix attempt
                is_accessible, reason = is_usb_accessible(path)
                if is_accessible:
                    log_message(f"Permission fix successful for {path}")
                    return True
                else:
                    log_message(f"Permission fix failed for {path}: {reason}")
                    
            return False
            
        except Exception as e:
            log_message(f"Error checking USB accessibility for {path}: {e}")
            return False
            
    def _try_fix_permissions(self, path):
        """Attempt to fix USB permission issues"""
        try:
            # Check if user is in required groups
            self._check_user_permissions()
            
            # Try to change ownership if we have sudo access (for development)
            if os.environ.get('USB_PERMISSION_FIX') == 'true':
                try:
                    subprocess.run(['sudo', 'chown', '-R', f'{os.getenv("USER")}:{os.getenv("USER")}', path], 
                                 check=False, capture_output=True)
                    log_message(f"Attempted ownership fix for {path}")
                except Exception as e:
                    log_message(f"Could not fix ownership for {path}: {e}")
                    
        except Exception as e:
            log_message(f"Error attempting permission fix: {e}")
            
    def _check_user_permissions(self):
        """Check and report user group memberships"""
        try:
            result = subprocess.run(['groups'], capture_output=True, text=True)
            groups = result.stdout.strip()
            
            required_groups = ['plugdev', 'audio']
            missing_groups = []
            
            for group in required_groups:
                if group not in groups:
                    missing_groups.append(group)
                    
            if missing_groups:
                log_message(f"User missing required groups: {missing_groups}")
                log_message(f"Current groups: {groups}")
                log_message(f"Run: sudo usermod -aG {' -aG '.join(missing_groups)} $USER")
                log_message("Then logout and login again")
            else:
                log_message(f"User has required groups: {groups}")
                
        except Exception as e:
            log_message(f"Could not check user groups: {e}")
            
    def get_current_usb_status(self):
        """Get current USB status"""
        return {
            'music_usb': self.current_music_usb,
            'control_usb': self.current_control_usb,
            'monitoring': self.monitoring
        } 