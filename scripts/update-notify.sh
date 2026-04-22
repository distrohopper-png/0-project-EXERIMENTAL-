#!/bin/bash
# Check for hyprarch dotfiles updates every 5 days and notify via mako

DOTFILES="$HOME/dotfiles"
STAMP="$HOME/.cache/hyprarch-update-stamp"
INTERVAL=$(( 5 * 24 * 60 * 60 ))

# Exit early if checked recently
if [[ -f "$STAMP" ]]; then
    last=$(cat "$STAMP" 2>/dev/null || echo 0)
    now=$(date +%s)
    (( now - last < INTERVAL )) && exit 0
fi

# Record this check
date +%s > "$STAMP"

# Need git and network
command -v git &>/dev/null || exit 0
[[ -d "$DOTFILES/.git" ]] || exit 0

# Fetch quietly — fail silently if offline
git -C "$DOTFILES" fetch origin --quiet 2>/dev/null || exit 0

behind=$(git -C "$DOTFILES" rev-list HEAD..origin/main --count 2>/dev/null)
[[ -z "$behind" || "$behind" == "0" ]] && exit 0

notify-send \
    "hyprarch dotfiles" \
    "$behind new update(s) available\ngit -C ~/dotfiles pull" \
    --icon=system-software-update \
    --urgency=normal \
    --expire-time=12000
