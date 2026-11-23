#!/usr/bin/env bash
# Install the Axyl Hyprland desktop on stock SteamOS (Steam Deck).
#
# Safe by design:
#   * packages come from the SteamOS repos with --needed (no -Syu, no downgrade)
#   * the KDE/GTK/Qt configuration is never touched
#   * switching sessions stays one-shot; DefaultLoginMode is unchanged
#   * every overwritten user file is backed up under ~/.local/state/axyl-deck
#
# Usage:
#   ./install.sh                 full install (asks for sudo via the terminal)
#   ./install.sh --yes           same, no confirmation prompts
#   ./install.sh --repair        re-apply packages, files and the session entry
#   ./install.sh --user-only     only write the user configuration
#   ./install.sh --no-packages   skip pacman (files and session entry only)
#   ./install.sh --user NAME     target user (needed when run as root/pkexec)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

YES=0
REPAIR=0
USER_ONLY=0
SKIP_PACKAGES=0
TARGET_USER="${SUDO_USER:-$(id -un)}"

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while (($#)); do
    case "$1" in
        --yes|-y)       YES=1 ;;
        --repair)       REPAIR=1 ;;
        --user-only)    USER_ONLY=1 ;;
        --no-packages)  SKIP_PACKAGES=1 ;;
        --user)         shift; TARGET_USER="${1:-}" ;;
        -h|--help)      usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

