#!/usr/bin/env bash
# ~/.config/rofi/services.sh
# Rofi menu to start/stop common system services and switch desktop effects.
# Bound to SUPER + SHIFT + M in ~/.config/hypr/conf/keybinds.lua.
#
# Works on both Axyl variants:
#   Arch  -- systemd units (systemctl)
#   Artix -- runit services (sv + runsvdir symlinks)
#
# System services need root: uses passwordless sudo if configured, otherwise
# pkexec (the polkit-gnome agent prompts for your password).
# Wi-Fi toggles use NetworkManager and need no privileges.
#
# Run with --list to print the menu without opening rofi.

set -uo pipefail

THEME="$HOME/.config/rofi/powermenu.rasi"
THEME_OVERRIDE='window { width: 560px; } listview { lines: 8; }'

notify() { notify-send -a "Services" "$1" ${2:+"$2"} 2>/dev/null || true; }

# Run a command as root: passwordless sudo if available, else pkexec.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif sudo -n true 2>/dev/null; then
    sudo -n "$@"
  else
    pkexec "$@"
  fi
}

# ------------------------------------------------------------------- init

init_kind() {
  if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
    echo systemd
  else
    echo runit
  fi
}
INIT=$(init_kind)

# systemd unit name -> runit service name (both variants use the same labels).
runit_name() {
  case "$1" in
    bluetooth.service) echo bluetoothd ;;
    NetworkManager.service) echo NetworkManager ;;
    sshd.service) echo sshd ;;
    docker.service) echo docker ;;
    httpd.service) echo apache ;;
    chronyd.service) echo chrony ;;
    *) echo "${1%.service}" ;;
  esac
}

unit_installed() {
  local unit=$1
  if [ "$INIT" = systemd ]; then
    systemctl list-unit-files "$unit" 2>/dev/null | grep -q "^$unit"
  else
    [ -d "/etc/runit/sv/$(runit_name "$unit")" ]
  fi
}

unit_active() {
  local unit=$1
  if [ "$INIT" = systemd ]; then
    systemctl is-active --quiet "$unit" 2>/dev/null
  else
    sv status "$(runit_name "$unit")" 2>/dev/null | grep -q '^run:'
  fi
}

unit_enabled() {
  local unit=$1 svc
  if [ "$INIT" = systemd ]; then
    systemctl is-enabled --quiet "$unit" 2>/dev/null
  else
    svc=$(runit_name "$unit")
    [ -L "/etc/runit/runsvdir/default/$svc" ]
  fi
}

service_row() {
  local label=$1 unit=$2 active=off boot=off
  unit_active "$unit" && active=on
  unit_enabled "$unit" && boot=on
  printf '%-27s %-6s boot:%s\n' "$label" "$active" "$boot"
}

toggle_service() {
  local label=$1 unit=$2 rc=0 svc
  shift 2

  if unit_active "$unit"; then
    if [ "$INIT" = systemd ]; then
      as_root systemctl disable --now "$unit" "$@" >/dev/null 2>&1 || rc=$?
    else
      svc=$(runit_name "$unit")
      as_root sh -c "sv down '$svc'; rm -f '/etc/runit/runsvdir/default/$svc'" \
        >/dev/null 2>&1 || rc=$?
    fi
    if   [ "$rc" -eq 0 ];   then notify "$label stopped" "disabled at boot"
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then notify "$label: authentication cancelled"
    else notify "$label: could not stop (exit $rc)"; fi
  else
    if [ "$INIT" = systemd ]; then
      as_root systemctl enable --now "$unit" >/dev/null 2>&1 || rc=$?
    else
      svc=$(runit_name "$unit")
      as_root sh -c "ln -sf '/etc/runit/sv/$svc' '/etc/runit/runsvdir/default/$svc'; for i in 1 2 3 4 5; do sv up '$svc' && exit 0; sleep 0.2; done; exit 1" \
        >/dev/null 2>&1 || rc=$?
    fi
    if   [ "$rc" -eq 0 ];   then notify "$label started" "enabled at boot"
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then notify "$label: authentication cancelled"
    else notify "$label: could not start (exit $rc)"; fi
  fi
}

