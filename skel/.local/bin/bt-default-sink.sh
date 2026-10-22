#!/usr/bin/env bash
# Keep a connected Bluetooth audio device as the default PipeWire/Pulse sink.
set -u

last_bt=""

get_default() {
    pactl get-default-sink 2>/dev/null
}

find_bt_sink() {
    pactl list short sinks 2>/dev/null | awk '$2 ~ /^bluez_output\./ { print $2; exit }'
}

apply() {
    local cur bt
    cur=$(get_default)
    bt=$(find_bt_sink)

    if [ -n "$bt" ] && [ "$cur" != "$bt" ]; then
        if pactl set-default-sink "$bt" 2>/dev/null; then
            echo "default sink -> $bt"
        fi
        last_bt="$bt"
    elif [ -z "$bt" ]; then
        last_bt=""
    fi
}

# Handle devices that are already connected when the helper starts.
apply

# React to sinks appearing/disappearing. pactl subscribe exits if pipewire-pulse
# restarts; Hyprland relaunches this helper on the next start.
while read -r line; do
    case "$line" in
        *"on sink"*) apply ;;
    esac
done < <(pactl subscribe)
