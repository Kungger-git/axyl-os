#!/usr/bin/env bash
# Power menu. loginctl works with both systemd (Arch) and elogind (Artix).

menu() {
    printf '%b\n' \
        "\uf023  Lock" \
        "\uf08b  Logout" \
        "\uf021  Reboot" \
        "\uf011  Shutdown" \
        "\uf186  Suspend"
}

chosen="$(menu | rofi -dmenu -no-custom -p "  Power Menu" \
    -theme ~/.config/rofi/powermenu.rasi \
    -hover-select -me-select-entry '' -me-accept-entry MousePrimary)"

case "$chosen" in
    *Lock)     hyprlock ;;
    *Logout)   hyprctl dispatch exit ;;
    *Reboot)   loginctl reboot ;;
    *Shutdown) loginctl poweroff ;;
    *Suspend)  loginctl suspend ;;
esac