# NetworkManager-wait-online is a oneshot unit: it never stays active, so only
# its boot-time enablement is shown and toggled.
wait_online_row() {
  local boot=off
  unit_enabled NetworkManager-wait-online.service && boot=on
  printf '%-27s boot:%s\n' "Network wait-online" "$boot"
}

toggle_wait_online() {
  local rc=0
  if unit_enabled NetworkManager-wait-online.service; then
    as_root systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || rc=$?
    if   [ "$rc" -eq 0 ];   then notify "Network wait-online disabled" "no boot delay"
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then notify "Network wait-online: authentication cancelled"
    else notify "Network wait-online: could not disable (exit $rc)"; fi
  else
    as_root systemctl enable NetworkManager-wait-online.service >/dev/null 2>&1 || rc=$?
    if   [ "$rc" -eq 0 ];   then notify "Network wait-online enabled" "waits for the network at boot"
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then notify "Network wait-online: authentication cancelled"
    else notify "Network wait-online: could not enable (exit $rc)"; fi
  fi
}

# On systemd, bluetooth.service is D-Bus activated: WirePlumber re-activates it
# as soon as bluetoothd exits, so a plain stop does not stick. Mask it while off
# and block the radio. runit services stay down until `sv up`.
toggle_bluetooth() {
  local rc=0
  if unit_active bluetooth.service; then
    if [ "$INIT" = systemd ]; then
      as_root sh -c 'systemctl mask --now bluetooth; rfkill block bluetooth' >/dev/null 2>&1 || rc=$?
    else
      as_root sh -c 'sv down bluetoothd; rfkill block bluetooth' >/dev/null 2>&1 || rc=$?
    fi
    if   [ "$rc" -eq 0 ];   then notify "Bluetooth disabled"
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then notify "Bluetooth: authentication cancelled"
    else notify "Bluetooth: could not disable (exit $rc)"; fi
  else
    if [ "$INIT" = systemd ]; then
      as_root sh -c 'rfkill unblock bluetooth || true; systemctl unmask bluetooth; systemctl start bluetooth' >/dev/null 2>&1 || rc=$?
    else
      as_root sh -c 'rfkill unblock bluetooth || true; sv up bluetoothd' >/dev/null 2>&1 || rc=$?
    fi
    if   [ "$rc" -eq 0 ];   then notify "Bluetooth enabled"
    elif [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then notify "Bluetooth: authentication cancelled"
    else notify "Bluetooth: could not enable (exit $rc)"; fi
  fi
}

# ---------------------------------------------------------------- Wi-Fi devices

wifi_ifaces() {
  nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
    | awk -F: '$2 == "wifi" && $1 !~ /^p2p-/ { print $1 }'
}

is_usb_iface() {
  local path
  path=$(readlink -f "/sys/class/net/$1/device" 2>/dev/null) || return 1
  case "$path" in */usb*) return 0 ;; *) return 1 ;; esac
}

wifi_state() {
  local iface=$1 state
  state=$(nmcli -t -f DEVICE,STATE device status 2>/dev/null \
    | awk -F: -v d="$iface" '$1 == d { print $2; exit }')
  case "$state" in
    connected)                 echo "connected" ;;
    unmanaged|unavailable|"")  echo "off" ;;
    *)                         echo "$state" ;;
  esac
}

wifi_row() {
  printf '%-27s %s\n' "$1" "$(wifi_state "$2")"
}

# Sets INTERNAL_IFACE / DONGLE_IFACE (empty when absent).
detect_wifi() {
  INTERNAL_IFACE=""
  DONGLE_IFACE=""
  local iface
  for iface in $(wifi_ifaces); do
    if is_usb_iface "$iface"; then
      [ -z "$DONGLE_IFACE" ] && DONGLE_IFACE=$iface
    else
      [ -z "$INTERNAL_IFACE" ] && INTERNAL_IFACE=$iface
    fi
  done
}

