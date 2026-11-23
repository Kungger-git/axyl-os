-- Runs once, when Hyprland starts (not on config reload).
hl.on("hyprland.start", function()
  hl.exec_cmd("~/.local/bin/start-audio.sh")
  hl.exec_cmd("waybar")

  -- Notifications (mako) and idle management (hypridle).
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")

  -- Clipboard history store (needs cliphist + wl-clipboard).
  hl.exec_cmd("wl-paste --watch cliphist store")

  -- Path is distro-specific. Prefer polkit-gnome (Arch ISO), then the KDE
  -- agent (SteamOS Deck), then hyprpolkitagent.
  hl.exec_cmd("sh -c 'for a in /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 /usr/lib/polkit-kde-authentication-agent-1 /usr/lib/hyprpolkitagent/hyprpolkitagent; do [ -x \"$a\" ] && exec \"$a\"; done'")
end)
