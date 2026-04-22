#!/bin/bash
# Install the hyprarch SDDM theme and configure SDDM to use it.
# Run with: sudo bash install-sddm.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_SRC="$SCRIPT_DIR/hyprarch"
THEME_DEST="/usr/share/sddm/themes/hyprarch"

# Detect the real user (works whether run as sudo or not)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "Installing SDDM candy theme for user: $REAL_USER"

# Install candy theme via AUR helper
if command -v paru &>/dev/null; then
    sudo -u "$REAL_USER" paru -S --needed --noconfirm sddm-sugar-candy-git
elif command -v yay &>/dev/null; then
    sudo -u "$REAL_USER" yay -S --needed --noconfirm sddm-sugar-candy-git
else
    echo "No AUR helper found, skipping candy theme install"
fi

# Activate the theme
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/hyprarch.conf <<EOF
[Theme]
Current=sugar-candy
EOF
echo "  activated candy theme in /etc/sddm.conf.d/hyprarch.conf"

echo ""
echo "Done. Candy SDDM theme is active."
