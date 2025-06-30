# 🚀 Quick Start Guide - USB Music Player

## ⚡ 30-Second Setup

```bash
# 1. Copy to your Raspberry Pi
git clone https://github.com/yourusername/slab-local.git
cd slab-local

# 2. One-command install
chmod +x deploy-native-pi.sh
./deploy-native-pi.sh

# 3. Logout and login again (for group permissions)
# Then start the player
python3 main.py
```

## 🔌 USB Setup

### Music Drive
- Label: `MUSIC`
- Add your music files (any format)

### Control Drive  
- Label: `PLAY_CARD`
- Create file: `control.txt`

## 🎵 Control Your Music

Edit `/media/pi/PLAY_CARD/control.txt` with:
```
Album: Your Album Name
Track: Your Song Name
play
pause
next
volume: 75
```

## 🌐 Web Interface

Open: `http://your-pi-ip:5000`

## 🔧 Troubleshooting

```bash
# Test system
python3 test-complete-system.py

# Check USB drives
ls /media/pi/

# Check groups
groups  # Should include 'plugdev' and 'audio'
```

## ✨ What's New

- ⚡ **Zero CPU usage** when idle (no polling!)
- 🔌 **Instant USB detection** via events
- 🎧 **VLC audio engine** for quality sound
- 📱 **Real-time web interface**

---

**That's it! Insert your USB drives and enjoy your music! 🎵** 