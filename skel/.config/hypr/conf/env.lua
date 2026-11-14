-- Environment variables
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Truecolor, so opencode/themes render at full fidelity.
hl.env("COLORTERM", "truecolor")

-- Qt. Standardised on Kvantum; keep ~/.config/environment.d in sync.
-- "wayland;xcb" lets Qt fall back to XWayland for apps without a Wayland plugin.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- Session
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