toggle_wifi() {
  local label=$1 iface=$2 state
  state=$(nmcli -t -f DEVICE,STATE device status 2>/dev/null \
    | awk -F: -v d="$iface" '$1 == d { print $2; exit }')
  if [ "$state" = "unmanaged" ] || [ -z "$state" ]; then
    if nmcli device set "$iface" managed yes >/dev/null 2>&1; then
      notify "$label enabled"
    else
      notify "$label: could not enable"
    fi
  else
    nmcli device disconnect "$iface" >/dev/null 2>&1 || true
    if nmcli device set "$iface" managed no >/dev/null 2>&1; then
      notify "$label disabled"
    else
      notify "$label: could not disable"
    fi
  fi
}

# ---------------------------------------------------------- Hyprland effects

EFFECTS_BIN="$HOME/.local/bin/hypr-effects"

effects_state() {
  if [ -x "$EFFECTS_BIN" ]; then
    "$EFFECTS_BIN" status 2>/dev/null || echo unknown
  else
    echo unknown
  fi
}

toggle_effects() {
  if [ -x "$EFFECTS_BIN" ] && "$EFFECTS_BIN" toggle >/dev/null 2>&1; then
    case "$(effects_state)" in
      performance) notify "Hyprland effects off" "performance mode" ;;
      full)        notify "Hyprland effects on" "full mode" ;;
      *)           notify "Hyprland effects switched" ;;
    esac
  else
    notify "Hyprland effects: could not switch"
  fi
}

# --------------------------------------------------------------------- menu

build_menu() {
  detect_wifi

  if unit_installed bluetooth.service; then
    service_row "Bluetooth" bluetooth.service
  fi

  unit_installed earlyoom.service && service_row "Early OOM" earlyoom.service

  if [ -n "$INTERNAL_IFACE" ]; then
    wifi_row "Wi-Fi internal ($INTERNAL_IFACE)" "$INTERNAL_IFACE"
  else
    printf '%-27s %s\n' "Wi-Fi internal" "not found"
  fi

  # Only show the dongle when it is physically present.
  if [ -n "$DONGLE_IFACE" ]; then
    wifi_row "Wi-Fi dongle ($DONGLE_IFACE)" "$DONGLE_IFACE"
  fi

  # Only offer services that are actually installed.
  unit_installed docker.service && service_row "Docker" docker.service
  unit_installed sshd.service   && service_row "SSH (sshd)" sshd.service
  unit_installed httpd.service  && service_row "Apache (httpd)" httpd.service
  unit_installed proton.VPN.service && service_row "Proton VPN" proton.VPN.service

  if [ "$INIT" = systemd ] && unit_installed NetworkManager-wait-online.service; then
    wait_online_row
  fi

  if command -v hyprctl >/dev/null 2>&1 && [ -x "$EFFECTS_BIN" ]; then
    printf '%-27s %s\n' "Hyprland effects" "$(effects_state)"
  fi
}

if [ "${1:-}" = "--list" ]; then
  build_menu
  exit 0
fi

while true; do
  menu="$(build_menu)"
  choice="$(printf '%s\n' "$menu" | rofi -dmenu -i -no-custom -p "Services" \
    -theme "$THEME" -theme-str "$THEME_OVERRIDE" \
    -hover-select -me-select-entry '' -me-accept-entry MousePrimary)"

  [ -z "$choice" ] && exit 0

  detect_wifi
  case "$choice" in
    "Bluetooth"*)          toggle_bluetooth ;;
    "Early OOM"*)          toggle_service "Early OOM" earlyoom.service ;;
    "Wi-Fi internal"*)     [ -n "$INTERNAL_IFACE" ] && toggle_wifi "Wi-Fi internal" "$INTERNAL_IFACE" ;;
    "Wi-Fi dongle"*)       [ -n "$DONGLE_IFACE" ] && toggle_wifi "Wi-Fi dongle" "$DONGLE_IFACE" ;;
    "Docker"*)             toggle_service "Docker" docker.service docker.socket ;;
    "SSH"*)                toggle_service "SSH" sshd.service ;;
    "Apache"*)             toggle_service "Apache" httpd.service ;;
    "Proton VPN"*)         toggle_service "Proton VPN" proton.VPN.service ;;
    "Network wait-online"*) toggle_wait_online ;;
    "Hyprland effects"*)   toggle_effects ;;
    *)                     exit 0 ;;
  esac
done
