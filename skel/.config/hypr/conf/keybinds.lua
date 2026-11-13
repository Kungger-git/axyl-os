-- Keybindings. Same keys as before; only the syntax changed.
-- https://wiki.hypr.land/Configuring/Basics/Binds/
--
-- Every bind carries a `description` so it can be listed by `hyprctl binds`
-- and shown by ~/.config/rofi/keybinds.sh (mainMod + slash).

local v   = require("conf.variables")
local mod = v.mainMod

-- Apps and session
hl.bind(mod .. " + RETURN",         hl.dsp.exec_cmd(v.terminal),   { description = "Open terminal" })
hl.bind(mod .. " + SHIFT + R",      hl.dsp.exec_cmd(v.reload),     { description = "Reload Hyprland config" })
-- hl.bind(mod .. " + SHIFT + Q",   hl.dsp.exit())
hl.bind(mod .. " + SHIFT + Q",      hl.dsp.exec_cmd("~/.config/rofi/powermenu.sh"), { description = "Power menu" })
hl.bind(mod .. " + W",              hl.dsp.exec_cmd(v.browser),     { description = "Open browser" })
hl.bind(mod .. " + E",              hl.dsp.exec_cmd(v.fileManager), { description = "Open file manager" })
hl.bind(mod .. " + D",              hl.dsp.exec_cmd(v.menu),        { description = "App launcher" })
hl.bind(mod .. " + A",              hl.dsp.exec_cmd("rofi -show window -theme ~/.config/rofi/style.rasi"), { description = "Window switcher" })

-- Session and system
hl.bind(mod .. " + L",              hl.dsp.exec_cmd("hyprlock"),    { description = "Lock screen" })
hl.bind(mod .. " + SHIFT + M",      hl.dsp.exec_cmd("~/.config/rofi/services.sh"), { description = "Services menu" })
hl.bind(mod .. " + SHIFT + E",      hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"), { description = "Exit Hyprland" })
hl.bind(mod .. " + SHIFT + B",      hl.dsp.exec_cmd("pkill -SIGUSR2 waybar"), { description = "Reload waybar" })
hl.bind(mod .. " + SHIFT + D",      function()
  -- DPMS must not be toggled directly from a bind; delay it slightly.
  hl.timer(function()
    hl.dispatch(hl.dsp.dpms({ action = "disable" }))
  end, { timeout = 500, type = "oneshot" })
end, { description = "Turn off displays" })

-- Screenshots (hyprshot + slurp). The print key's keysym is "Print".
-- -z freezes the screen first so menus/tooltips stay put while you drag the region.
hl.bind("Print",                    hl.dsp.exec_cmd("hyprshot -m region -z"),                  { description = "Screenshot: region" })
hl.bind(mod .. " + SHIFT + C",      hl.dsp.exec_cmd("hyprshot -m region -z"),                  { description = "Screenshot: region (alt)" })
hl.bind(mod .. " + SHIFT + A",      hl.dsp.exec_cmd("hyprshot -m region -z --clipboard-only"), { description = "Screenshot: region to clipboard" })
hl.bind("SHIFT + Print",            hl.dsp.exec_cmd("hyprshot -m window"),                     { description = "Screenshot: window" })
hl.bind(mod .. " + Print",          hl.dsp.exec_cmd("hyprshot -m output"),                     { description = "Screenshot: output" })
hl.bind(mod .. " + C",              hl.dsp.exec_cmd("hyprpicker"),         { description = "Colour picker" })

-- Window management
hl.bind(mod .. " + Q",              hl.dsp.window.close(),                        { description = "Close window" })
hl.bind(mod .. " + V",              hl.dsp.window.float({ action = "toggle" }),   { description = "Toggle floating" })
hl.bind(mod .. " + P",              hl.dsp.window.pseudo(),                       { description = "Toggle pseudotile (dwindle)" })
hl.bind(mod .. " + J",              hl.dsp.layout("togglesplit"),                 { description = "Toggle split (dwindle)" })
hl.bind(mod .. " + F",              hl.dsp.window.fullscreen({ action = "toggle" }), { description = "Toggle fullscreen" })
hl.bind(mod .. " + SHIFT + F",      hl.dsp.window.fullscreen({ action = "toggle", mode = "maximized" }), { description = "Toggle maximize" })
hl.bind(mod .. " + SHIFT + P",      hl.dsp.window.pin(),                          { description = "Pin window" })
hl.bind(mod .. " + CTRL + C",       hl.dsp.window.center(),                       { description = "Center window" })
hl.bind(mod .. " + grave",          hl.dsp.window.alter_zorder({ mode = "top" }), { description = "Raise window to top" })

-- Swap window with its neighbour in a direction
hl.bind(mod .. " + SHIFT + left",   hl.dsp.window.swap({ direction = "left" }),   { description = "Swap window left" })
hl.bind(mod .. " + SHIFT + right",  hl.dsp.window.swap({ direction = "right" }),  { description = "Swap window right" })
hl.bind(mod .. " + SHIFT + up",     hl.dsp.window.swap({ direction = "up" }),     { description = "Swap window up" })
hl.bind(mod .. " + SHIFT + down",   hl.dsp.window.swap({ direction = "down" }),   { description = "Swap window down" })

-- Resize the active window with the keyboard (hold to repeat)
hl.bind(mod .. " + CTRL + left",    hl.dsp.window.resize({ x = -20, y = 0,   relative = true }), { repeating = true, description = "Resize window left" })
hl.bind(mod .. " + CTRL + right",   hl.dsp.window.resize({ x = 20,  y = 0,   relative = true }), { repeating = true, description = "Resize window right" })
hl.bind(mod .. " + CTRL + up",      hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true, description = "Resize window up" })
hl.bind(mod .. " + CTRL + down",    hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true, description = "Resize window down" })

