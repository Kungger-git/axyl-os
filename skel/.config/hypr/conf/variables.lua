-- Shared values. Use in other modules with:  local v = require("conf.variables")
return {
  mainMod     = "SUPER",

  terminal    = "kitty",
  fileManager = "dolphin",
  menu        = "rofi -show drun -theme ~/.config/rofi/style.rasi",
  browser     = "brave-wayland",
  reload      = "hyprctl reload",
}