[[ -n "$TARGET_USER" && "$TARGET_USER" != root ]] || {
    echo "error: run as your desktop user, or pass --user <name>" >&2
    exit 1
}

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" && -d "$TARGET_HOME" ]] || {
    echo "error: no home directory for user $TARGET_USER" >&2
    exit 1
}
TARGET_GROUP="$(id -gn "$TARGET_USER")"
STATE="$TARGET_HOME/.local/state/axyl-deck"
CACHE="$TARGET_HOME/.cache/axyl-pacman"

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# ------------------------------------------------------------------ packages ---
install_packages() {
    log "Installing SteamOS packages (this can take a few minutes)"
    local avail_kb
    avail_kb=$(df -Pk / | awk 'NR==2 {print $4}')
    if (( avail_kb < 350 * 1024 )); then
        die "only $((avail_kb / 1024)) MB free on /; free space and re-run"
    fi
    (( avail_kb < 600 * 1024 )) && warn "only $((avail_kb / 1024)) MB free on /"

    command -v pacman >/dev/null 2>&1 || die "pacman is not available"

    local desired=(
        hyprland waybar foot rofi mako hyprlock hypridle
        grim slurp wl-clipboard cliphist hyprpicker rofi-emoji
        brightnessctl playerctl
        xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        squeekboard
        ttf-jetbrains-mono ttf-nerd-fonts-symbols
        polkit-kde-agent
    )
    local pkgs=() p
    for p in "${desired[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1 || pacman -Q "$p" >/dev/null 2>&1; then
            pkgs+=("$p")
        else
            warn "package not available on this SteamOS image: $p"
        fi
    done
    ((${#pkgs[@]})) || die "none of the required packages are available"

    as_root install -d -o "$TARGET_USER" -g "$TARGET_GROUP" "$CACHE"
    if ! as_root pacman -S --needed --noconfirm --cachedir "$CACHE" "${pkgs[@]}"; then
        warn "package transaction failed; if the sync database is missing run:"
        warn "  sudo pacman -Sy"
        die "pacman failed"
    fi
    as_root rm -rf "$CACHE"
}

# -------------------------------------------------------------------- system ---
install_system() {
    log "Installing the SDDM session entry and command symlinks"
    as_root install -d /usr/share/wayland-sessions /usr/local/bin
    as_root install -m644 "$SCRIPT_DIR/system/wayland-sessions/axyl-hyprland.desktop" \
        /usr/share/wayland-sessions/axyl-hyprland.desktop
    local name
    for name in axyl-hyprland-session axyl-switch axyl-deck axyl-osk; do
        as_root ln -sf "$TARGET_HOME/.local/bin/$name" "/usr/local/bin/$name"
    done
}

# ---------------------------------------------------------------------- user ---
backup_user() {
    [[ $REPAIR -eq 1 ]] && return 0
    local backup="$STATE/backup-$(date -u +%Y%m%dT%H%M%SZ)"
    local paths=() rel
    for rel in \
        .config/hypr .config/waybar .config/rofi .config/foot .config/theme \
        .config/mako .config/fastfetch .config/kitty \
        .local/bin/axyl-switch .local/bin/axyl-deck .local/bin/axyl-osk \
        .local/bin/axyl-hyprland-session .local/bin/screenshot \
        .local/bin/start-audio.sh .local/bin/waybar-battery \
        .local/bin/hypr-effects .local/bin/timer \
        .local/share/squeekboard/keyboards \
        "Desktop/Axyl Deck.desktop" \
        .local/share/applications/axyl-switch.desktop \
        .local/share/icons/hicolor/scalable/apps/axyl-deck.svg; do
        [[ -e "$TARGET_HOME/$rel" ]] && paths+=("$rel")
    done
    if ((${#paths[@]})); then
        mkdir -p "$backup"
        tar -C "$TARGET_HOME" -cf "$backup/user-config.tar" "${paths[@]}"
        log "Existing user files backed up to $backup"
    fi
    pacman -Q >"$STATE/packages-before.txt" 2>/dev/null || true
}

copy_configs() {
    log "Installing Hyprland, Waybar, Rofi, Foot and theme configuration"
    local dest="$TARGET_HOME/.config" dir
    mkdir -p "$dest"
    for dir in hypr waybar rofi foot theme mako fastfetch kitty; do
        [[ -d "$REPO_ROOT/skel/.config/$dir" ]] || continue
        mkdir -p "$dest/$dir"
        cp -a "$REPO_ROOT/skel/.config/$dir/." "$dest/$dir/"
    done
    # Deck-specific overlay: monitor/input/Steam config, compact Waybar and the
    # 1280x800 foot/rofi profiles.
    cp -a "$SCRIPT_DIR/config/." "$dest/"

    local bin_dir="$TARGET_HOME/.local/bin"
    mkdir -p "$bin_dir"
    local helper
    for helper in screenshot start-audio.sh waybar-battery battery-guard hypr-effects timer; do
        [[ -f "$REPO_ROOT/skel/.local/bin/$helper" ]] || continue
        install -m755 "$REPO_ROOT/skel/.local/bin/$helper" "$bin_dir/$helper"
    done
    for helper in "$SCRIPT_DIR"/bin/*; do
        install -m755 "$helper" "$bin_dir/$(basename "$helper")"
    done

    chmod 755 "$dest"/rofi/*.sh "$dest"/theme/*.py 2>/dev/null || true
    chmod 755 "$bin_dir"/axyl-* 2>/dev/null || true
}

install_keyboard_layout() {
    # The SteamOS squeekboard package ships the binary without its layout data,
    # so the keyboard stays blank unless we provide a layout ourselves.
    local src="$SCRIPT_DIR/share/squeekboard/us.yaml"
    [[ -f "$src" ]] || return 0
    local dest="$TARGET_HOME/.local/share/squeekboard/keyboards"
    mkdir -p "$dest"
    install -m644 "$src" "$dest/us.yaml"
}

install_desktop_entry() {
    local apps="$TARGET_HOME/.local/share/applications"
    local icons="$TARGET_HOME/.local/share/icons/hicolor/scalable/apps"
    mkdir -p "$apps" "$icons" "$TARGET_HOME/Desktop"
    install -m644 "$SCRIPT_DIR/system/applications/axyl-switch.desktop" \
        "$apps/axyl-switch.desktop"
    install -m644 "$SCRIPT_DIR/system/axyl-deck.svg" "$icons/axyl-deck.svg"
    install -m755 "$SCRIPT_DIR/system/applications/axyl-switch.desktop" \
        "$TARGET_HOME/Desktop/Axyl Deck.desktop"

    if command -v gio >/dev/null 2>&1; then
        gio set "$TARGET_HOME/Desktop/Axyl Deck.desktop" metadata::trusted true \
            >/dev/null 2>&1 || true
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$apps" >/dev/null 2>&1 || true
    fi
}

render_theme() {
    local render="$TARGET_HOME/.config/theme/render.py"
    [[ -x "$render" ]] || return 0
    # Persist the scope so a later manual `render.py` cannot repaint KDE.
    printf 'hypr\n' >"$TARGET_HOME/.config/theme/scope"
    log "Rendering the opencode palette (Hyprland files only)"
    AXYL_RENDER_SCOPE=hypr \
    AXYL_FONT_MONO="JetBrains Mono" \
    AXYL_FONT_ICON="Symbols Nerd Font" \
        "$render" || warn "render.py failed; the session will retry it"
}

stage_tree() {
    local stage="$STATE/tree"
    if [[ "$(readlink -f "$REPO_ROOT")" == "$(readlink -f "$stage" 2>/dev/null || true)" ]]; then
        return 0
    fi
    rm -rf "$stage"
    mkdir -p "$stage/skel/.config" "$stage/skel/.local/bin"
    local dir
    for dir in hypr waybar rofi foot theme mako fastfetch kitty; do
        [[ -d "$REPO_ROOT/skel/.config/$dir" ]] || continue
        cp -a "$REPO_ROOT/skel/.config/$dir" "$stage/skel/.config/"
    done
    local helper
    for helper in screenshot start-audio.sh waybar-battery battery-guard hypr-effects timer; do
        [[ -f "$REPO_ROOT/skel/.local/bin/$helper" ]] || continue
        cp -a "$REPO_ROOT/skel/.local/bin/$helper" "$stage/skel/.local/bin/"
    done
    cp -a "$SCRIPT_DIR" "$stage/steamdeck"
    log "Repair copy staged at $stage"
}

validate() {
    local missing=()
    [[ -x "$TARGET_HOME/.local/bin/axyl-switch" ]] || missing+=("axyl-switch")
    [[ -f "$TARGET_HOME/.config/hypr/hyprland.lua" ]] || missing+=("hyprland.lua")
    [[ -f "$TARGET_HOME/.config/hypr/conf/device.lua" ]] || missing+=("device.lua")
    [[ -f /usr/share/wayland-sessions/axyl-hyprland.desktop ]] || missing+=("session entry")
    if command -v Hyprland >/dev/null 2>&1 || command -v start-hyprland >/dev/null 2>&1; then :; else
        missing+=("hyprland binary")
    fi

    if ! command -v steamosctl >/dev/null 2>&1; then
        warn "steamosctl not found; session switching will not work"
    elif ! steamosctl get-valid-desktop-sessions 2>/dev/null | grep -q 'axyl-hyprland.desktop'; then
        warn "SteamOS does not list axyl-hyprland.desktop yet."
        warn "A reboot or 'sudo systemctl restart sddm' may be required."
    fi

    if ((${#missing[@]})); then
        warn "missing after install: ${missing[*]}"
        return 1
    fi
    return 0
}

user_phase() {
    mkdir -p "$STATE"
    backup_user
    copy_configs
    install_keyboard_layout
    install_desktop_entry
    render_theme
    stage_tree
    log "Setup complete"
    if validate; then
        echo
        echo "Switch now with:  axyl-switch hyprland"
        echo "Or open the app:  axyl-switch"
        echo "Return to Game Mode: axyl-switch game  (or reboot)"
    fi
}

# ---------------------------------------------------------------------- main ---
[[ -d "$REPO_ROOT/skel/.config" ]] || die "skel/.config not found in $REPO_ROOT"
[[ -d "$SCRIPT_DIR/config" ]] || die "steamdeck/config not found"

if [[ $EUID -eq 0 ]]; then
    if [[ "${AXYL_USER_PHASE:-0}" != "1" ]]; then
        [[ $USER_ONLY -eq 0 ]] || die "--user-only cannot be used as root without --user handling"
        [[ $SKIP_PACKAGES -eq 1 ]] || install_packages
        install_system
        log "Switching to $TARGET_USER for the user configuration"
        user_args=(--user-only --yes --user "$TARGET_USER")
        [[ $REPAIR -eq 1 ]] && user_args+=(--repair)
        exec runuser -u "$TARGET_USER" -- \
            env HOME="$TARGET_HOME" AXYL_USER_PHASE=1 \
            "$0" "${user_args[@]}"
    fi
    user_phase
    exit 0
fi

if [[ $USER_ONLY -eq 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "sudo is required for packages and the session entry"
    [[ $SKIP_PACKAGES -eq 1 ]] || install_packages
    install_system
fi

user_phase
