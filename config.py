#!/usr/bin/env python3
# config.py

import os
import configparser

def load_config():
    """Load configuration from config.ini or create with defaults if not exists"""
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

# Load configuration
config = load_config()

# Configuration variables
MUSIC_USB_MOUNT = config['MUSIC_USB_MOUNT']
CONTROL_USB_MOUNT = config['CONTROL_USB_MOUNT']
CONTROL_FILE_NAME = config['CONTROL_FILE_NAME']
WEB_PORT = int(config['WEB_PORT'])
DEFAULT_VOLUME = int(config['DEFAULT_VOLUME'])

# Global flag for repeat playback
repeat_playback = True  # If True, playback loops 