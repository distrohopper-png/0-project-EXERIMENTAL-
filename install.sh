#!/bin/bash
# hyprarch dotfiles installer
# Supports: Arch, CachyOS, EndeavourOS, Garuda, Manjaro (and other Arch-based distros)
# Run once after cloning: bash install.sh

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# ── COLOURS ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  !${NC} $1"; }
err()  { echo -e "${RED}  ✗${NC} $1"; }
info() { echo -e "${CYAN}  →${NC} $1"; }

# ── DISTRO DETECTION ─────────────────────────────────────────────────────────
DISTRO_ID=""
[ -f /etc/os-release ] && . /etc/os-release && DISTRO_ID="$ID"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  hyprarch dotfiles installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

case "$DISTRO_ID" in
    manjaro)
        warn "Manjaro detected — package versions may lag behind Arch."
        warn "AUR packages might fail to build. If they do, install them manually."
        warn "Continuing in 5 seconds..." ; sleep 5
        ;;
    cachyos|garuda)
        info "CachyOS/Garuda detected — chaotic-aur packages will be preferred."
        ;;
    endeavouros)
        info "EndeavourOS detected — fully compatible."
        ;;
    arch)
        info "Arch Linux detected."
        ;;
    *)
        [ -n "$DISTRO_ID" ] && info "Distro: $DISTRO_ID"
        ;;
esac

# ── AUR HELPER ───────────────────────────────────────────────────────────────
if command -v paru &>/dev/null; then
    AUR="paru -S --needed --noconfirm"
elif command -v yay &>/dev/null; then
    AUR="yay -S --needed --noconfirm"
else
    echo ""
    err "No AUR helper found. Install paru or yay first:"
    echo "    sudo pacman -S --needed git base-devel"
    echo "    git clone https://aur.archlinux.org/paru.git /tmp/paru"
    echo "    cd /tmp/paru && makepkg -si"
    exit 1
fi

