#!/usr/bin/env python3
#player.py

import os
import time
import vlc
import glob
import threading
from flask import Flask, render_template_string, request, redirect, url_for
from urllib.parse import unquote
import configparser

# ------------- CONFIG -------------
def load_config():
    config = configparser.ConfigParser()
    config['DEFAULT'] = {
        'MUSIC_USB_MOUNT': '/media/pi/MUSIC',
        'CONTROL_USB_MOUNT': '/media/pi/PLAY_CARD',
        'CONTROL_FILE_NAME': 'playMusic.txt',
        'WEB_PORT': '5000',
        'DEFAULT_VOLUME': '70'
    }
    
    if os.path.exists('config.ini'):
        config.read('config.ini')
    else:
        with open('config.ini', 'w') as f:
            config.write(f)
    
    return config['DEFAULT']

# Then use the config values
config = load_config()
MUSIC_USB_MOUNT = config['MUSIC_USB_MOUNT']
CONTROL_USB_MOUNT = config['CONTROL_USB_MOUNT']
CONTROL_FILE_NAME = config['CONTROL_FILE_NAME']
WEB_PORT = int(config['WEB_PORT'])
DEFAULT_VOLUME = int(config['DEFAULT_VOLUME'])

# Global log variable
log_messages = []

# Global flag for repeat playback:
repeat_playback = True      # If True, playback loops.

