-- Runs once, when Hyprland starts (not on config reload).
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")

  -- Notifications (mako) and idle management (hypridle).
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")

  -- Clipboard history store (needs cliphist + wl-clipboard).
  hl.exec_cmd("wl-paste --watch cliphist store")

  -- Path is distro-specific (Arch shown). Alternative: hyprpolkitagent.
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
end)
