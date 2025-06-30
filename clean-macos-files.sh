#!/bin/bash

echo "🧹 Cleaning macOS Hidden Files from Music USB"
echo "=============================================="

MUSIC_USB="/media/pi/MUSIC"

if [ ! -d "$MUSIC_USB" ]; then
    echo "❌ Music USB not found at $MUSIC_USB"
    echo "   Make sure your MUSIC USB is plugged in"
    exit 1
fi

echo "📁 Scanning for macOS hidden files in: $MUSIC_USB"
echo ""

# Count files before cleanup
echo "🔍 Before cleanup:"
._files=$(find "$MUSIC_USB" -name "._*" 2>/dev/null | wc -l)
ds_files=$(find "$MUSIC_USB" -name ".DS_Store" 2>/dev/null | wc -l)
thumbs_files=$(find "$MUSIC_USB" -name "Thumbs.db" 2>/dev/null | wc -l)

echo "   - ._* files (resource forks): $._files"
echo "   - .DS_Store files: $ds_files"
echo "   - Thumbs.db files: $thumbs_files"
echo ""

if [ $._files -eq 0 ] && [ $ds_files -eq 0 ] && [ $thumbs_files -eq 0 ]; then
    echo "✅ No hidden files found - USB is clean!"
    exit 0
fi

echo "🗑️  Removing hidden files..."

# Remove macOS resource fork files (._filename)
if [ $._files -gt 0 ]; then
    echo "   - Removing $._files resource fork files..."
    find "$MUSIC_USB" -name "._*" -type f -delete 2>/dev/null
    echo "     ✅ Resource fork files removed"
fi

# Remove .DS_Store files
if [ $ds_files -gt 0 ]; then
    echo "   - Removing $ds_files .DS_Store files..."
    find "$MUSIC_USB" -name ".DS_Store" -type f -delete 2>/dev/null
    echo "     ✅ .DS_Store files removed"
fi

# Remove Thumbs.db files
if [ $thumbs_files -gt 0 ]; then
    echo "   - Removing $thumbs_files Thumbs.db files..."
    find "$MUSIC_USB" -name "Thumbs.db" -type f -delete 2>/dev/null
    echo "     ✅ Thumbs.db files removed"
fi

echo ""
echo "🔍 After cleanup:"
._files_after=$(find "$MUSIC_USB" -name "._*" 2>/dev/null | wc -l)
ds_files_after=$(find "$MUSIC_USB" -name ".DS_Store" 2>/dev/null | wc -l)
thumbs_files_after=$(find "$MUSIC_USB" -name "Thumbs.db" 2>/dev/null | wc -l)

echo "   - ._* files (resource forks): $._files_after"
echo "   - .DS_Store files: $ds_files_after"
echo "   - Thumbs.db files: $thumbs_files_after"

echo ""
if [ $._files_after -eq 0 ] && [ $ds_files_after -eq 0 ] && [ $thumbs_files_after -eq 0 ]; then
    echo "✅ USB cleanup completed successfully!"
    echo ""
    echo "🎵 Your music should now play properly without:"
    echo "   - Trying to play ._* resource fork files"
    echo "   - Errors from corrupted system files"
    echo ""
    echo "💡 To prevent this in the future:"
    echo "   - Use 'cp -X' when copying from Mac to exclude resource forks"
    echo "   - Or run this script after copying music"
else
    echo "⚠️  Some files couldn't be removed (check permissions)"
fi 