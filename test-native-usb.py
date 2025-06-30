#!/usr/bin/env python3

import sys
import os

# Add current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from utils import find_music_usb, find_control_usb, log_message

def test_native_usb_detection():
    """Test the native USB detection functions."""
    print("=== Testing Native USB Detection ===")
    print()
    
    # Test music USB detection
    print("1. Testing Music USB Detection:")
    music_usb = find_music_usb()
    if music_usb:
        print(f"   ✅ Music USB found: {music_usb}")
        try:
            contents = os.listdir(music_usb)
            print(f"   📂 Contents: {len(contents)} items")
            if len(contents) <= 5:
                print(f"   📄 Items: {contents}")
        except Exception as e:
            print(f"   ❌ Error reading contents: {e}")
    else:
        print("   ❌ No music USB found")
    
    print()
    
    # Test control USB detection
    print("2. Testing Control USB Detection:")
    control_usb = find_control_usb()
    if control_usb:
        print(f"   ✅ Control USB found: {control_usb}")
        control_file = os.path.join(control_usb, "playMusic.txt")
        if os.path.isfile(control_file):
            print(f"   ✅ playMusic.txt found: {control_file}")
            try:
                with open(control_file, 'r') as f:
                    content = f.read().strip()
                print(f"   📄 Content: '{content}'")
            except Exception as e:
                print(f"   ❌ Error reading control file: {e}")
        else:
            print(f"   ❌ playMusic.txt not found in {control_usb}")
    else:
        print("   ❌ No control USB found")
    
    print()
    
    # Show all mounted USB drives for reference
    print("3. All mounted USB drives in /media/pi/:")
    try:
        if os.path.exists("/media/pi"):
            items = os.listdir("/media/pi")
            if items:
                for item in items:
                    mount_path = f"/media/pi/{item}"
                    if os.path.isdir(mount_path) and os.path.ismount(mount_path):
                        print(f"   📍 {mount_path}")
                        try:
                            contents = os.listdir(mount_path)
                            print(f"      ({len(contents)} items)")
                        except:
                            print("      (inaccessible)")
            else:
                print("   (No items in /media/pi/)")
        else:
            print("   ❌ /media/pi/ directory not found")
    except Exception as e:
        print(f"   ❌ Error scanning /media/pi/: {e}")
    
    print()
    print("=== Test Complete ===")

if __name__ == "__main__":
    test_native_usb_detection() 