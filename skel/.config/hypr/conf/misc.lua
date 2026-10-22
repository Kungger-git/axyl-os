-- https://wiki.hypr.land/Configuring/Basics/Variables/#misc
hl.config({
  misc = {
    disable_hyprland_logo   = true,               -- no Hyprland logo on the wallpaper
    force_default_wallpaper = 0,                  -- no mascot wallpaper
    background_color        = "rgba(0a0a0aff)",   -- solid opencode background
  },
})

-- NOTE: `misc.vfr` was removed. VFR is now the debug keyword `debug.vfr`, and it
-- is enabled by default ("do not turn off unless debugging"), so nothing needs
-- to be set here. If you ever need to force it explicitly:
--   hl.config({ debug = { vfr = true } })