def log_message(msg):
    """Log a message with a timestamp."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] {msg}"
    log_messages.append(message)
    print(message)

def usb_is_mounted(mount_path):
    """Return True if mount_path is mounted, else False."""
    if not os.path.ismount(mount_path):
        return False
    try:
        os.listdir(mount_path)
        return True
    except OSError:
        return False

def format_track_name(filename):
    """Decode URL-encoded filename and return its basename without extension."""
    decoded = unquote(filename)
    base = os.path.basename(decoded)
    base_without_ext, _ = os.path.splitext(base)
    return base_without_ext

def find_album_folder(album_name):
    """Recursively search MUSIC_USB_MOUNT for a folder whose name starts with album_name."""
    # Check if MUSIC_USB_MOUNT exists first
    if not usb_is_mounted(MUSIC_USB_MOUNT):
        log_message(f"Music USB not mounted at {MUSIC_USB_MOUNT}")
        return None
        
    escaped_album = f"{glob.escape(album_name)}*"
    pattern = os.path.join(MUSIC_USB_MOUNT, "**", escaped_album)
    matching_dirs = glob.glob(pattern, recursive=True)
    for d in matching_dirs:
        if os.path.isdir(d):
            return d
    return None

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

# Global Player instance
player = Player()

def main_loop():
    """
    Monitor the control USB:
      - On a fresh mount event (transition from unmounted to mounted),
        always stop current playback and re-read the control file to start new playback.
      - On unmount, always stop playback.
    """
    previously_mounted = False
    while True:
        if usb_is_mounted(CONTROL_USB_MOUNT):
            if not previously_mounted:
                log_message("Control USB mounted. Restarting playback from control file.")
                previously_mounted = True
                player.stop()
                control_file_path = os.path.join(CONTROL_USB_MOUNT, CONTROL_FILE_NAME)
                if os.path.isfile(control_file_path):
                    with open(control_file_path, "r") as f:
                        request_line = f.read().strip()
                    log_message(f"Requested line: {request_line}")
                    if request_line.startswith("Album:"):
                        album_name = request_line.replace("Album:", "").strip()
                        log_message(f"Album requested: {album_name}")
                        target_folder = find_album_folder(album_name)
                        if target_folder:
                            player.play_album(target_folder)
                        else:
                            log_message(f"No matching album folder named '{album_name}' found.")
                    elif request_line.startswith("Track:"):
                        track_name = request_line.replace("Track:", "").strip()
                        log_message(f"Track requested: {track_name}")
                        escaped_track = glob.escape(track_name)
                        matching_tracks = glob.glob(
                            os.path.join(MUSIC_USB_MOUNT, "**", f"{escaped_track}*"),
                            recursive=True
                        )
                        if matching_tracks:
                            player.play_single(matching_tracks[0])
                        else:
                            log_message(f"No matching track named '{track_name}' found in {MUSIC_USB_MOUNT}.")
                    else:
                        log_message("Error: playMusic.txt not in valid format. Use 'Album: <folder>' or 'Track: <filename>'.")
                else:
                    log_message(f"{CONTROL_FILE_NAME} not found on Control USB.")
        else:
            if previously_mounted:
                log_message("Control USB unmounted. Stopping playback.")
                previously_mounted = False
                player.stop()
        time.sleep(2)

# Flask web interface
app = Flask(__name__)

@app.route('/')
def index():
    current_vlc_track = player.get_current_media_title()
    album_tracks = []
    if player.current_album and player.current_album_tracks:
        album_tracks = [format_track_name(track) for track in player.current_album_tracks]
    playback_info = player.get_playback_info()
    html = """
    <html>
    <head>
        <title>Raspberry Pi Music Player</title>
        <meta http-equiv="refresh" content="10">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            h2 { margin-bottom: 5px; }
            .control { margin-bottom: 15px; }
            .player-controls form { display: inline-block; margin-right: 10px; }
        </style>
    </head>
    <body>
        <h1>Music Player Status</h1>
        
        <h2>Currently Playing:</h2>
        {% if player_current_album %}
            <p>Album: {{ player_current_album }}</p>
        {% endif %}
        {% if current_vlc_track %}
            <p>Track: {{ current_vlc_track }}</p>
        {% else %}
            <p>Nothing playing</p>
        {% endif %}
        
        <div class="player-controls control">
            <form method="POST" action="/toggle_play_pause">
                <button type="submit">Play/Pause</button>
            </form>
            <form method="POST" action="/next_track">
                <button type="submit">Next Track</button>
            </form>
            <form method="POST" action="/prev_track">
                <button type="submit">Previous Track</button>
            </form>
            <form method="POST" action="/set_volume/0">
                <button type="submit">Mute</button>
            </form>
            <form method="POST" action="/set_volume/30">
                <button type="submit">Low</button>
            </form>
            <form method="POST" action="/set_volume/70">
                <button type="submit">Medium</button>
            </form>
            <form method="POST" action="/set_volume/100">
                <button type="submit">High</button>
            </form>
            <span>Current Volume: {{ player_volume }}%</span>
        </div>
        
        {% if album_tracks %}
            <h2>List of tracks in folder:</h2>
            <ul>
            {% for t in album_tracks %}
                <li>{{ t }}</li>
            {% endfor %}
            </ul>
        {% endif %}
        
        <div class="control">
            <form method="POST" action="/toggle_repeat_playback">
                <button type="submit">Toggle Repeat Playback (Currently: {% if repeat_playback %}Enabled{% else %}Disabled{% endif %})</button>
            </form>
        </div>
        
        <hr>
        <h3>Log Messages (most recent last)</h3>
        <pre>
{% for msg in logs %}
{{ msg }}
{% endfor %}
        </pre>
    </body>
    </html>
    """
    return render_template_string(
        html,
        player_current_album=player.current_album,
        current_vlc_track=current_vlc_track,
        album_tracks=album_tracks,
        logs=log_messages[-50:],
        repeat_playback=repeat_playback,
        player_volume=player.get_volume(),
        playback_info=playback_info
    )

@app.route('/toggle_repeat_playback', methods=['POST'])
def toggle_repeat_playback():
    global repeat_playback
    repeat_playback = not repeat_playback
    log_message(f"repeat_playback toggled to {repeat_playback}")
    if repeat_playback:
        player.media_list_player.set_playback_mode(vlc.PlaybackMode.loop)
    else:
        player.media_list_player.set_playback_mode(vlc.PlaybackMode.default)
    return redirect(url_for('index'))

@app.route('/toggle_play_pause', methods=['POST'])
def toggle_play_pause():
    # Only allow play/pause if the control USB is present.
    if usb_is_mounted(CONTROL_USB_MOUNT):
        player.toggle_play_pause()
    else:
        log_message("Play/Pause toggle ignored: No PLAY_CARD present.")
    return redirect(url_for('index'))

@app.route('/next_track', methods=['POST'])
def next_track():
    if usb_is_mounted(CONTROL_USB_MOUNT):
        player.next_track()
    else:
        log_message("Next track ignored: No PLAY_CARD present.")
    return redirect(url_for('index'))

@app.route('/prev_track', methods=['POST'])
def prev_track():
    if usb_is_mounted(CONTROL_USB_MOUNT):
        player.previous_track()
    else:
        log_message("Previous track ignored: No PLAY_CARD present.")
    return redirect(url_for('index'))

@app.route('/set_volume/<int:volume>', methods=['POST'])
def set_volume(volume):
    if player.set_volume(volume):
        log_message(f"Volume set to {volume}%")
    return redirect(url_for('index'))

def start_flask_app():
    app.run(host='0.0.0.0', port=WEB_PORT, debug=False, use_reloader=False)

if __name__ == "__main__":
    flask_thread = threading.Thread(target=start_flask_app, daemon=True)
    flask_thread.start()
    main_loop()