-- Runs once, when Hyprland starts (not on config reload).
hl.on("hyprland.start", function()
  local home = os.getenv("HOME") or "/home/axyl"

  -- Artix/runit has no user systemd instance to socket-activate PipeWire, so
  -- launch the audio stack from the session. The guards also keep this safe on
  -- Arch, where the user units may already have started it.
  hl.exec_cmd("bash " .. home .. "/.local/bin/start-audio.sh")

  -- Give the Layer Shell and audio stack a moment to come up before Waybar.
  hl.exec_cmd("sleep 2; waybar")

  -- Notifications (mako) and idle management (hypridle).
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")

  -- Clipboard history store (needs cliphist + wl-clipboard).
  hl.exec_cmd("wl-paste --watch cliphist store")

  -- Bluetooth audio -> default sink helper.
  hl.exec_cmd("sleep 2; bash " .. home .. "/.local/bin/bt-default-sink.sh")

  -- Path is distro-specific (Arch shown). Alternative: hyprpolkitagent.
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
end)
