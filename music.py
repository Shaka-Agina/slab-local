#!/usr/bin/env python3
# music.py

import os
import time
import pygame
import threading
from utils import log_message, find_music_usb, find_control_usb_with_retry, usb_is_mounted, find_album_folder
from config import CONTROL_FILE_NAME, AUDIO_OUTPUT, VOLUME_LEVEL

class MusicController:
    def __init__(self):
        pygame.mixer.pre_init(frequency=44100, size=-16, channels=2, buffer=1024)
        pygame.mixer.init()
        
        # Set audio output
        os.environ['SDL_AUDIODRIVER'] = AUDIO_OUTPUT
        
        self.current_track = None
        self.is_playing = False
        self.is_paused = False
        self.volume = VOLUME_LEVEL
        self.track_position = 0
        self.track_length = 0
        self.playlist = []
        self.current_index = 0
        self.repeat_mode = False
        
        # Set initial volume
        pygame.mixer.music.set_volume(self.volume)
        
        log_message("Music controller initialized with native USB detection")

    def get_status(self):
        """Get current playback status."""
        return {
            'is_playing': self.is_playing,
            'is_paused': self.is_paused,
            'current_track': self.current_track,
            'volume': self.volume,
            'position': self.get_position(),
            'length': self.track_length,
            'playlist_length': len(self.playlist),
            'current_index': self.current_index,
            'repeat_mode': self.repeat_mode
        }

    def check_control_file(self):
        """Check for control file and execute commands."""
        log_message("Checking for control file...")
        
        # Find control USB using native detection
        control_usb_path = find_control_usb_with_retry()
        
        if not control_usb_path:
            log_message("No control USB found")
            return
        
        control_file_path = os.path.join(control_usb_path, CONTROL_FILE_NAME)
        
        if not os.path.isfile(control_file_path):
            log_message(f"Control file not found: {control_file_path}")
            return
        
        try:
            with open(control_file_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
            
            if not content:
                log_message("Control file is empty")
                return
            
            log_message(f"Control file content: '{content}'")
            
            # Parse control commands
            if content.lower() == 'play':
                self.play()
            elif content.lower() == 'pause':
                self.pause()
            elif content.lower() == 'stop':
                self.stop()
            elif content.lower() == 'next':
                self.next_track()
            elif content.lower() == 'previous':
                self.previous_track()
            elif content.lower().startswith('volume:'):
                try:
                    vol = float(content.split(':')[1]) / 100.0
                    self.set_volume(vol)
                except (ValueError, IndexError):
                    log_message(f"Invalid volume command: {content}")
            elif content.lower().startswith('album:'):
                album_name = content[6:].strip()
                self.play_album(album_name)
            else:
                log_message(f"Unknown control command: {content}")
                
        except Exception as e:
            log_message(f"Error reading control file: {str(e)}")

    def play_album(self, album_name):
        """Load and play an album."""
        log_message(f"Attempting to play album: {album_name}")
        
        # Find music USB
        music_usb_path = find_music_usb()
        if not music_usb_path:
            log_message("No music USB found for album playback")
            return False
        
        # Find album folder
        album_folder = find_album_folder(album_name)
        if not album_folder:
            log_message(f"Album folder not found: {album_name}")
            return False
        
        # Load tracks from album
        tracks = self.load_tracks_from_folder(album_folder)
        if not tracks:
            log_message(f"No playable tracks found in album: {album_folder}")
            return False
        
        self.playlist = tracks
        self.current_index = 0
        log_message(f"Loaded {len(tracks)} tracks from album: {album_name}")
        
        # Start playing first track
        return self.play_track(0)

    def load_tracks_from_folder(self, folder_path):
        """Load all music files from a folder."""
        tracks = []
        supported_formats = ('.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg')
        
        try:
            for file in sorted(os.listdir(folder_path)):
                if file.lower().endswith(supported_formats):
                    full_path = os.path.join(folder_path, file)
                    tracks.append(full_path)
            
            log_message(f"Found {len(tracks)} tracks in {folder_path}")
            
        except Exception as e:
            log_message(f"Error loading tracks from {folder_path}: {str(e)}")
        
        return tracks

    def play_track(self, index):
        """Play a specific track by index."""
        if not self.playlist or index < 0 or index >= len(self.playlist):
            log_message(f"Invalid track index: {index}")
            return False
        
        track_path = self.playlist[index]
        
        try:
            pygame.mixer.music.load(track_path)
            pygame.mixer.music.play()
            
            self.current_track = os.path.basename(track_path)
            self.current_index = index
            self.is_playing = True
            self.is_paused = False
            
            log_message(f"Playing track: {self.current_track}")
            return True
            
        except Exception as e:
            log_message(f"Error playing track {track_path}: {str(e)}")
            return False

    def play(self):
        """Resume or start playback."""
        if self.is_paused:
            pygame.mixer.music.unpause()
            self.is_paused = False
            self.is_playing = True
            log_message("Playback resumed")
        elif self.playlist and not self.is_playing:
            self.play_track(self.current_index)
        else:
            log_message("Nothing to play")

    def pause(self):
        """Pause playback."""
        if self.is_playing and not self.is_paused:
            pygame.mixer.music.pause()
            self.is_paused = True
            self.is_playing = False
            log_message("Playback paused")

    def stop(self):
        """Stop playback."""
        pygame.mixer.music.stop()
        self.is_playing = False
        self.is_paused = False
        self.current_track = None
        log_message("Playback stopped")

    def next_track(self):
        """Play next track."""
        if not self.playlist:
            log_message("No playlist loaded")
            return
        
        next_index = self.current_index + 1
        if next_index >= len(self.playlist):
            if self.repeat_mode:
                next_index = 0
            else:
                log_message("End of playlist reached")
                return
        
        self.play_track(next_index)

    def previous_track(self):
        """Play previous track."""
        if not self.playlist:
            log_message("No playlist loaded")
            return
        
        prev_index = self.current_index - 1
        if prev_index < 0:
            if self.repeat_mode:
                prev_index = len(self.playlist) - 1
            else:
                log_message("Beginning of playlist reached")
                return
        
        self.play_track(prev_index)

    def set_volume(self, volume):
        """Set playback volume (0.0 to 1.0)."""
        self.volume = max(0.0, min(1.0, volume))
        pygame.mixer.music.set_volume(self.volume)
        log_message(f"Volume set to: {int(self.volume * 100)}%")

    def get_position(self):
        """Get current playback position (approximate)."""
        if self.is_playing:
            return pygame.mixer.music.get_pos() / 1000.0  # Convert to seconds
        return 0

    def toggle_repeat(self):
        """Toggle repeat mode."""
        self.repeat_mode = not self.repeat_mode
        log_message(f"Repeat mode: {'ON' if self.repeat_mode else 'OFF'}")

# Global music controller instance
music_controller = MusicController() 