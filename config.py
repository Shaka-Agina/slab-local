#!/usr/bin/env python3
# config.py

import os
import configparser

def load_config():
    """Load configuration from config.ini or create with defaults if not exists"""
    config = configparser.ConfigParser()
    
    config['DEFAULT'] = {
        'CONTROL_FILE_NAME': os.environ.get('CONTROL_FILE_NAME', 'control.txt'),
        'WEB_PORT': os.environ.get('WEB_PORT', '5000'),
        'DEFAULT_VOLUME': os.environ.get('DEFAULT_VOLUME', '70'),
        'AUDIO_OUTPUT': os.environ.get('AUDIO_OUTPUT', 'pulse'),
        'VOLUME_LEVEL': os.environ.get('VOLUME_LEVEL', '0.7'),
        'DEBUG_MODE': os.environ.get('DEBUG_MODE', 'True')
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
CONTROL_FILE_NAME = config['CONTROL_FILE_NAME']
WEB_PORT = int(config['WEB_PORT'])
DEFAULT_VOLUME = int(config['DEFAULT_VOLUME'])
AUDIO_OUTPUT = config['AUDIO_OUTPUT']
VOLUME_LEVEL = float(config['VOLUME_LEVEL'])
DEBUG_MODE = config['DEBUG_MODE'] == 'True'

# Global flag for repeat playback
repeat_playback = True  # If True, playback loops 