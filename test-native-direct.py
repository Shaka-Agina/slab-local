#!/usr/bin/env python3
"""
Test script for native USB access and event-driven monitoring
This verifies that we can access USB drives directly and use event-driven detection
"""

import os
import sys
import time
import threading
from utils import find_music_usb, find_control_usb, log_message
from usb_monitor import USBMonitor

def test_event_driven_monitoring():
    """Test the new event-driven USB monitoring"""
    print("\n5. Testing Event-Driven USB Monitoring:")
    
    events_received = []
    
    def on_music_change(new_path, old_path):
        events_received.append(f"Music USB: {old_path} → {new_path}")
        print(f"   🎵 Music USB event: {old_path} → {new_path}")
        
    def on_control_change(new_path, old_path):
        events_received.append(f"Control USB: {old_path} → {new_path}")
        print(f"   🎛️ Control USB event: {old_path} → {new_path}")
    
    # Create USB monitor
    monitor = USBMonitor(
        on_music_usb_change=on_music_change,
        on_control_usb_change=on_control_change
    )
    
    try:
        print("   Starting event-driven monitoring for 5 seconds...")
        monitor.start_monitoring()
        
        # Let it run for a few seconds
        time.sleep(5)
        
        # Check status
        status = monitor.get_current_usb_status()
        print(f"   ✅ Monitor status: {status}")
        
        if events_received:
            print(f"   ✅ Received {len(events_received)} USB events:")
            for event in events_received:
                print(f"      • {event}")
        else:
            print("   ℹ️  No USB events during test (drives may already be mounted)")
            
        print("   ✅ Event-driven monitoring test completed")
        
    except Exception as e:
        print(f"   ❌ Error in event-driven monitoring: {e}")
    finally:
        monitor.stop_monitoring()

def test_native_usb_access():
    """Test direct USB access for native deployment"""
    print("🎵 Testing Native USB Access (Direct /media/pi/ access)")
    print("=" * 60)
    
    # Test music USB detection
    print("\n1. Testing Music USB Detection:")
    music_usb = find_music_usb()
    if music_usb:
        print(f"✅ Music USB found at: {music_usb}")
        try:
            files = os.listdir(music_usb)
            print(f"✅ Can list contents: {len(files)} items")
            
            # Try to find some music files
            music_files = []
            for root, dirs, files in os.walk(music_usb):
                for file in files:
                    if file.lower().endswith(('.mp3', '.wav', '.flac', '.m4a')):
                        music_files.append(os.path.join(root, file))
                        if len(music_files) >= 3:  # Just get a few examples
                            break
                if len(music_files) >= 3:
                    break
            
            if music_files:
                print(f"✅ Found {len(music_files)} music files (showing first 3):")
                for i, file in enumerate(music_files[:3]):
                    print(f"   {i+1}. {os.path.basename(file)}")
            else:
                print("⚠️  No music files found")
                
        except PermissionError as e:
            print(f"❌ Permission denied: {e}")
            print("💡 Make sure your user is in the 'plugdev' group")
        except Exception as e:
            print(f"❌ Error accessing music USB: {e}")
    else:
        print("❌ No music USB found")
        print("💡 Make sure you have a USB drive labeled 'MUSIC' inserted")
    
    # Test control USB detection
    print("\n2. Testing Control USB Detection:")
    control_usb = find_control_usb()
    if control_usb:
        print(f"✅ Control USB found at: {control_usb}")
        try:
            files = os.listdir(control_usb)
            print(f"✅ Can list contents: {len(files)} items")
            
            # Look for control file
            from config import CONTROL_FILE_NAME
            control_file = os.path.join(control_usb, CONTROL_FILE_NAME)
            if os.path.isfile(control_file):
                print(f"✅ Control file found: {CONTROL_FILE_NAME}")
                try:
                    with open(control_file, 'r') as f:
                        content = f.read().strip()
                    print(f"✅ Control file content: '{content}'")
                except Exception as e:
                    print(f"⚠️  Could not read control file: {e}")
            else:
                print(f"⚠️  Control file '{CONTROL_FILE_NAME}' not found")
                print("💡 Create this file on your PLAY_CARD USB drive")
                
        except PermissionError as e:
            print(f"❌ Permission denied: {e}")
            print("💡 Make sure your user is in the 'plugdev' group")
        except Exception as e:
            print(f"❌ Error accessing control USB: {e}")
    else:
        print("❌ No control USB found")
        print("💡 Make sure you have a USB drive labeled 'PLAY_CARD' inserted")
    
    # Test user permissions
    print("\n3. Testing User Permissions:")
    try:
        # Check if user is in plugdev group
        import subprocess
        result = subprocess.run(['groups'], capture_output=True, text=True)
        groups = result.stdout.strip()
        print(f"✅ User groups: {groups}")
        
        if 'plugdev' in groups:
            print("✅ User is in 'plugdev' group (good for USB access)")
        else:
            print("⚠️  User is NOT in 'plugdev' group")
            print("💡 Run: sudo usermod -aG plugdev $USER")
            print("💡 Then logout and login again")
            
    except Exception as e:
        print(f"⚠️  Could not check groups: {e}")
    
    # Test /media/pi directory
    print("\n4. Testing /media/pi Directory:")
    if os.path.exists("/media/pi"):
        try:
            items = os.listdir("/media/pi")
            print(f"✅ /media/pi exists with {len(items)} items:")
            for item in items:
                item_path = f"/media/pi/{item}"
                if os.path.isdir(item_path):
                    try:
                        sub_items = os.listdir(item_path)
                        print(f"   📁 {item}/ ({len(sub_items)} items)")
                    except PermissionError:
                        print(f"   📁 {item}/ (permission denied)")
                    except Exception as e:
                        print(f"   📁 {item}/ (error: {e})")
                else:
                    print(f"   📄 {item}")
        except Exception as e:
            print(f"❌ Error listing /media/pi: {e}")
    else:
        print("❌ /media/pi directory does not exist")
        print("💡 This is unusual - are you on Raspberry Pi OS with desktop?")
    
    # Test event-driven monitoring
    test_event_driven_monitoring()
    
    print("\n" + "=" * 60)
    print("🎵 Native USB Test Complete!")
    print("\n💡 Tips:")
    print("• Insert USB drives labeled 'MUSIC' and 'PLAY_CARD'")
    print("• Make sure you're in the 'plugdev' group")
    print("• Desktop environment should auto-mount USB drives")
    print("• Event-driven monitoring eliminates polling overhead")
    print("• No bind mounts needed - direct access to /media/pi/")

if __name__ == "__main__":
    test_native_usb_access() 