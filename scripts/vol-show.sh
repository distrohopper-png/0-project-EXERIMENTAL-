#!/bin/bash
pkill -USR1 -f volume-overlay.py 2>/dev/null || \
    LD_PRELOAD=/usr/lib/libgtk4-layer-shell.so python3 "$HOME/.config/scripts/volume-overlay.py" &
