#!/usr/bin/env python3
# player.py

import os
import glob
import vlc
from config import DEFAULT_VOLUME, repeat_playback
from utils import log_message, format_track_name

class Player:
    def __init__(self):
        self.current_album = None            # Album folder name if album playback
        self.current_album_folder = None     # Full path for the album
        self.current_album_tracks = []       # List of audio file paths in the album
        self.current_track_path = None       # For single track playback
        self.instance = vlc.Instance()
        self.media_list_player = self.instance.media_list_player_new()
        self.media_player = self.instance.media_player_new()
        self.media_list_player.set_media_player(self.media_player)
        self.volume = DEFAULT_VOLUME  # Use volume from config
        self.media_player.audio_set_volume(self.volume)
    
    def is_active(self):
        """Return True if VLC state is Playing or Paused."""
        state = self.media_player.get_state()
        return state in (vlc.State.Playing, vlc.State.Paused)
    
    def is_playing(self):
        """Return True if VLC state is Playing."""
        state = self.media_player.get_state()
        return state == vlc.State.Playing
    
    def play_album(self, folder_path):
        # More efficient file search - avoid multiple glob operations
        audio_extensions = [".mp3", ".MP3", ".wav", ".WAV", ".flac", ".FLAC"]
        audio_files = []
        
        for root, _, files in os.walk(folder_path):
            for file in files:
                if any(file.endswith(ext) for ext in audio_extensions):
                    audio_files.append(os.path.join(root, file))
        
        # Sort files to ensure consistent playback order
        audio_files.sort()
        
        log_message(f"Found {len(audio_files)} audio files")
        if not audio_files:
            log_message(f"No audio files found in {folder_path} or its subfolders.")
            return
        
        self.current_album = os.path.basename(folder_path)
        self.current_album_folder = folder_path
        self.current_album_tracks = audio_files
        media_list = self.instance.media_list_new()
        for audio_file in audio_files:
            media = self.instance.media_new(audio_file)
            media_list.add_media(media)
        self.media_list_player.set_media_list(media_list)
        if repeat_playback:
            self.media_list_player.set_playback_mode(vlc.PlaybackMode.loop)
        else:
            self.media_list_player.set_playback_mode(vlc.PlaybackMode.default)
        self.media_list_player.play()
        log_message(f"Playing album: {folder_path}")
    
    def play_single(self, track_path):
        self.current_album = None
        self.current_album_folder = None
        self.current_album_tracks = []
        self.current_track_path = track_path
        media_list = self.instance.media_list_new()
        media = self.instance.media_new(track_path)
        if repeat_playback:
            # Duplicate the track so loop mode works reliably.
            media_list.add_media(media)
            media_list.add_media(media)
            self.media_list_player.set_playback_mode(vlc.PlaybackMode.loop)
        else:
            media_list.add_media(media)
            self.media_list_player.set_playback_mode(vlc.PlaybackMode.default)
        self.media_list_player.set_media_list(media_list)
        self.media_list_player.play()
        log_message(f"Playing single track: {track_path}")
    
    def stop(self):
        self.media_list_player.stop()
        self.current_album = None
        self.current_album_folder = None
        self.current_album_tracks = []
        self.current_track_path = None
        log_message("Playback stopped.")
    
    def toggle_play_pause(self):
        # Only toggle play/pause if control USB is present (this check happens externally).
        state = self.media_player.get_state()
        if state == vlc.State.Playing:
            self.media_player.pause()
            log_message("Playback paused.")
        elif state == vlc.State.Paused:
            self.media_player.play()
            log_message("Playback resumed.")
        else:
            self.media_player.play()
            log_message("Playback started.")
    
    def next_track(self):
        self.media_list_player.next()
        log_message("Skipped to next track.")
    
    def previous_track(self):
        self.media_list_player.previous()
        log_message("Skipped to previous track.")
    
    def get_current_media_title(self):
        cur_media = self.media_list_player.get_media_player().get_media()
        if cur_media is not None:
            mrl = cur_media.get_mrl()
            if mrl.startswith("file://"):
                path = mrl[7:]
            else:
                path = mrl
            return format_track_name(path)
        return None

    def get_playback_info(self):
        """Return current playback position and length in seconds"""
        if self.is_active():
            length = self.media_player.get_length() / 1000  # ms to seconds
            position = self.media_player.get_position() * length
            return {
                'position': position,
                'length': length,
                'position_percent': self.media_player.get_position() * 100,
                'position_formatted': self.format_time(position),
                'length_formatted': self.format_time(length)
            }
        return {
            'position': 0, 
            'length': 0, 
            'position_percent': 0,
            'position_formatted': '0:00',
            'length_formatted': '0:00'
        }
    
    def format_time(self, seconds):
        """Format seconds as mm:ss"""
        minutes = int(seconds // 60)
        seconds = int(seconds % 60)
        return f"{minutes}:{seconds:02d}"

    def get_volume(self):
        """Get current volume level"""
        return self.volume

    def set_volume(self, volume):
        """Set volume level (0-100)"""
        if 0 <= volume <= 100:
            self.volume = volume
            self.media_player.audio_set_volume(volume)
            return True
        return False

    def update_repeat_mode(self, repeat_enabled):
        """Update the repeat mode based on the global setting"""
        if repeat_enabled:
            self.media_list_player.set_playback_mode(vlc.PlaybackMode.loop)
        else:
            self.media_list_player.set_playback_mode(vlc.PlaybackMode.default)

# Create a global player instance
player = Player() 