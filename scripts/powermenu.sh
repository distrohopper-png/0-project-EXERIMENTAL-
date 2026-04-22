#!/bin/bash
CHOICE=$(printf '⏻  Shutdown\n  Reboot\n󰍃  Log Out\n⏾  Suspend' | \
    rofi -dmenu \
         -p "  " \
         -theme "$HOME/.config/rofi/powermenu.rasi" \
         -no-custom)

case "$CHOICE" in
    *Shutdown*) systemctl poweroff ;;
    *Reboot*)   systemctl reboot ;;
    *Log\ Out*) hyprctl dispatch exit ;;
    *Suspend*)  systemctl suspend ;;
esac
