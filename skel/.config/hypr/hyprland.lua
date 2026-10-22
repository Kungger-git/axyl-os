-- ~/.config/hypr/hyprland.lua
-- Entry point. Needs Hyprland >= 0.55 (Lua config). If a hyprland.lua exists it is
-- loaded instead of hyprland.conf.
--
-- Each require() runs in its own scope, so an error in one module does not stop the
-- others from loading. Because of that, shared values (programs, main modifier) live in
-- conf/variables.lua, which returns a table.

require("conf.monitors")
require("conf.env")
require("conf.autostart")
require("conf.appearance")
require("conf.input")
require("conf.misc")
require("conf.keybinds")
require("conf.rules")