# ── PACKAGE HELPERS ──────────────────────────────────────────────────────────
# Install a list of pacman packages — skips ones that fail rather than aborting
install_pacman() {
    local failed=()
    for pkg in "$@"; do
        sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null && ok "$pkg" \
            || { err "$pkg (pacman failed — skipping)"; failed+=("$pkg"); }
    done
    [ ${#failed[@]} -gt 0 ] && warn "Skipped: ${failed[*]}"
}

# Install a list of AUR packages — skips ones that fail
install_aur() {
    local failed=()
    for pkg in "$@"; do
        $AUR "$pkg" 2>/dev/null && ok "$pkg" \
            || { err "$pkg (AUR failed — skipping)"; failed+=("$pkg"); }
    done
    [ ${#failed[@]} -gt 0 ] && warn "Skipped: ${failed[*]}"
}

# ── PACKAGES ─────────────────────────────────────────────────────────────────
echo ""
echo "Installing pacman packages..."

PACMAN_PKGS=(
    # Core compositor
    hyprland
    hyprsunset

    # Terminal + shell
    kitty
    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions

    # Launcher
    rofi

    # Notifications
    mako

    # System info
    fastfetch

    # Audio visualizer / matrix
    cava
    cmatrix

    # Login screen
    sddm

    # Audio
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber

    # Screenshot + annotation
    satty

    # Wallpaper utilities
    imagemagick

    # Media control (for lyrics easter egg)
    playerctl

    # Python + GTK (lock screen)
    python
    python-requests
    python-gobject
    python-pam
    gtk4
    gtk4-layer-shell

    # Misc
    jq
    ttf-jetbrains-mono-nerd
    noto-fonts
    wl-clipboard
    dolphin
)

install_pacman "${PACMAN_PKGS[@]}"

echo ""
echo "Installing AUR packages..."

AUR_PKGS=(
    quickshell-git    # top bar
    matugen           # wallpaper color extraction
    awww              # wallpaper daemon
    grimblast-git     # screenshot helper for hyprland
    wlogout           # logout menu
)

install_aur "${AUR_PKGS[@]}"

# ── SYMLINKS ─────────────────────────────────────────────────────────────────
echo ""
echo "Linking configs..."

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    ok "$(basename "$dst")"
}

link "$DOTFILES/hypr/hyprland.conf"                          "$HOME/.config/hypr/hyprland.conf"
link "$DOTFILES/kitty/kitty.conf"                            "$HOME/.config/kitty/kitty.conf"
link "$DOTFILES/mako/config"                                 "$HOME/.config/mako/config"
link "$DOTFILES/rofi/config.rasi"                            "$HOME/.config/rofi/config.rasi"
link "$DOTFILES/rofi/theme.rasi"                             "$HOME/.config/rofi/theme.rasi"
link "$DOTFILES/rofi/wallpaper.rasi"                         "$HOME/.config/rofi/wallpaper.rasi"
link "$DOTFILES/rofi/powermenu.rasi"                         "$HOME/.config/rofi/powermenu.rasi"
link "$DOTFILES/quickshell/shell.qml"                        "$HOME/.config/quickshell/shell.qml"
link "$DOTFILES/wallpaper-picker/picker.py"                  "$HOME/.config/wallpaper-picker/picker.py"
link "$DOTFILES/scripts/lockscreen.py"                       "$HOME/.config/scripts/lockscreen.py"
link "$DOTFILES/scripts/lyrics-fetch.py"                     "$HOME/.config/scripts/lyrics-fetch.py"
link "$DOTFILES/scripts/powermenu.sh"                        "$HOME/.config/scripts/powermenu.sh"
link "$DOTFILES/scripts/power-popup.py"                      "$HOME/.config/scripts/power-popup.py"
link "$DOTFILES/fastfetch/config.jsonc"                      "$HOME/.config/fastfetch/config.jsonc"
link "$DOTFILES/fastfetch/small.jsonc"                       "$HOME/.config/fastfetch/small.jsonc"
link "$DOTFILES/matugen/templates/zsh-colors.zsh"            "$HOME/.config/matugen/templates/zsh-colors.zsh"
link "$DOTFILES/matugen/templates/kitty.conf"                "$HOME/.config/matugen/templates/kitty.conf"
link "$DOTFILES/matugen/templates/rofi-theme.rasi"           "$HOME/.config/matugen/templates/rofi-theme.rasi"
link "$DOTFILES/matugen/templates/cava.conf"                 "$HOME/.config/matugen/templates/cava.conf"
link "$DOTFILES/matugen/templates/cmatrix"                   "$HOME/.config/matugen/templates/cmatrix"
link "$DOTFILES/wlogout/layout"                              "$HOME/.config/wlogout/layout"
link "$DOTFILES/wlogout/style.css"                           "$HOME/.config/wlogout/style.css"
link "$DOTFILES/zsh/.zshrc"                                  "$HOME/.zshrc"

# Directories without config files
mkdir -p "$HOME/.config/cmatrix"
mkdir -p "$HOME/.config/zsh"
mkdir -p "$HOME/Pictures/Wallpapers"
ok "created required directories"

# matugen config needs absolute HOME paths — generated from template, not symlinked
mkdir -p "$HOME/.config/matugen"
sed "s|{{HOME}}|$HOME|g" "$DOTFILES/matugen/config.toml.template" \
    > "$HOME/.config/matugen/config.toml"
ok "generated matugen/config.toml"

# wireplumber audio fix — hardware-specific, only link if present
if [ -f "$DOTFILES/wireplumber/wireplumber.conf.d/50-fix-profiles.conf" ]; then
    link "$DOTFILES/wireplumber/wireplumber.conf.d/50-fix-profiles.conf" \
         "$HOME/.config/wireplumber/wireplumber.conf.d/50-fix-profiles.conf"
    warn "wireplumber audio fix linked — edit or delete if your hardware differs"
fi

# ── ZSH DEFAULT SHELL ────────────────────────────────────────────────────────
ZSH_BIN=$(command -v zsh 2>/dev/null)
if [ -n "$ZSH_BIN" ] && [ "$SHELL" != "$ZSH_BIN" ]; then
    echo ""
    echo "Setting zsh as default shell..."
    chsh -s "$ZSH_BIN" \
        && ok "zsh set as default shell (takes effect on next login)" \
        || warn "Could not set zsh — run manually: chsh -s $ZSH_BIN"
fi

# ── SDDM NOPASSWD SCRIPT ─────────────────────────────────────────────────────
if [ -f "$DOTFILES/sddm/sddm-bg-update" ]; then
    echo ""
    echo "Installing SDDM background updater..."
    sudo install -m 755 "$DOTFILES/sddm/sddm-bg-update" /usr/local/bin/sddm-bg-update \
        && ok "sddm-bg-update installed to /usr/local/bin" \
        || warn "Could not install sddm-bg-update (needs sudo)"

    # Add sudoers rule so the wallpaper picker can call it without a password
    SUDOERS_LINE="$USER ALL=(ALL) NOPASSWD: /usr/local/bin/sddm-bg-update"
    if ! sudo grep -qF "$SUDOERS_LINE" /etc/sudoers 2>/dev/null; then
        echo "$SUDOERS_LINE" | sudo tee /etc/sudoers.d/sddm-bg-update > /dev/null \
            && ok "sudoers rule added for sddm-bg-update" \
            || warn "Could not add sudoers rule — wallpaper picker won't update SDDM bg"
    fi
fi

# ── SDDM THEME ───────────────────────────────────────────────────────────────
if [ -f "$DOTFILES/sddm/install-sddm.sh" ]; then
    echo ""
    echo "Installing SDDM theme..."
    sudo bash "$DOTFILES/sddm/install-sddm.sh" \
        && ok "SDDM theme installed" \
        || warn "SDDM theme install failed (non-fatal)"
fi

# ── SDDM SERVICE ─────────────────────────────────────────────────────────────
if command -v systemctl &>/dev/null; then
    echo ""
    echo "Enabling SDDM..."
    sudo systemctl enable sddm \
        && ok "sddm enabled" \
        || warn "Could not enable sddm (may already be enabled or using a different DM)"
fi

# ── DONE ─────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}Done!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Next steps:"
echo "  1. Reboot"
echo "  2. Select Hyprland in SDDM (bottom-right session picker)"
echo "  3. Pick a wallpaper with Super+W to generate your color theme"
echo ""
echo "  If any packages were skipped, install them manually:"
echo "    paru -S <package-name>"
echo ""
