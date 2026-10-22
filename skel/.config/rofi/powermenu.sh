#!/usr/bin/env bash

options="  Lock\n  Logout\n  Reboot\n  Shutdown\n  Suspend"
chosen="$(echo -e "$options" | rofi -dmenu -p "Power Menu" -theme ~/.config/rofi/powermenu.rasi)"

case "$chosen" in
    "  Lock") hyprlock ;;
    "  Logout") hyprctl dispatch exit ;;
    "  Reboot") loginctl reboot ;;
    "  Shutdown") loginctl poweroff ;;
    "  Suspend") loginctl suspend ;;
esac
