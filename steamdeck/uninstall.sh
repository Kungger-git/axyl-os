#!/usr/bin/env bash
# Remove the Axyl Hyprland desktop from SteamOS.
#
#   ./uninstall.sh              remove the session entry, commands and app icon
#   ./uninstall.sh --purge      also remove the Hyprland/Waybar/Rofi/Foot config
#
# Packages are left installed; SteamOS updates and other sessions may use them.
# Backups under ~/.local/state/axyl-deck/backup-* are never deleted.
set -euo pipefail

PURGE=0
TARGET_USER="${SUDO_USER:-$(id -un)}"

while (($#)); do
    case "$1" in
        --purge) PURGE=1 ;;
        --user)  shift; TARGET_USER="${1:-}" ;;
        -h|--help)
            sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || {
    echo "error: no home directory for $TARGET_USER" >&2
    exit 1
}
STATE="$TARGET_HOME/.local/state/axyl-deck"

as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

echo "==> Removing the Axyl session entry and command symlinks"
as_root rm -f /usr/share/wayland-sessions/axyl-hyprland.desktop

for name in axyl-hyprland-session axyl-switch axyl-deck axyl-osk; do
    link="/usr/local/bin/$name"
    if [[ -L "$link" ]]; then
        target="$(readlink "$link")"
        if [[ "$target" == "$TARGET_HOME"/* ]]; then
            as_root rm -f "$link"
        fi
    fi
done

echo "==> Removing the desktop application files"
rm -f "$TARGET_HOME/.local/share/applications/axyl-switch.desktop"
rm -f "$TARGET_HOME/Desktop/Axyl Deck.desktop"
rm -f "$TARGET_HOME/.local/share/icons/hicolor/scalable/apps/axyl-deck.svg"
rm -rf "$STATE/tree"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$TARGET_HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

if [[ $PURGE -eq 1 ]]; then
    echo "==> Removing user configuration (backups are kept)"
    rm -rf "$TARGET_HOME/.config/hypr" \
           "$TARGET_HOME/.config/waybar" \
           "$TARGET_HOME/.config/rofi" \
           "$TARGET_HOME/.config/foot" \
           "$TARGET_HOME/.config/theme" \
           "$TARGET_HOME/.config/mako" \
           "$TARGET_HOME/.config/fastfetch" \
           "$TARGET_HOME/.config/kitty"
    rm -rf "$TARGET_HOME/.local/share/squeekboard/keyboards"
    rm -f "$TARGET_HOME"/.local/bin/axyl-switch \
          "$TARGET_HOME"/.local/bin/axyl-deck \
          "$TARGET_HOME"/.local/bin/axyl-osk \
          "$TARGET_HOME"/.local/bin/axyl-hyprland-session \
          "$TARGET_HOME"/.local/bin/screenshot \
          "$TARGET_HOME"/.local/bin/start-audio.sh \
          "$TARGET_HOME"/.local/bin/waybar-battery \
          "$TARGET_HOME"/.local/bin/hypr-effects \
          "$TARGET_HOME"/.local/bin/timer
    rm -f "$STATE"/session.log "$STATE"/switch.log "$STATE"/keyboard.log \
          "$STATE"/packages-before.txt
fi

echo
echo "Done. Reboot to return to Steam Game Mode."
echo "Installed packages were kept:"
echo "  hyprland waybar foot rofi mako hyprlock hypridle ..."
echo "Backups: $STATE/backup-*"
