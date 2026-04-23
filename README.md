# 0-project dotfiles | DISCONTINUED

Hyprland desktop setup for Arch-based distros (Arch, CachyOS, EndeavourOS, Manjaro, Garuda).

## Install

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles ~/dotfiles
cd ~/dotfiles
bash install.sh
```

The script installs all packages, links configs, sets up the SDDM login theme, and enables SDDM. After it finishes, reboot. On the login screen pick **Hyprland** from the session selector — SDDM remembers it from then on.

> You need `paru` or `yay` before running. If you don't have one:
> ```bash
> sudo pacman -S --needed git base-devel
> git clone https://aur.archlinux.org/paru.git /tmp/paru && cd /tmp/paru && makepkg -si
> ```

---

## Keybinds

| Key | Action |
|-----|--------|
| Super + Return | Kitty terminal |
| Super + Q | Kill window |
| Super + D | Rofi app launcher |
| Super + W | Wallpaper picker (wallhaven.cc) |
| Super + E | Dolphin file manager |
| Super + V | Toggle floating |
| Super + M | Exit Hyprland |
| Super + L | Lock screen |
| Super + R | Reload the top bar (quickshell) |
| Super + F | Fullscreen (keep bar) |
| Super + Shift + F | True fullscreen |
| Super + 1–8 | Switch workspace |
| Super + Shift + 1–8 | Move window to workspace |
| Super + Arrow keys | Move focus |
| Super + LMB | Drag window |
| Super + RMB | Resize window |
| Print | Freeze + copy region screenshot |
| Shift + Print | Fullscreen → Satty annotate |
| Volume keys | Raise / lower / mute |
| F8 | Stop all media playback |

---

## What's included

| Folder | Config for |
|--------|-----------|
| `hypr/` | Hyprland — keybinds, blur, rounded corners |
| `kitty/` | Kitty terminal — transparent + blur |
| `mako/` | Mako notification daemon — pill-shaped, black/transparent |
| `rofi/` | Rofi launcher — glass side panel |
| `quickshell/` | Top bar — workspaces, volume, clock, app indicators, lyrics easter egg |
| `wallpaper-picker/` | GTK4 wallhaven.cc browser (Super+W) |
| `fastfetch/` | Fastfetch — colors sync with wallpaper via matugen |
| `matugen/` | Color scheme generator — syncs rofi, fastfetch, cava, cmatrix |
| `scripts/` | Lock screen (GTK4 layer-shell), lyrics fetcher |
| `sddm/` | Custom login theme (hyprarch) |
| `wireplumber/` | Audio fix — machine-specific, may need editing |

---

## Notes

- **Wallpaper colors**: Changing wallpaper via Super+W auto-regenerates colors for rofi, fastfetch, cava, and cmatrix. The lock screen wallpaper blur is pre-generated at pick time for instant lock.
- **Lock screen**: Custom GTK4 lock screen (Super+L). Requires `gtk4-layer-shell` and `python-pam`.
- **Cava**: Colors sync with wallpaper automatically — open cava after changing wallpaper.
- **Cmatrix**: Run `cmatrix` — the shell function auto-picks the closest color to your current wallpaper palette. Runs with terminal blur/transparency from kitty.
- **Lyrics easter egg**: Click the Spotify icon in the bar (green note) to open a synced lyrics pill on the left. Powered by lrclib.net.
- **Audio fix**: `wireplumber/50-fix-profiles.conf` has PCI IDs for Realtek ALC897 + DGM20 USB mic. Edit or delete it if your hardware is different.
