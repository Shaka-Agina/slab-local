#!/usr/bin/env python3
# web_interface.py

import os
import base64
import time
from flask import Flask, request, redirect, url_for, jsonify, send_from_directory
from flask_cors import CORS
from config import WEB_PORT, CONTROL_USB_MOUNT, repeat_playback
from player import player
from utils import log_message, usb_is_mounted, format_track_name, log_messages

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

# Flask web interface
app = Flask(__name__, static_folder='frontend/build')
CORS(app)  # Enable CORS for all routes

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
        'length': playback_info['length']
    })

@app.route('/api/toggle_repeat_playback', methods=['POST'])
def toggle_repeat_playback():
    global repeat_playback
    repeat_playback = not repeat_playback
    log_message(f"repeat_playback toggled to {repeat_playback}")
    player.update_repeat_mode(repeat_playback)
    return jsonify({'success': True})

@app.route('/api/toggle_play_pause', methods=['POST'])
def toggle_play_pause():
    # Only allow play/pause if the control USB is present.
    if usb_is_mounted(CONTROL_USB_MOUNT):
        player.toggle_play_pause()
    else:
        log_message("Play/Pause toggle ignored: No PLAY_CARD present.")
    return jsonify({'success': True})

@app.route('/api/next_track', methods=['POST'])
def next_track():
    if usb_is_mounted(CONTROL_USB_MOUNT):
        player.next_track()
    else:
        log_message("Next track ignored: No PLAY_CARD present.")
    return jsonify({'success': True})

@app.route('/api/prev_track', methods=['POST'])
def prev_track():
    if usb_is_mounted(CONTROL_USB_MOUNT):
        player.previous_track()
    else:
        log_message("Previous track ignored: No PLAY_CARD present.")
    return jsonify({'success': True})

@app.route('/api/set_volume/<int:volume>', methods=['POST'])
def set_volume(volume):
    if player.set_volume(volume):
        log_message(f"Volume set to {volume}%")
    return jsonify({'success': True})

# Health check endpoint for Docker
@app.route('/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'usb-music-player',
        'timestamp': int(time.time())
    }), 200

# Serve React App
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    if path != "" and os.path.exists(os.path.join(app.static_folder, path)):
        return send_from_directory(app.static_folder, path)
    else:
        return send_from_directory(app.static_folder, 'index.html')

def start_flask_app():
    app.run(host='0.0.0.0', port=WEB_PORT, debug=False, use_reloader=False) 