#!/usr/bin/env python3
# web_interface.py

import os
import base64
import time
import json
import glob
from flask import Flask, request, redirect, url_for, jsonify, send_from_directory
from flask_cors import CORS
from config import WEB_PORT, repeat_playback, CONTROL_FILE_NAME
from player import player
from utils import (
    log_message, find_music_usb, find_control_usb_with_retry, usb_is_mounted, format_track_name,
    find_album_folder, log_messages
)

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
    control_usb = find_control_usb_with_retry()
    if control_usb:
        player.toggle_play_pause()
    else:
        log_message("Play/Pause toggle ignored: No PLAY_CARD present.")
    return jsonify({'success': True})

@app.route('/api/next_track', methods=['POST'])
def next_track():
    control_usb = find_control_usb_with_retry()
    if control_usb:
        player.next_track()
    else:
        log_message("Next track ignored: No PLAY_CARD present.")
    return jsonify({'success': True})

@app.route('/api/prev_track', methods=['POST'])
def prev_track():
    control_usb = find_control_usb_with_retry()
    if control_usb:
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

@app.route('/write_control', methods=['POST'])
def write_control():
    """Write a track request to the control file on the control USB."""
    request_line = request.form.get('request')
    
    if not request_line:
        return jsonify({"status": "error", "message": "No request provided"})
    
    control_usb = find_control_usb_with_retry()
    if not control_usb:
        return jsonify({"status": "error", "message": "Control USB not found"})
    
    control_file_path = os.path.join(control_usb, CONTROL_FILE_NAME)
    
    try:
        with open(control_file_path, "w") as f:
            f.write(request_line)
        log_message(f"Written to control file: {request_line}")
        return jsonify({"status": "success", "message": f"Written: {request_line}"})
    except Exception as e:
        log_message(f"Failed to write to control file: {str(e)}")
        return jsonify({"status": "error", "message": f"Failed to write: {str(e)}"})

@app.route('/clear_control', methods=['POST'])
def clear_control():
    """Clear the control file."""
    control_usb = find_control_usb_with_retry()
    if not control_usb:
        return jsonify({"status": "error", "message": "Control USB not found"})
    
    control_file_path = os.path.join(control_usb, CONTROL_FILE_NAME)
    
    try:
        with open(control_file_path, "w") as f:
            f.write("")
        log_message("Control file cleared")
        return jsonify({"status": "success", "message": "Control file cleared"})
    except Exception as e:
        log_message(f"Failed to clear control file: {str(e)}")
        return jsonify({"status": "error", "message": f"Failed to clear: {str(e)}"})

@app.route('/read_control')
def read_control():
    """Read the current control file content."""
    control_usb = find_control_usb_with_retry()
    if not control_usb:
        return jsonify({"status": "error", "message": "Control USB not found", "content": ""})
    
    control_file_path = os.path.join(control_usb, CONTROL_FILE_NAME)
    
    try:
        if os.path.isfile(control_file_path):
            with open(control_file_path, "r") as f:
                content = f.read().strip()
            return jsonify({"status": "success", "content": content})
        else:
            return jsonify({"status": "error", "message": "Control file not found", "content": ""})
    except Exception as e:
        log_message(f"Failed to read control file: {str(e)}")
        return jsonify({"status": "error", "message": f"Failed to read: {str(e)}", "content": ""})

@app.route('/debug/usb')
def debug_usb():
    """Debug endpoint to check USB detection status."""
    debug_info = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "music_usb": None,
        "control_usb": None,
        "bind_mounts": {},
        "mount_points": [],
        "control_file_status": "not_found"
    }
    
    try:
        # Check music USB
        music_usb = find_music_usb()
        if music_usb:
            debug_info["music_usb"] = {
                "path": music_usb,
                "mounted": usb_is_mounted(music_usb),
                "exists": os.path.exists(music_usb)
            }
        
        # Check control USB
        control_usb = find_control_usb_with_retry(max_retries=1)  # Quick check for debug
        if control_usb:
            control_file_path = os.path.join(control_usb, CONTROL_FILE_NAME)
            debug_info["control_usb"] = {
                "path": control_usb,
                "mounted": usb_is_mounted(control_usb),
                "exists": os.path.exists(control_usb),
                "control_file_exists": os.path.isfile(control_file_path)
            }
            
            if os.path.isfile(control_file_path):
                debug_info["control_file_status"] = "found"
                try:
                    with open(control_file_path, "r") as f:
                        debug_info["control_file_content"] = f.read().strip()
                except Exception as e:
                    debug_info["control_file_content"] = f"Error reading: {str(e)}"
        
        # Check bind mount directories
        bind_base = "/home/pi/usb"
        if os.path.exists(bind_base):
            for item in os.listdir(bind_base):
                item_path = os.path.join(bind_base, item)
                if os.path.isdir(item_path):
                    debug_info["bind_mounts"][item] = {
                        "path": item_path,
                        "mounted": usb_is_mounted(item_path),
                        "exists": os.path.exists(item_path),
                        "contents": []
                    }
                    try:
                        contents = os.listdir(item_path)
                        debug_info["bind_mounts"][item]["contents"] = contents[:10]  # First 10 items
                    except Exception as e:
                        debug_info["bind_mounts"][item]["contents"] = [f"Error: {str(e)}"]
        
        # Check /media/pi mount points
        media_pi = "/media/pi"
        if os.path.exists(media_pi):
            for item in os.listdir(media_pi):
                item_path = os.path.join(media_pi, item)
                if os.path.isdir(item_path):
                    mount_info = {
                        "name": item,
                        "path": item_path,
                        "mounted": os.path.ismount(item_path),
                        "accessible": False,
                        "contents_count": 0
                    }
                    try:
                        contents = os.listdir(item_path)
                        mount_info["accessible"] = True
                        mount_info["contents_count"] = len(contents)
                        # Check for control file
                        control_file = os.path.join(item_path, CONTROL_FILE_NAME)
                        mount_info["has_control_file"] = os.path.isfile(control_file)
                    except Exception as e:
                        mount_info["error"] = str(e)
                    
                    debug_info["mount_points"].append(mount_info)
        
    except Exception as e:
        debug_info["error"] = str(e)
    
    return jsonify(debug_info)

def start_flask_app():
    app.run(host='0.0.0.0', port=WEB_PORT, debug=False, use_reloader=False) 