-- Move focus
hl.bind(mod .. " + left",           hl.dsp.focus({ direction = "left" }),  { description = "Focus left" })
hl.bind(mod .. " + right",          hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mod .. " + up",             hl.dsp.focus({ direction = "up" }),    { description = "Focus up" })
hl.bind(mod .. " + down",           hl.dsp.focus({ direction = "down" }),  { description = "Focus down" })

-- Cycle windows
hl.bind("ALT + TAB", function()
  hl.dispatch(hl.dsp.window.cycle_next())
  hl.dispatch(hl.dsp.window.bring_to_top())
end, { description = "Cycle windows" })

-- Window groups (tabbed containers)
hl.bind(mod .. " + G",              hl.dsp.group.toggle(),                        { description = "Toggle window group" })
hl.bind(mod .. " + SHIFT + G",      hl.dsp.group.lock(),                          { description = "Lock window group" })
hl.bind(mod .. " + TAB",            hl.dsp.group.next(),                          { description = "Next window in group" })
hl.bind(mod .. " + SHIFT + TAB",    hl.dsp.group.prev(),                          { description = "Previous window in group" })
hl.bind(mod .. " + CTRL + TAB",     hl.dsp.group.move_window({ forward = true }), { description = "Move window in group" })

-- Workspaces 1-10 (key 0 = workspace 10)
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key,               hl.dsp.focus({ workspace = i }), { description = "Focus workspace " .. i })
  hl.bind(mod .. " + SHIFT + " .. key,        hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
  hl.bind(mod .. " + SHIFT + ALT + " .. key,  hl.dsp.window.move({ workspace = i, follow = false }), { description = "Move window to workspace " .. i .. " (silent)" })
end

-- Monitors (multi-monitor setups)
hl.bind(mod .. " + ALT + left",     hl.dsp.focus({ monitor = "left" }),  { description = "Focus monitor left" })
hl.bind(mod .. " + ALT + right",    hl.dsp.focus({ monitor = "right" }), { description = "Focus monitor right" })
hl.bind(mod .. " + SHIFT + ALT + left",  hl.dsp.window.move({ monitor = "left" }),  { description = "Move window to monitor left" })
hl.bind(mod .. " + SHIFT + ALT + right", hl.dsp.window.move({ monitor = "right" }), { description = "Move window to monitor right" })

-- Scratchpad
hl.bind(mod .. " + S",              hl.dsp.workspace.toggle_special("magic"), { description = "Toggle scratchpad" })
hl.bind(mod .. " + SHIFT + S",      hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to scratchpad" })

-- Scroll through existing workspaces
hl.bind(mod .. " + mouse_down",     hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mod .. " + mouse_up",       hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

-- Move / resize with the mouse
hl.bind(mod .. " + mouse:272",      hl.dsp.window.drag(),   { mouse = true, description = "Drag window (mouse)" })
hl.bind(mod .. " + mouse:273",      hl.dsp.window.resize(), { mouse = true, description = "Resize window (mouse)" })

-- Clipboard history (needs cliphist + wl-clipboard)
hl.bind(mod .. " + X",              hl.dsp.exec_cmd("cliphist list | rofi -dmenu -theme ~/.config/rofi/style.rasi | cliphist decode | wl-copy"), { description = "Clipboard history" })
-- Keybind cheat sheet
hl.bind(mod .. " + slash",          hl.dsp.exec_cmd("~/.config/rofi/keybinds.sh"), { description = "Keybind cheat sheet" })
-- Theme picker (opencode built-in themes -> entire desktop)
hl.bind(mod .. " + SHIFT + T",      hl.dsp.exec_cmd("~/.config/theme/themes.py pick"), { description = "Theme picker" })

-- Resize mode: mainMod + R, then resize with the arrows; Esc/Enter exits.
hl.bind(mod .. " + R", hl.dsp.submap("resize"), { description = "Enter resize mode" })
hl.define_submap("resize", function()
  hl.bind("left",  hl.dsp.window.resize({ x = -20, y = 0,   relative = true }), { repeating = true, description = "[resize] left" })
  hl.bind("right", hl.dsp.window.resize({ x = 20,  y = 0,   relative = true }), { repeating = true, description = "[resize] right" })
  hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true, description = "[resize] up" })
  hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true, description = "[resize] down" })
  hl.bind("escape", hl.dsp.submap("reset"), { description = "[resize] exit" })
  hl.bind("return", hl.dsp.submap("reset"), { description = "[resize] exit" })
end)

-- Volume and brightness (work on the lock screen, repeat while held)
local hold = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",     hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), hold)
hl.bind("XF86AudioLowerVolume",     hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      hold)
hl.bind("XF86AudioMute",            hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     hold)
hl.bind("XF86AudioMicMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   hold)
hl.bind("XF86MonBrightnessUp",      hl.dsp.exec_cmd("brightnessctl s 10%+"),                           hold)
hl.bind("XF86MonBrightnessDown",    hl.dsp.exec_cmd("brightnessctl s 10%-"),                           hold)

-- Media keys (requires playerctl)
local locked = { locked = true }
hl.bind("XF86AudioNext",            hl.dsp.exec_cmd("playerctl next"),       locked)
hl.bind("XF86AudioPause",           hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPlay",            hl.dsp.exec_cmd("playerctl play-pause"), locked)
hl.bind("XF86AudioPrev",            hl.dsp.exec_cmd("playerctl previous"),   locked)
