#!/bin/bash
# Full setup script — installs packages and links all configs.
# Run once after cloning: bash install.sh

set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# ── COLOURS ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  !${NC} $1"; }
info() { echo -e "  $1"; }

# ── AUR HELPER ───────────────────────────────────────────────────────────────
if command -v paru &>/dev/null; then
    AUR="paru -S --needed --noconfirm"
elif command -v yay &>/dev/null; then
    AUR="yay -S --needed --noconfirm"
else
    echo -e "${RED}Error:${NC} No AUR helper found. Install paru or yay first:"
    echo "  sudo pacman -S --needed git base-devel"
    echo "  git clone https://aur.archlinux.org/paru.git /tmp/paru"
    echo "  cd /tmp/paru && makepkg -si"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  hyprarch dotfiles installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── PACKAGES ─────────────────────────────────────────────────────────────────
echo "Installing packages..."

PACMAN_PKGS=(
    hyprland
    hyprsunset
    kitty
    rofi
    mako
    fastfetch
    cava
    cmatrix
    sddm
    pipewire
    wireplumber
    imagemagick
    playerctl
    python
    python-requests
    python-gobject
    python-pam
    gtk4
    gtk4-layer-shell
    jq
    ttf-jetbrains-mono-nerd
    noto-fonts
    wl-clipboard
    dolphin
)

AUR_PKGS=(
    quickshell-git
    matugen
    awww
    grimblast-git
    satty-git
    wlogout
)

sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
ok "pacman packages installed"

$AUR "${AUR_PKGS[@]}"
ok "AUR packages installed"

# ── SYMLINKS ─────────────────────────────────────────────────────────────────
echo ""
echo "Linking configs..."

link() {
    mkdir -p "$(dirname "$2")"
    ln -sf "$1" "$2"
    ok "linked $(basename "$2")"
}

link "$DOTFILES/hypr/hyprland.conf"                                "$HOME/.config/hypr/hyprland.conf"
link "$DOTFILES/kitty/kitty.conf"                                  "$HOME/.config/kitty/kitty.conf"
link "$DOTFILES/mako/config"                                       "$HOME/.config/mako/config"
link "$DOTFILES/rofi/config.rasi"                                  "$HOME/.config/rofi/config.rasi"
link "$DOTFILES/rofi/theme.rasi"                                   "$HOME/.config/rofi/theme.rasi"
link "$DOTFILES/rofi/wallpaper.rasi"                               "$HOME/.config/rofi/wallpaper.rasi"
link "$DOTFILES/rofi/powermenu.rasi"                               "$HOME/.config/rofi/powermenu.rasi"
link "$DOTFILES/quickshell/shell.qml"                              "$HOME/.config/quickshell/shell.qml"
link "$DOTFILES/wallpaper-picker/picker.py"                        "$HOME/.config/wallpaper-picker/picker.py"
link "$DOTFILES/scripts/lockscreen.py"                             "$HOME/.config/scripts/lockscreen.py"
link "$DOTFILES/scripts/lyrics-fetch.py"                           "$HOME/.config/scripts/lyrics-fetch.py"
link "$DOTFILES/scripts/powermenu.sh"                              "$HOME/.config/scripts/powermenu.sh"
link "$DOTFILES/scripts/power-popup.py"                            "$HOME/.config/scripts/power-popup.py"
link "$DOTFILES/fastfetch/config.jsonc"                            "$HOME/.config/fastfetch/config.jsonc"
link "$DOTFILES/fastfetch/small.jsonc"                             "$HOME/.config/fastfetch/small.jsonc"
link "$DOTFILES/matugen/templates/fastfetch.jsonc"                 "$HOME/.config/matugen/templates/fastfetch.jsonc"
link "$DOTFILES/matugen/templates/fastfetch-small.jsonc"           "$HOME/.config/matugen/templates/fastfetch-small.jsonc"
link "$DOTFILES/matugen/templates/rofi-theme.rasi"                 "$HOME/.config/matugen/templates/rofi-theme.rasi"
link "$DOTFILES/matugen/templates/cava.conf"                       "$HOME/.config/matugen/templates/cava.conf"
link "$DOTFILES/matugen/templates/cmatrix"                         "$HOME/.config/matugen/templates/cmatrix"
link "$DOTFILES/wlogout/layout"                                    "$HOME/.config/wlogout/layout"
link "$DOTFILES/wlogout/style.css"                                 "$HOME/.config/wlogout/style.css"
link "$DOTFILES/.bashrc"                                           "$HOME/.bashrc"

# matugen config — generated (not symlinked) because it needs absolute paths
mkdir -p "$HOME/.config/matugen"
sed "s|{{HOME}}|$HOME|g" "$DOTFILES/matugen/config.toml.template" \
    > "$HOME/.config/matugen/config.toml"
ok "generated matugen/config.toml"

# cmatrix color dir
mkdir -p "$HOME/.config/cmatrix"
ok "created ~/.config/cmatrix"

# wireplumber audio fix — machine-specific, skip if not matching hardware
if [ -f "$DOTFILES/wireplumber/wireplumber.conf.d/50-fix-profiles.conf" ]; then
    link "$DOTFILES/wireplumber/wireplumber.conf.d/50-fix-profiles.conf" \
         "$HOME/.config/wireplumber/wireplumber.conf.d/50-fix-profiles.conf"
    warn "wireplumber: audio fix linked (may need editing for your hardware)"
fi

# ── SDDM THEME ───────────────────────────────────────────────────────────────
echo ""
echo "Installing SDDM theme..."
sudo bash "$DOTFILES/sddm/install-sddm.sh"

# ── SDDM SERVICE ─────────────────────────────────────────────────────────────
echo ""
echo "Enabling SDDM..."
sudo systemctl enable sddm
ok "sddm enabled"

# ── WALLPAPER DIR ────────────────────────────────────────────────────────────
mkdir -p "$HOME/Pictures/Wallpapers"
ok "created ~/Pictures/Wallpapers"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}Done!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Reboot, select Hyprland in SDDM, and log in."
echo "  First time: pick Hyprland from the session list (bottom-right)."
echo "  SDDM will remember it from then on."
echo ""
