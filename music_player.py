#!/usr/bin/env python3
"""
Music Player - VLC-based music player with event-driven USB support
Replaces the pygame-based player with a more robust VLC implementation
"""

import os
import time
import glob
import threading
from urllib.parse import unquote
import vlc
from utils import log_message, find_album_folder
from config import CONTROL_FILE_NAME, VOLUME_LEVEL, repeat_playback

class MusicPlayer:
    """VLC-based music player with event-driven USB support"""
    
    def __init__(self):
        """Initialize the music player"""
        try:
            # Create VLC instance with optimized audio settings for Raspberry Pi
            vlc_args = [
                '--intf', 'dummy',
                '--no-video',
                '--aout', 'alsa',  # Use ALSA instead of PulseAudio
                '--alsa-audio-device', 'default',
                '--audio-resampler', 'soxr',  # Better resampling
                '--no-audio-time-stretch',  # Disable time stretching
                '--audio-replay-gain-mode', 'none',  # Disable replay gain
                '--no-sout-video',  # Disable video output completely
                '--file-caching', '1000',  # 1 second file cache
                '--network-caching', '1000',  # 1 second network cache
                '--live-caching', '300',  # 300ms live cache
                '--clock-jitter', '0',  # Disable clock jitter
                '--clock-synchro', '0'  # Disable clock sync
            ]
            
            self.vlc_instance = vlc.Instance(vlc_args)
            self.media_player = self.vlc_instance.media_player_new()
            
            # Player state
            self.current_album = None
            self.current_album_folder = None
            self.current_album_tracks = []
            self.current_track_index = 0
            self.current_track_path = None
            self.volume = VOLUME_LEVEL
            self.repeat_mode = repeat_playback
            self.single_track_mode = False  # For single track repeat
            
            # USB sources
            self.music_source = None
            self.control_source = None
            
            # Set initial volume
            self.set_volume(self.volume)
            
            # Set up VLC event callbacks for automatic track progression
            events = self.media_player.event_manager()
            events.event_attach(vlc.EventType.MediaPlayerEndReached, self._on_track_end)
            
            # Control file monitoring
            self.control_file_last_modified = 0
            self.control_monitor_thread = None
            self.control_monitor_running = False
            
            log_message("VLC Music Player initialized with ALSA audio output")
            
        except Exception as e:
            log_message(f"Error initializing VLC player: {str(e)}")
            raise
    
    def set_music_source(self, music_path):
        """Set the music USB source path"""
        if music_path != self.music_source:
            old_source = self.music_source
            self.music_source = music_path
            
            if music_path:
                log_message(f"Music source set to: {music_path}")
                # Don't auto-start playback, wait for control commands
            else:
                log_message("Music source disconnected")
                self.stop_playback()
                self.current_album = None
                self.current_album_folder = None
                self.current_album_tracks = []
    
    def set_control_source(self, control_path):
        """Set the control USB source path"""
        if control_path != self.control_source:
            old_source = self.control_source
            self.control_source = control_path
            
            if control_path:
                log_message(f"Control source set to: {control_path}")
                # Start monitoring control file
                self.start_control_monitoring()
            else:
                log_message("Control source disconnected")
                # Stop monitoring control file
                self.stop_control_monitoring()
    
    def start_control_monitoring(self):
        """Start monitoring the control file for changes"""
        if self.control_monitor_running:
            return
            
        self.control_monitor_running = True
        self.control_monitor_thread = threading.Thread(target=self._control_monitor_loop, daemon=True)
        self.control_monitor_thread.start()
        log_message("Started control file monitoring")
    
    def stop_control_monitoring(self):
        """Stop monitoring the control file"""
        self.control_monitor_running = False
        if self.control_monitor_thread:
            self.control_monitor_thread.join(timeout=2)
        log_message("Stopped control file monitoring")
    
    def _control_monitor_loop(self):
        """Control file monitoring loop"""
        while self.control_monitor_running and self.control_source:
            try:
                control_file_path = os.path.join(self.control_source, CONTROL_FILE_NAME)
                
                if os.path.exists(control_file_path):
                    # Check if file was modified
                    current_mtime = os.path.getmtime(control_file_path)
                    
                    if current_mtime > self.control_file_last_modified:
                        self.control_file_last_modified = current_mtime
                        self._process_control_file(control_file_path)
                
                time.sleep(1)  # Check every second
                
            except Exception as e:
                log_message(f"Error in control monitoring: {str(e)}")
                time.sleep(2)
    
    def _process_control_file(self, control_file_path):
        """Process control file commands"""
        try:
            with open(control_file_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
            
            if not content:
                return
            
            log_message(f"Processing control command: '{content}'")
            
            # Parse control commands
            if content.lower() == 'play':
                self.toggle_play_pause()
            elif content.lower() == 'pause':
                self.pause_playback()
            elif content.lower() == 'stop':
                self.stop_playback()
            elif content.lower() == 'next':
                self.next_track()
            elif content.lower() == 'previous':
                self.previous_track()
            elif content.lower().startswith('volume:'):
                try:
                    vol = int(content.split(':')[1])
                    self.set_volume(vol)
                except (ValueError, IndexError):
                    log_message(f"Invalid volume command: {content}")
            elif content.lower().startswith('album:'):
                album_name = content[6:].strip()
                self.play_album(album_name)
            elif content.lower().startswith('track:'):
                track_name = content[6:].strip()
                self.play_track_by_name(track_name)
            else:
                log_message(f"Unknown control command: {content}")
                
        except Exception as e:
            log_message(f"Error processing control file: {str(e)}")
    
    def play_album(self, album_name):
        """Play an album by name"""
        if not self.music_source:
            log_message("No music source available")
            return False
        
        # Find album folder
        album_folder = find_album_folder(album_name, self.music_source)
        if not album_folder:
            log_message(f"Album not found: {album_name}")
            return False
        
        # Load tracks from album
        tracks = self._load_tracks_from_folder(album_folder)
        if not tracks:
            log_message(f"No tracks found in album: {album_name}")
            return False
        
        # Set current album
        self.current_album = album_name
        self.current_album_folder = album_folder
        self.current_album_tracks = tracks
        self.current_track_index = 0
        
        # Disable single track mode for album playback
        self.single_track_mode = False
        
        log_message(f"Playing album '{album_name}' with {len(tracks)} tracks")
        
        # Start playing first track
        return self._play_track_at_index(0)
    
    def play_track_by_name(self, track_name):
        """Play a specific track by name - implements single track repeat"""
        if not self.music_source:
            log_message("No music source available")
            return False
        
        # Search for track in music source recursively
        found_tracks = self._find_tracks_by_name(track_name)
        
        if not found_tracks:
            log_message(f"Track not found: {track_name}")
            return False
        
        # Play first matching track in single-track repeat mode
        track_path = found_tracks[0]
        self.current_album = f"Single Track: {os.path.basename(track_path)}"
        self.current_album_folder = os.path.dirname(track_path)
        self.current_album_tracks = [track_path]  # Only this track
        self.current_track_index = 0
        self.current_track_path = track_path
        
        # Enable single track repeat mode for specific track requests
        self.single_track_mode = True
        
        log_message(f"Playing single track on repeat: {os.path.basename(track_path)}")
        success = self._play_media(track_path)
        
        if success:
            log_message(f"Single track repeat mode enabled for: {track_name}")
            
        return success
    
    def _find_tracks_by_name(self, track_name):
        """Find tracks by name with recursive search"""
        found_tracks = []
        audio_extensions = ('.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg')
        
        try:
            # Use os.walk for proper recursive search
            for root, dirs, files in os.walk(self.music_source):
                for file in files:
                    if file.lower().endswith(audio_extensions):
                        # Skip macOS hidden files and system files
                        if self._is_valid_audio_file(file):
                            # Check if track name matches (case insensitive, partial match)
                            if track_name.lower() in file.lower():
                                full_path = os.path.join(root, file)
                                found_tracks.append(full_path)
            
            # Sort by exact match first, then partial matches
            def match_quality(track_path):
                filename = os.path.basename(track_path).lower()
                track_lower = track_name.lower()
                
                # Exact filename match (highest priority)
                if filename == track_lower + '.mp3' or filename == track_lower + '.flac':
                    return 0
                # Exact match without extension
                elif os.path.splitext(filename)[0] == track_lower:
                    return 1
                # Starts with search term
                elif filename.startswith(track_lower):
                    return 2
                # Contains search term
                else:
                    return 3
            
            found_tracks.sort(key=match_quality)
            log_message(f"Found {len(found_tracks)} tracks matching '{track_name}'")
            
        except Exception as e:
            log_message(f"Error searching for tracks: {str(e)}")
        
        return found_tracks
    
    def _load_tracks_from_folder(self, folder_path):
        """Load all music files from a folder recursively"""
        tracks = []
        audio_extensions = ('.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg')
        
        try:
            # First try non-recursive (just the folder itself)
            direct_files = []
            for file in sorted(os.listdir(folder_path)):
                if file.lower().endswith(audio_extensions):
                    # Skip macOS hidden files and system files
                    if self._is_valid_audio_file(file):
                        full_path = os.path.join(folder_path, file)
                        direct_files.append(full_path)
            
            if direct_files:
                # If we found files directly in the folder, use those
                tracks = direct_files
                log_message(f"Loaded {len(tracks)} tracks from {folder_path}")
            else:
                # If no direct files, search recursively
                log_message(f"No direct files found, searching recursively in {folder_path}")
                for root, dirs, files in os.walk(folder_path):
                    for file in sorted(files):
                        if file.lower().endswith(audio_extensions):
                            # Skip macOS hidden files and system files
                            if self._is_valid_audio_file(file):
                                full_path = os.path.join(root, file)
                                tracks.append(full_path)
                
                log_message(f"Loaded {len(tracks)} tracks recursively from {folder_path}")
            
        except Exception as e:
            log_message(f"Error loading tracks from {folder_path}: {str(e)}")
        
        return tracks
    
    def _is_valid_audio_file(self, filename):
        """Check if file is a valid audio file (not system/hidden file)"""
        # Skip macOS resource fork files
        if filename.startswith('._'):
            return False
        
        # Skip hidden files
        if filename.startswith('.'):
            return False
        
        # Skip common system files
        system_files = ['Thumbs.db', 'desktop.ini', '.DS_Store']
        if filename in system_files:
            return False
        
        # Skip very small files (likely corrupted)
        return True
    
    def _play_track_at_index(self, index):
        """Play track at specific index in current album"""
        if not self.current_album_tracks or index < 0 or index >= len(self.current_album_tracks):
            log_message(f"Invalid track index: {index}")
            return False
        
        self.current_track_index = index
        track_path = self.current_album_tracks[index]
        self.current_track_path = track_path
        
        return self._play_media(track_path)
    
    def _play_media(self, media_path):
        """Play media file using VLC"""
        try:
            # Create media object
            media = self.vlc_instance.media_new(media_path)
            self.media_player.set_media(media)
            
            # Start playback
            result = self.media_player.play()
            
            if result == 0:  # Success
                track_name = os.path.basename(media_path)
                log_message(f"Now playing: {track_name}")
                return True
            else:
                log_message(f"Failed to play: {media_path}")
                return False
                
        except Exception as e:
            log_message(f"Error playing media {media_path}: {str(e)}")
            return False
    
    def toggle_play_pause(self):
        """Toggle between play and pause"""
        if self.is_playing():
            self.pause_playback()
        else:
            self.resume_playback()
    
    def pause_playback(self):
        """Pause current playback"""
        try:
            self.media_player.pause()
            log_message("Playback paused")
        except Exception as e:
            log_message(f"Error pausing playback: {str(e)}")
    
    def resume_playback(self):
        """Resume paused playback"""
        try:
            if self.media_player.get_state() == vlc.State.Paused:
                self.media_player.play()
                log_message("Playback resumed")
            elif not self.is_playing():
                # If we have tracks loaded, try to resume from current track
                if self.current_album_tracks and self.current_track_index >= 0:
                    log_message("Resuming from current track")
                    self._play_track_at_index(self.current_track_index)
                # If no tracks but we have a music source, try to load default album
                elif self.music_source and os.path.exists(self.music_source):
                    log_message("No tracks loaded, attempting to load default album from music source")
                    self._load_default_album()
                else:
                    log_message("Cannot resume: No tracks available and no music source")
        except Exception as e:
            log_message(f"Error resuming playback: {str(e)}")
    
    def _load_default_album(self):
        """Load the first available album from music source"""
        try:
            if not self.music_source or not os.path.exists(self.music_source):
                log_message("No valid music source available")
                return False
            
            # Look for the first directory with music files
            for root, dirs, files in os.walk(self.music_source):
                # Check if this directory has audio files
                audio_files = []
                for file in files:
                    if file.lower().endswith(('.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg')):
                        if self._is_valid_audio_file(file):
                            audio_files.append(os.path.join(root, file))
                
                if audio_files:
                    # Found a directory with music, load it as default
                    self.current_album = os.path.basename(root) or "Default Album"
                    self.current_album_folder = root
                    self.current_album_tracks = sorted(audio_files)
                    self.current_track_index = 0
                    self.single_track_mode = False
                    
                    log_message(f"Loaded default album '{self.current_album}' with {len(audio_files)} tracks")
                    return self._play_track_at_index(0)
            
            log_message("No audio files found in music source")
            return False
            
        except Exception as e:
            log_message(f"Error loading default album: {str(e)}")
            return False
    
    def stop_playback(self):
        """Stop current playback"""
        try:
            self.media_player.stop()
            log_message("Playback stopped")
        except Exception as e:
            log_message(f"Error stopping playback: {str(e)}")
    
    def next_track(self):
        """Skip to next track"""
        if not self.current_album_tracks:
            log_message("No tracks to skip")
            return
        
        next_index = self.current_track_index + 1
        
        if next_index >= len(self.current_album_tracks):
            if self.repeat_mode:
                next_index = 0  # Loop back to first track
            else:
                log_message("End of album reached")
                return
        
        log_message(f"Skipping to track {next_index + 1}")
        self._play_track_at_index(next_index)
    
    def previous_track(self):
        """Skip to previous track"""
        if not self.current_album_tracks:
            log_message("No tracks to skip")
            return
        
        prev_index = self.current_track_index - 1
        
        if prev_index < 0:
            if self.repeat_mode:
                prev_index = len(self.current_album_tracks) - 1  # Loop to last track
            else:
                log_message("At beginning of album")
                return
        
        log_message(f"Skipping to track {prev_index + 1}")
        self._play_track_at_index(prev_index)
    
    def set_volume(self, volume):
        """Set playback volume (0-100)"""
        try:
            volume = max(0, min(100, volume))  # Clamp to 0-100
            self.media_player.audio_set_volume(volume)
            self.volume = volume
            log_message(f"Volume set to {volume}%")
            return True
        except Exception as e:
            log_message(f"Error setting volume: {str(e)}")
            return False
    
    def get_volume(self):
        """Get current volume level"""
        return self.volume
    
    def is_playing(self):
        """Check if currently playing"""
        try:
            state = self.media_player.get_state()
            return state == vlc.State.Playing
        except:
            return False
    
    def get_current_media_title(self):
        """Get current track title"""
        if self.current_track_path:
            return os.path.basename(self.current_track_path)
        return None
    
    def get_playback_info(self):
        """Get current playback position and length"""
        try:
            position = self.media_player.get_time()  # milliseconds
            length = self.media_player.get_length()  # milliseconds
            
            return {
                'position': position if position >= 0 else 0,
                'length': length if length > 0 else 0
            }
        except:
            return {'position': 0, 'length': 0}
    
    def update_repeat_mode(self, repeat_enabled):
        """Update repeat mode"""
        self.repeat_mode = repeat_enabled
        log_message(f"Repeat mode {'enabled' if repeat_enabled else 'disabled'}")
    
    def get_status(self):
        """Get comprehensive player status"""
        playback_info = self.get_playback_info()
        
        return {
            'is_playing': self.is_playing(),
            'current_album': self.current_album,
            'current_track': self.get_current_media_title(),
            'track_index': self.current_track_index,
            'total_tracks': len(self.current_album_tracks),
            'volume': self.volume,
            'repeat_mode': self.repeat_mode,
            'single_track_mode': self.single_track_mode,
            'position': playback_info['position'],
            'length': playback_info['length'],
            'music_source': self.music_source,
            'control_source': self.control_source,
            'control_monitoring': self.control_monitor_running
        }
    
    def _on_track_end(self, event):
        """Handle end of track event from VLC"""
        try:
            if self.single_track_mode:
                # In single track mode, repeat the same track
                log_message("Single track ended, repeating...")
                time.sleep(0.5)  # Small delay to avoid rapid repeats
                self._play_track_at_index(self.current_track_index)
            elif self.repeat_mode or self.current_track_index < len(self.current_album_tracks) - 1:
                # Normal album mode with repeat or more tracks available
                log_message("Track ended, playing next...")
                self.next_track()
            else:
                log_message("Album completed, stopping playback")
                
        except Exception as e:
            log_message(f"Error handling track end: {str(e)}") 