#!/bin/bash
nohup /bin/bash -c "sleep 0.2 && python3 /home/arch/.config/scripts/power-popup.py" \
    >/tmp/hyprlock-power.log 2>&1 &
disown $!
/usr/bin/pkill -x hyprlock
