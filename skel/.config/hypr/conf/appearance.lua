-- Look and feel: general, decoration, animations, layouts.
-- Colors come from conf/palette.lua and the layout (gaps, rounding, blur) from
-- conf/design.lua; both are generated from ~/.config/theme/palette.json by
-- ~/.config/theme/render.py -- change it there.
-- https://wiki.hypr.land/Configuring/Basics/Variables/

local p = require("conf.palette")
local d = require("conf.design")

-- Hyprland colour type: "rgba(RRGGBBAA)" / "rgb(RRGGBB)".
local function rgba(hex, alpha)
  return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

hl.config({
  general = {
    gaps_in          = d.gaps_in,
    gaps_out         = d.gaps_out,
    border_size      = d.border_size,
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",

    col = {
      active_border   = rgba(p.accent),
      inactive_border = rgba(p.border, "aa"),
    },
  },

  decoration = {
    rounding         = d.rounding,
    rounding_power   = 2,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,

    shadow = {
      enabled      = d.shadow,
      range        = d.shadow_range,
      render_power = d.shadow_power,
      color        = rgba("000000", "b3"),
    },

    -- Blur is a per-design choice: the flat and chunky designs turn it off
    -- entirely to save GPU time.
    blur = {
      enabled        = d.blur,
      size           = d.blur_size,
      passes         = d.blur_passes,
      ignore_opacity = false,
      vibrancy       = d.blur_vibrancy,
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
