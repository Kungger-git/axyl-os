#!/usr/bin/env bash
# Start the per-user PipeWire stack from a Wayland session.
#
# Arch starts these through systemd user units, while Artix/runit has no user
# service manager. Using systemd on Arch avoids racing the socket units it
# already owns; the manual path is only for non-systemd sessions.
set -u

# systemd-based systems: let the user manager own the sockets and services.
if command -v systemctl >/dev/null 2>&1 &&
   systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user start pipewire.socket pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 && exit 0
fi

# Artix/runit (and any session without a systemd user manager): start the
# daemons directly. Wait briefly for PipeWire before starting its clients.
start_if_missing() {
    local name="$1"
    shift
    pgrep -x "$name" >/dev/null && return 0
    setsid "$@" </dev/null >/dev/null 2>&1 &
}

start_if_missing pipewire pipewire
for _ in $(seq 1 20); do
    pgrep -x pipewire >/dev/null && break
    sleep 0.2
done

start_if_missing wireplumber wireplumber
sleep 0.5
start_if_missing pipewire-pulse pipewire-pulse
