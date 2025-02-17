#!/usr/bin/env python3
import os
import time
import vlc
import glob
import threading
from flask import Flask, render_template_string, request, redirect, url_for
from urllib.parse import unquote

# ------------- CONFIG -------------
MUSIC_USB_MOUNT = "/media/pi/MUSIC"
CONTROL_USB_MOUNT = "/media/pi/PLAY_CARD"
CONTROL_FILE_NAME = "playMusic.txt"

# Global log and status variables
log_messages = []
current_status = {"playing": False, "track_or_folder": None}

# Extended info for albums:
current_album_name = None         # Stores the current album folder name (if album playback)
current_album_folder = None       # Stores the full folder path for the album.
current_album_tracks = []         # List of audio file paths in the current album

# Global flags for player settings:
stop_on_unmount = True      # If True, when PLAY_CARD is unmounted, playback stops.
repeat_playback = True     # If True, the album/track repeats after finishing.

# Initialize VLC
instance = vlc.Instance()
media_list_player = instance.media_list_player_new()
media_player = instance.media_player_new()
media_list_player.set_media_player(media_player)

def log_message(msg):
    """Store a log message and print it to stdout."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    message = f"[{timestamp}] {msg}"
    log_messages.append(message)
    print(message)

def usb_is_mounted(mount_path):
    if not os.path.ismount(mount_path):
        return False
    try:
        os.listdir(mount_path)
        return True
    except OSError:
        return False

def format_track_name(filename):
    """
    Decode a URL-encoded filename, get its basename, and remove the extension.
    """
    decoded = unquote(filename)
    base = os.path.basename(decoded)
    base_without_ext, _ = os.path.splitext(base)
    return base_without_ext

def play_tracks_from_folder(folder_path):
    """
    Gather all audio files from 'folder_path' (including subfolders)
    and play them in sequence. Also store album info for UI.
    """
    global current_album_name, current_album_folder, current_album_tracks
    audio_files = []
    # Escape folder path so special characters (like brackets) are literal.
    escaped_folder = glob.escape(folder_path)
    patterns = ["*.mp3", "*.MP3", "*.wav", "*.WAV", "*.flac", "*.FLAC"]
    for pattern in patterns:
        search_pattern = os.path.join(escaped_folder, "**", pattern)
        found = glob.glob(search_pattern, recursive=True)
        audio_files += found
    log_message(f"Found audio files: {audio_files}")
    if not audio_files:
        log_message(f"No audio files found in {folder_path} or its subfolders.")
        return
    current_album_name = os.path.basename(folder_path)
    current_album_folder = folder_path  # Save the folder path.
    current_album_tracks = audio_files
    media_list = instance.media_list_new()
    for audio_file in audio_files:
        media = instance.media_new(audio_file)
        media_list.add_media(media)
    media_list_player.set_media_list(media_list)
    if repeat_playback:
        media_list_player.set_playback_mode(vlc.PlaybackMode.loop)
    else:
        media_list_player.set_playback_mode(vlc.PlaybackMode.default)
    media_list_player.play()
    current_status["playing"] = True
    current_status["track_or_folder"] = os.path.basename(folder_path)
    log_message(f"Playing folder (recursive): {folder_path}")

def play_single_track(track_path):
    """Play a single audio file by its full path using a media list with one item."""
    global current_album_name, current_album_folder, current_album_tracks
    current_album_name = None
    current_album_folder = None
    current_album_tracks = []
    media_list = instance.media_list_new()
    media = instance.media_new(track_path)
    media_list.add_media(media)
    media_list_player.set_media_list(media_list)
    if repeat_playback:
        media_list_player.set_playback_mode(vlc.PlaybackMode.loop)
    else:
        media_list_player.set_playback_mode(vlc.PlaybackMode.default)
    media_list_player.play()
    current_status["playing"] = True
    current_status["track_or_folder"] = os.path.basename(track_path)
    log_message(f"Playing single track: {track_path}")

def find_album_folder(album_name):
    """
    Search recursively under MUSIC_USB_MOUNT for a directory whose name matches album_name.
    Special characters in album_name are escaped and a wildcard is appended so that the search 
    matches directories whose name starts with album_name.
    Returns the first matching directory or None.
    """
    escaped_album = f"{glob.escape(album_name)}*"
    pattern = os.path.join(MUSIC_USB_MOUNT, "**", escaped_album)
    matching_dirs = glob.glob(pattern, recursive=True)
    for d in matching_dirs:
        if os.path.isdir(d):
            return d
    return None

def get_current_media_title():
    """
    Retrieve the currently playing media's filename from VLC,
    decode it, remove the file extension, and return it.
    """
    cur_media = media_list_player.get_media_player().get_media()
    if cur_media is not None:
        mrl = cur_media.get_mrl()
        if mrl.startswith("file://"):
            path = mrl[7:]
        else:
            path = mrl
        return format_track_name(path)
    return None

def stop_playback():
    """
    Stop playback and clear the current status.
    """
    global current_album_name, current_album_folder, current_album_tracks
    media_list_player.stop()
    current_status["playing"] = False
    current_status["track_or_folder"] = None
    current_album_name = None
    current_album_folder = None
    current_album_tracks = []
    log_message("Stopped playback.")

def main_loop():
    """
    Monitor the CONTROL_USB_MOUNT. When the USB is mounted, read the control file
    and start new playback. When the USB is unmounted, stop playback (if stop_on_unmount is True).
    """
    previously_mounted = False
    while True:
        if usb_is_mounted(CONTROL_USB_MOUNT):
            if not previously_mounted:
                log_message("Control USB mounted.")
                previously_mounted = True
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
                            stop_playback()
                            play_tracks_from_folder(target_folder)
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
                            stop_playback()
                            play_single_track(matching_tracks[0])
                        else:
                            log_message(f"No matching track named '{track_name}' found in {MUSIC_USB_MOUNT}.")
                    else:
                        log_message("Error: playMusic.txt not in valid format. Use 'Album: <folder>' or 'Track: <filename>'.")
                else:
                    log_message(f"{CONTROL_FILE_NAME} not found on Control USB.")
        else:
            if previously_mounted:
                log_message("Control USB unmounted.")
                previously_mounted = False
                if stop_on_unmount:
                    log_message("Stop on unmount is True, stopping playback.")
                    stop_playback()
                else:
                    log_message("Stop on unmount is False, continuing playback.")
        time.sleep(2)

# ---------------- FLASK WEB INTERFACE ----------------
app = Flask(__name__)

@app.route('/')
def index():
    """
    Display a UI that shows:
      - "Currently Playing:" information:
          - If an album is playing, display the album name.
          - The current track playing in VLC.
          - A control button for toggling Repeat Playback (under the album/track info).
      - "List of tracks in folder:" if an album is playing.
      - At the bottom, a control button for toggling Stop On Unmount.
      - Log messages.
    """
    current_vlc_track = get_current_media_title()
    album_tracks = []
    if current_album_name and current_album_tracks:
        album_tracks = [format_track_name(track) for track in current_album_tracks]
    html = """
    <html>
    <head>
        <title>Raspberry Pi Music Player</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            h2 { margin-bottom: 5px; }
            .control { margin-bottom: 15px; }
        </style>
    </head>
    <body>
        <h1>Music Player Status</h1>
        
        <h2>Currently Playing:</h2>
        {% if current_album %}
            <p>Album: {{ current_album }}</p>
        {% endif %}
        {% if current_vlc_track %}
            <p>Track: {{ current_vlc_track }}</p>
        {% else %}
            <p>Nothing playing</p>
        {% endif %}
        <div class="control">
            <form method="POST" action="/toggle_repeat_playback">
                <button type="submit">Toggle Repeat Playback (Currently: {% if repeat_playback %}Enabled{% else %}Disabled{% endif %})</button>
            </form>
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
            <form method="POST" action="/toggle_stop_on_unmount">
                <button type="submit">Toggle Stop On Unmount (Currently: {% if stop_on_unmount %}Enabled{% else %}Disabled{% endif %})</button>
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
        current_album=current_album_name,
        current_vlc_track=current_vlc_track,
        album_tracks=album_tracks,
        logs=log_messages[-50:],
        stop_on_unmount=stop_on_unmount,
        repeat_playback=repeat_playback
    )

@app.route('/toggle_stop_on_unmount', methods=['POST'])
def toggle_stop_on_unmount():
    global stop_on_unmount
    stop_on_unmount = not stop_on_unmount
    log_message(f"stop_on_unmount toggled to {stop_on_unmount}")
    return redirect(url_for('index'))

@app.route('/toggle_repeat_playback', methods=['POST'])
def toggle_repeat_playback():
    global repeat_playback
    repeat_playback = not repeat_playback
    log_message(f"repeat_playback toggled to {repeat_playback}")
    return redirect(url_for('index'))

def start_flask_app():
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)

if __name__ == "__main__":
    flask_thread = threading.Thread(target=start_flask_app, daemon=True)
    flask_thread.start()
    main_loop()