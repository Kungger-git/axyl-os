-- https://wiki.hypr.land/Configuring/Basics/Variables/#misc
hl.config({
  misc = {
    disable_hyprland_logo   = true,               -- no Hyprland logo on the wallpaper
    force_default_wallpaper = 0,                  -- no mascot wallpaper
    background_color        = "rgba(0a0a0aff)",   -- solid opencode background
  },
})

-- Hyprland 0.57 enables `quirks:skip_non_kms_dmabuf_formats` by default, so it only
-- advertises dmabuf formats that can be scanned out directly. On some GPUs that hides
-- all RGBA formats, which leaves EGL clients that request an alpha channel (kitty)
-- with no usable EGLConfig. Restore the pre-0.57 behaviour of advertising every
-- renderable format.
hl.config({ quirks = { skip_non_kms_dmabuf_formats = false } })

-- NOTE: `misc.vfr` was removed. VFR is now the debug keyword `debug.vfr`, and it
-- is enabled by default ("do not turn off unless debugging"), so nothing needs
-- to be set here. If you ever need to force it explicitly:
--   hl.config({ debug = { vfr = true } })
