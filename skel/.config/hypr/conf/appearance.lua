-- Look and feel: general, decoration, animations, layouts.
-- Colors come from conf/palette.lua, which is generated from
-- ~/.config/theme/palette.json by ~/.config/theme/render.py -- change it there.
-- https://wiki.hypr.land/Configuring/Basics/Variables/

local p = require("conf.palette")

-- Hyprland colour type: "rgba(RRGGBBAA)" / "rgb(RRGGBB)".
local function rgba(hex, alpha)
  return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

hl.config({
  general = {
    gaps_in          = 6,
    gaps_out         = 8,
    border_size      = 2,
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",

    col = {
      active_border   = rgba(p.accent),
      inactive_border = rgba(p.border, "aa"),
    },
  },

  decoration = {
    rounding         = 8,
    rounding_power   = 2,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,

    shadow = {
      enabled      = true,
      range        = 6,
      render_power = 2,
      color        = rgba("000000", "b3"),
    },

    -- One blur pass is enough for the two translucent surfaces we have
    -- (Waybar and rofi); kitty is opaque, so this mostly saves GPU time.
    blur = {
      enabled        = true,
      size           = 4,
      passes         = 1,
      ignore_opacity = false,
      vibrancy       = 0.10,
    },
  },

  animations = { enabled = true },

  dwindle = {
    -- NOTE: `dwindle.pseudotile` was removed from Hyprland. Pseudotiling is now
    -- always available; toggle it with mainMod + P (hl.dsp.window.pseudo() in
    -- conf/keybinds.lua).
    preserve_split = true,
  },

  master = { new_status = "master" },
})

-- Curves: a single easing family keeps motion predictable and cheap to reason
-- about. Duration in ms is 1000 / speed, so speeds 5-6 are 167-200 ms.
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })

-- Animations: all 150-250 ms, all easeOutQuint.
hl.animation({ leaf = "global",        enabled = true, speed = 10,  bezier = "easeOutQuint" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 5,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5,   bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 6.5, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 6,   bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 6.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "fade",          enabled = true, speed = 6,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layers",        enabled = true, speed = 5,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 5,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 6.5, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 6,   bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 6.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 6,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 6,   bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 6,   bezier = "easeOutQuint", style = "fade" })
