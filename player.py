#!/usr/bin/env python3

import os
import time
import vlc
import glob
import threading
from flask import Flask, render_template_string, request, redirect, url_for

# ------------- CONFIG -------------
MUSIC_USB_MOUNT = "/media/pi/MUSIC"
CONTROL_USB_MOUNT = "/media/pi/PLAY_CARD"
CONTROL_FILE_NAME = "playMusic.txt"

# Global log and status variables
log_messages = []
current_status = {"playing": False, "track_or_folder": None}

# Extended info for albums:
current_album_name = None         # Stores the current album folder name
current_album_tracks = []         # List of audio file paths in the current album

# Global flag to decide if we stop playback on USB removal.
stop_on_unmount = True  # default True

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
    # First check if it's reported as a mount
    if not os.path.ismount(mount_path):
        return False
    # Then try listing its contents in a try/except
    try:
        _ = os.listdir(mount_path)
        return True
    except OSError:
        # If we get an OSError (e.g., "No such device"), it's not really mounted
        return False

def stop_playback():
    """Stop any ongoing playback and clear status."""
    global current_album_name, current_album_tracks
    media_list_player.stop()
    current_status["playing"] = False
    current_status["track_or_folder"] = None
    current_album_name = None
    current_album_tracks = []
    log_message("Stopped playback.")

def play_tracks_from_folder(folder_path):
    """
    Gather all audio files from 'folder_path' (including subfolders) 
    and play them in sequence.
    """
    global current_album_name, current_album_tracks

    audio_files = []
    # Escape the folder path so that special characters (like brackets)
    # are treated literally in the glob pattern.
    escaped_folder = glob.escape(folder_path)
    # Patterns for common audio file extensions
    patterns = ["*.mp3", "*.MP3", "*.wav", "*.WAV", "*.flac", "*.FLAC"]
    for pattern in patterns:
        # Build the pattern using the escaped folder
        search_pattern = os.path.join(escaped_folder, "**", pattern)
        found = glob.glob(search_pattern, recursive=True)
        audio_files += found

    log_message(f"Found audio files: {audio_files}")

    if not audio_files:
        log_message(f"No audio files found in {folder_path} or its subfolders.")
        return

    # Store album info for the UI
    current_album_name = os.path.basename(folder_path)
    current_album_tracks = audio_files

    # Create a new media list for VLC
    media_list = instance.media_list_new()
    for audio_file in audio_files:
        media = instance.media_new(audio_file)
        media_list.add_media(media)

    media_list_player.set_media_list(media_list)
    media_list_player.play()

    current_status["playing"] = True
    current_status["track_or_folder"] = os.path.basename(folder_path)
    log_message(f"Playing folder (recursive): {folder_path}")

def play_single_track(track_path):
    """Play a single audio file by its full path."""
    global current_album_name, current_album_tracks
    # Clear album info since we're playing a single track
    current_album_name = None
    current_album_tracks = []
    media = instance.media_new(track_path)
    media_player.set_media(media)
    media_player.play()
    current_status["playing"] = True
    current_status["track_or_folder"] = os.path.basename(track_path)
    log_message(f"Playing single track: {track_path}")

def find_album_folder(album_name):
    """
    Search recursively under MUSIC_USB_MOUNT for a directory whose name matches album_name.
    Special characters (such as brackets) in album_name are escaped and a wildcard is appended
    so that the search matches directories whose name starts with album_name.
    Returns the first matching directory or None.
    """
    # Escape special characters and append a wildcard
    escaped_album = f"{glob.escape(album_name)}*"
    pattern = os.path.join(MUSIC_USB_MOUNT, "**", escaped_album)
    matching_dirs = glob.glob(pattern, recursive=True)
    for d in matching_dirs:
        if os.path.isdir(d):
            return d
    return None

def main_loop():
    """
    Monitors the CONTROL_USB_MOUNT. When mounted, reads 'playMusic.txt'
    and tries to play an album or track. On unmount, optionally stops playback
    if 'stop_on_unmount' is True.
    """
    previously_mounted = False

    while True:
        if usb_is_mounted(CONTROL_USB_MOUNT):
            if not previously_mounted:
                # Just inserted
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
                        # Escape special characters for glob search
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
                        log_message(
                            "Error: playMusic.txt not in valid format. "
                            "Use 'Album: <folder>' or 'Track: <filename>'."
                        )
                else:
                    log_message(f"{CONTROL_FILE_NAME} not found on Control USB.")

        else:
            # USB is not mounted
            if previously_mounted:
                log_message("Control USB unmounted.")
                previously_mounted = False

                if stop_on_unmount:
                    log_message("Stop on unmount is True, stopping playback.")
                    stop_playback()
                else:
                    log_message("Stop on unmount is False, continuing playback.")

        time.sleep(2)  # Poll every 2 seconds

# ---------------- FLASK WEB INTERFACE ----------------
app = Flask(__name__)

@app.route('/')
def index():
    """
    Display a simple log view, current status, and a list of tracks (if an album is playing),
    plus a button to toggle whether we stop on unmount or not.
    """
    album_tracks_list = ""
    if current_album_name and current_album_tracks:
        # Create an HTML list of track basenames
        album_tracks_list += "<h3>Tracks in Album: " + current_album_name + "</h3><ul>"
        for track in current_album_tracks:
            album_tracks_list += "<li>" + os.path.basename(track) + "</li>"
        album_tracks_list += "</ul>"
    
    html = """
    <html>
    <head>
        <title>Raspberry Pi Music Player</title>
    </head>
    <body>
        <h1>Music Player Status</h1>
        <p>Currently playing: {% if current_track %} {{ current_track }} {% else %} Nothing {% endif %}</p>
        <p>Stop On Unmount: <strong>{% if stop_on_unmount %}Enabled{% else %}Disabled{% endif %}</strong></p>
        
        <!-- Form to toggle stop_on_unmount -->
        <form method="POST" action="/toggle_stop_on_unmount">
            <button type="submit">Toggle Stop On Unmount</button>
        </form>
        
        {{ album_tracks_list|safe }}
        
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
        current_track=current_status["track_or_folder"] if current_status["playing"] else None,
        logs=log_messages[-50:],
        stop_on_unmount=stop_on_unmount,
        album_tracks_list=album_tracks_list
    )

@app.route('/toggle_stop_on_unmount', methods=['POST'])
def toggle_stop_on_unmount():
    global stop_on_unmount
    stop_on_unmount = not stop_on_unmount
    log_message(f"stop_on_unmount toggled to {stop_on_unmount}")
    return redirect(url_for('index'))

def start_flask_app():
    """Run Flask in its own thread."""
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)

if __name__ == "__main__":
    # Start the Flask server in a background thread
    flask_thread = threading.Thread(target=start_flask_app, daemon=True)
    flask_thread.start()

    # Run the main loop
    main_loop()