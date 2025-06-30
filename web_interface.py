#!/usr/bin/env python3
"""
Web Interface - Flask web server for USB Music Player
Updated for event-driven architecture with proper USB monitoring
"""

import os
import base64
import time
import json
import glob
from flask import Flask, request, redirect, url_for, jsonify, send_from_directory
from flask_cors import CORS
from config import WEB_PORT, repeat_playback, CONTROL_FILE_NAME
from utils import log_message, format_track_name, log_messages

# Try to import music tag libraries for metadata extraction
try:
    import mutagen
    from mutagen.id3 import ID3
    from mutagen.flac import FLAC
    from mutagen.mp3 import MP3
    METADATA_SUPPORT = True
except ImportError:
    METADATA_SUPPORT = False
    log_message("Mutagen library not found. Album art extraction will be limited.")

def create_app(music_player, usb_monitor):
    """Create Flask app with music player and USB monitor instances"""
    app = Flask(__name__, static_folder='frontend/build')
    CORS(app)  # Enable CORS for all routes
    
    # Store references to the player and monitor
    app.music_player = music_player
    app.usb_monitor = usb_monitor

    def extract_album_art(file_path):
        """Extract album art from audio file metadata or look for cover image in the album folder"""
        if not file_path:
            return None
        
        # URL decode the file path to handle spaces and special characters
        try:
            from urllib.parse import unquote
            decoded_file_path = unquote(file_path)
            
            # Check if the decoded file exists
            if not os.path.exists(decoded_file_path):
                log_message(f"File not found: {decoded_file_path}")
                # Try to get just the album directory
                album_dir = os.path.dirname(decoded_file_path)
                if not os.path.exists(album_dir):
                    log_message(f"Album directory not found: {album_dir}")
                    return None
            else:
                # First, try to extract from metadata if mutagen is available
                if METADATA_SUPPORT:
                    try:
                        if decoded_file_path.lower().endswith('.mp3'):
                            audio = MP3(decoded_file_path)
                            if audio.tags:
                                for tag in audio.tags.values():
                                    if tag.FrameID == 'APIC':  # ID3 picture frame
                                        image_data = tag.data
                                        return f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"
                        
                        elif decoded_file_path.lower().endswith('.flac'):
                            audio = FLAC(decoded_file_path)
                            if audio.pictures:
                                picture = audio.pictures[0]
                                image_data = picture.data
                                return f"data:image/jpeg;base64,{base64.b64encode(image_data).decode('utf-8')}"
                    except Exception as e:
                        log_message(f"Error extracting metadata: {str(e)}")
        
            # If metadata extraction failed or not available, look for cover images in the album folder
            album_dir = os.path.dirname(decoded_file_path)
            
            # Look for common cover image filenames
            cover_filenames = ['cover.jpg', 'cover.png', 'folder.jpg', 'folder.png', 
                               'album.jpg', 'album.png', 'front.jpg', 'front.png',
                               'Cover.jpg', 'Cover.png', 'Folder.jpg', 'Folder.png',
                               'artwork.jpg', 'artwork.png', 'Artwork.jpg', 'Artwork.png',
                               'albumart.jpg', 'albumart.png', 'AlbumArt.jpg', 'AlbumArt.png']
            
            # First try exact matches
            for cover_name in cover_filenames:
                cover_path = os.path.join(album_dir, cover_name)
                if os.path.exists(cover_path):
                    try:
                        with open(cover_path, 'rb') as img_file:
                            img_data = img_file.read()
                            img_type = cover_path.split('.')[-1].lower()
                            return f"data:image/{img_type};base64,{base64.b64encode(img_data).decode('utf-8')}"
                    except Exception as e:
                        log_message(f"Error reading cover file: {str(e)}")
            
            # If no exact matches, look for any image file in the directory
            try:
                for file in os.listdir(album_dir):
                    if file.lower().endswith(('.jpg', '.jpeg', '.png', '.gif')):
                        cover_path = os.path.join(album_dir, file)
                        try:
                            with open(cover_path, 'rb') as img_file:
                                img_data = img_file.read()
                                img_type = cover_path.split('.')[-1].lower()
                                if img_type == 'jpeg':
                                    img_type = 'jpg'
                                return f"data:image/{img_type};base64,{base64.b64encode(img_data).decode('utf-8')}"
                        except Exception as e:
                            log_message(f"Error reading image file {file}: {str(e)}")
            except Exception as e:
                log_message(f"Error listing directory {album_dir}: {str(e)}")
        
        except Exception as e:
            log_message(f"Error processing file path: {str(e)}")
        
        return None

    # API endpoints
    @app.route('/api/player_state')
    def get_player_state():
        """Get current player state and USB status"""
        player = app.music_player
        usb_status = app.usb_monitor.get_current_usb_status()
        
        current_vlc_track = player.get_current_media_title()
        album_tracks = []
        if player.current_album and player.current_album_tracks:
            album_tracks = [format_track_name(track) for track in player.current_album_tracks]
        
        # Get current track path for album art extraction
        current_track_path = None
        album_dir = None
        
        # First try to get the path from the player
        if player.current_track_path:
            current_track_path = player.current_track_path
            album_dir = os.path.dirname(player.current_track_path)
        elif player.current_album_folder:
            # If we have the album folder but not the specific track
            album_dir = player.current_album_folder
        elif player.current_album_tracks and player.media_player.get_media():
            # Try to determine which track is currently playing
            media_path = player.media_player.get_media().get_mrl()
            if media_path.startswith('file://'):
                media_path = media_path[7:]
            current_track_path = media_path
        
        # Extract album art
        album_image = None
        if current_track_path:
            album_image = extract_album_art(current_track_path)
        elif album_dir:
            # If we only have the album directory, try to find any image in it
            album_image = extract_album_art(os.path.join(album_dir, "dummy.mp3"))
        
        # Get playback position information
        playback_info = player.get_playback_info()
        
        return jsonify({
            'currentAlbum': player.current_album,
            'currentTrack': current_vlc_track,
            'albumTracks': album_tracks,
            'volume': player.get_volume(),
            'isPlaying': player.is_playing(),
            'repeatPlayback': repeat_playback,
            'logs': log_messages[-50:],
            'albumImage': album_image,
            'position': playback_info['position'],
            'length': playback_info['length'],
            'usbStatus': {
                'musicUsb': usb_status['music_usb'],
                'controlUsb': usb_status['control_usb'],
                'monitoring': usb_status['monitoring']
            }
        })

    @app.route('/api/toggle_repeat_playback', methods=['POST'])
    def toggle_repeat_playback():
        global repeat_playback
        repeat_playback = not repeat_playback
        log_message(f"repeat_playback toggled to {repeat_playback}")
        app.music_player.update_repeat_mode(repeat_playback)
        return jsonify({'success': True})

    @app.route('/api/toggle_play_pause', methods=['POST'])
    def toggle_play_pause():
        """Toggle play/pause - only works if control USB is present"""
        if app.music_player.control_source:
            app.music_player.toggle_play_pause()
            return jsonify({'success': True})
        else:
            log_message("Play/Pause toggle ignored: No PLAY_CARD present")
            return jsonify({'success': False, 'error': 'No control USB present'})

    @app.route('/api/next_track', methods=['POST'])
    def next_track():
        """Skip to next track - only works if control USB is present"""
        if app.music_player.control_source:
            app.music_player.next_track()
            return jsonify({'success': True})
        else:
            log_message("Next track ignored: No PLAY_CARD present")
            return jsonify({'success': False, 'error': 'No control USB present'})

    @app.route('/api/prev_track', methods=['POST'])
    def prev_track():
        """Skip to previous track - only works if control USB is present"""
        if app.music_player.control_source:
            app.music_player.previous_track()
            return jsonify({'success': True})
        else:
            log_message("Previous track ignored: No PLAY_CARD present")
            return jsonify({'success': False, 'error': 'No control USB present'})

    @app.route('/api/set_volume/<int:volume>', methods=['POST'])
    def set_volume(volume):
        """Set volume level"""
        success = app.music_player.set_volume(volume)
        return jsonify({'success': success})

    @app.route('/health')
    def health_check():
        """Health check endpoint"""
        usb_status = app.usb_monitor.get_current_usb_status()
        return jsonify({
            'status': 'healthy',
            'music_usb': usb_status['music_usb'] is not None,
            'control_usb': usb_status['control_usb'] is not None,
            'monitoring': usb_status['monitoring']
        })

    @app.route('/', defaults={'path': ''})
    @app.route('/<path:path>')
    def serve(path):
        """Serve static files"""
        if path != "" and os.path.exists(os.path.join(app.static_folder, path)):
            return send_from_directory(app.static_folder, path)
        else:
            return send_from_directory(app.static_folder, 'index.html')

    @app.route('/write_control', methods=['POST'])
    def write_control():
        """Write control file to USB"""
        try:
            data = request.get_json()
            content = data.get('content', '')
            
            if not app.music_player.control_source:
                return jsonify({'success': False, 'error': 'No control USB present'})
            
            control_file_path = os.path.join(app.music_player.control_source, CONTROL_FILE_NAME)
            
            with open(control_file_path, 'w') as f:
                f.write(content)
            
            log_message(f"Control file written: {content}")
            return jsonify({'success': True})
            
        except Exception as e:
            log_message(f"Error writing control file: {str(e)}")
            return jsonify({'success': False, 'error': str(e)})

    @app.route('/clear_control', methods=['POST'])
    def clear_control():
        """Clear control file from USB"""
        try:
            if not app.music_player.control_source:
                return jsonify({'success': False, 'error': 'No control USB present'})
            
            control_file_path = os.path.join(app.music_player.control_source, CONTROL_FILE_NAME)
            
            if os.path.exists(control_file_path):
                os.remove(control_file_path)
                log_message("Control file cleared")
            
            return jsonify({'success': True})
            
        except Exception as e:
            log_message(f"Error clearing control file: {str(e)}")
            return jsonify({'success': False, 'error': str(e)})

    @app.route('/read_control')
    def read_control():
        """Read current control file content"""
        try:
            if not app.music_player.control_source:
                return jsonify({'success': False, 'error': 'No control USB present'})
            
            control_file_path = os.path.join(app.music_player.control_source, CONTROL_FILE_NAME)
            
            if os.path.exists(control_file_path):
                with open(control_file_path, 'r') as f:
                    content = f.read().strip()
                return jsonify({'success': True, 'content': content})
            else:
                return jsonify({'success': True, 'content': ''})
                
        except Exception as e:
            log_message(f"Error reading control file: {str(e)}")
            return jsonify({'success': False, 'error': str(e)})

    @app.route('/debug/usb')
    def debug_usb():
        """Debug endpoint for USB status"""
        usb_status = app.usb_monitor.get_current_usb_status()
        player_status = app.music_player.get_status()
        
        return jsonify({
            'usb_monitor': usb_status,
            'music_player': player_status,
            'logs': log_messages[-20:]
        })

    return app 