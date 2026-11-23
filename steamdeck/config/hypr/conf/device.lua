-- Steam Deck / SteamOS overrides. Loaded last from hyprland.lua via pcall so a
-- normal Axyl install never requires this file.

-- LCD Deck is 1280x800@60; OLED is 1280x800@90. The panel reports native
-- 800x1280 portrait, so transform 3 rotates it into landscape, and scale 1
-- keeps the full 1280x800 logical resolution.
hl.monitor({
  output    = "eDP-1",
  mode      = "preferred",
  position  = "0x0",
  scale     = 1,
  transform = 3,
})
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0.0,
    accel_profile = "adaptive",
    touchpad = {
      natural_scroll     = true,
      tap_to_click       = true,
      clickfinger_behavior = true,
      scroll_factor      = 0.8,
    },

    -- The digitizer reports the panel's native portrait frame (0x0-800x1280),
    -- so without this Hyprland stretches it over the rotated 1280x800 output
    -- and every tap lands far from where it was made. The global option also
    -- covers OLED Decks, whose touch controller has a different name.
    touchdevice = {
      transform = 3,
    },
  },
})

-- Four-finger horizontal swipe switches workspaces (three fingers is left to
-- the applications).
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- The touchscreen needs no per-device entry: its transform is the input-wide
-- `touchdevice` option above, which follows the panel rotation set here.

-- The stock Super+W browser bind points at Brave, which the Deck may not have.
-- hl.bind appends, so the original binds must be removed first.
pcall(hl.unbind, "SUPER + W")
pcall(hl.unbind, "SUPER + L")
hl.bind("SUPER + W",         hl.dsp.exec_cmd("axyl-switch steam"), { description = "Steam Big Picture" })
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("axyl-switch steam"), { description = "Steam Big Picture" })
hl.bind("SUPER + SHIFT + K", hl.dsp.exec_cmd("axyl-osk toggle"),   { description = "On-screen keyboard" })
hl.bind("SUPER + CTRL + K",  hl.dsp.exec_cmd("axyl-osk toggle"),   { description = "On-screen keyboard (alt)" })
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("axyl-switch game --yes"), { description = "Return to Steam Game Mode" })

-- hyprlock is a fullscreen window, so the on-screen keyboard (a layer surface)
-- cannot be drawn above it. Locking on a Deck with no hardware keyboard would
-- be a lockout, so the bind explains the situation instead.
hl.bind("SUPER + L", hl.dsp.exec_cmd(
  "notify-send -a Axyl -t 4000 'Locking is disabled' 'The Deck has no hardware keyboard, so the lock screen cannot be unlocked. Use the power button to sleep, or attach a keyboard and run hyprlock.'"
), { description = "Lock (unavailable without a keyboard)" })

-- The session app is a dialog, not a tiled window.
hl.window_rule({
  name  = "axyl-switch-float",
  match = { class = "^(axyl-switch)$" },
  float = true,
  size  = "760 680",
  center = true,
})

-- Steam Input gives the Deck buttons and trackpads their gamepad mapping and
-- provides the on-screen keyboard inside Steam. It stays in the background so
-- the desktop session keeps working without covering it.
hl.on("hyprland.start", function()
  hl.exec_cmd("steam -silent")
end)
