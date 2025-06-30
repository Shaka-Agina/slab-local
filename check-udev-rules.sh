#!/bin/bash

echo "🔍 Checking for USB Mounting udev Rules"
echo "======================================="

# 1. Check common udev rule locations
echo "1. Checking udev rules directories..."

UDEV_DIRS=(
    "/etc/udev/rules.d"
    "/lib/udev/rules.d"
    "/usr/lib/udev/rules.d"
    "/run/udev/rules.d"
)

USB_RULES_FOUND=()

for dir in "${UDEV_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "   Checking $dir..."
        
        # Look for USB-related rules
        for rule_file in "$dir"/*.rules; do
            if [ -f "$rule_file" ]; then
                # Check for USB mount rules
                if grep -l -i "usb\|mount\|PLAY_CARD\|MUSIC\|/home/pi/usb" "$rule_file" 2>/dev/null; then
                    echo "   🔴 Found USB rule: $rule_file"
                    USB_RULES_FOUND+=("$rule_file")
                    echo "      Contents:"
                    grep -n -i "usb\|mount\|PLAY_CARD\|MUSIC\|/home/pi/usb" "$rule_file" | sed 's/^/         /'
                    echo ""
                fi
            fi
        done
    fi
done

# 2. Check for custom mount scripts referenced in udev rules
echo "2. Checking for custom mount scripts..."
if [ ${#USB_RULES_FOUND[@]} -gt 0 ]; then
    for rule_file in "${USB_RULES_FOUND[@]}"; do
        echo "   Checking scripts referenced in $rule_file:"
        grep -o 'RUN+="[^"]*"' "$rule_file" 2>/dev/null | sed 's/^/      /'
        grep -o 'PROGRAM=="[^"]*"' "$rule_file" 2>/dev/null | sed 's/^/      /'
    done
fi

# 3. Check systemd automount units
echo "3. Checking systemd automount units..."
systemctl list-units --type=automount | grep -i usb && echo "   Found USB automount units" || echo "   No USB automount units found"

# 4. Check for udisks2 configuration
echo "4. Checking udisks2 configuration..."
if [ -d "/etc/udisks2" ]; then
    echo "   Found /etc/udisks2 directory:"
    ls -la /etc/udisks2/ | sed 's/^/      /'
else
    echo "   No custom udisks2 configuration found"
fi

# 5. Offer to fix the issues
echo ""
if [ ${#USB_RULES_FOUND[@]} -gt 0 ]; then
    echo "🔧 SOLUTION: Remove problematic udev rules"
    echo "==========================================="
    echo ""
    echo "Found ${#USB_RULES_FOUND[@]} problematic udev rule(s):"
    for rule_file in "${USB_RULES_FOUND[@]}"; do
        echo "   - $rule_file"
    done
    echo ""
    echo "To fix the double mounting, run:"
    echo ""
    for rule_file in "${USB_RULES_FOUND[@]}"; do
        echo "   sudo mv '$rule_file' '$rule_file.backup'"
    done
    echo "   sudo udevadm control --reload-rules"
    echo "   sudo udevadm trigger"
    echo ""
    echo "Then unplug and replug your USB drives."
else
    echo "✅ No problematic udev rules found."
    echo ""
    echo "The double mounting might be caused by:"
    echo "   1. /etc/fstab entries (check with: cat /etc/fstab)"
    echo "   2. systemd mount units (check with: systemctl list-units --type=mount)"
    echo "   3. Custom scripts in /etc/rc.local or similar"
fi 