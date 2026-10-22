-- Window, workspace and layer rules.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Assign applications to workspaces (add a line to extend)
local assignments = {
  { name = "brave-to-ws2",  class = "^(brave)$",          workspace = "2" },
  { name = "firefox-to-ws2",  class = "^(firefox)$",          workspace = "2" },
  { name = "code-to-ws3",     class = "^(code-oss)$",         workspace = "3" },
  { name = "dolphin-to-ws4",  class = "^(org.kde.dolphin)$",  workspace = "4" },
  { name = "spotify-to-ws7",  class = "^(Spotify)$",          workspace = "7" },
  { name = "discord-to-ws8",  class = "^(discord)$",          workspace = "8" },
}

for _, a in ipairs(assignments) do
  hl.window_rule({ name = a.name, match = { class = a.class }, workspace = a.workspace })
end

-- Ignore maximize requests from apps
hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
  name = "fix-xwayland-drags",
  match = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },
  no_focus = true,
})

----------------------------------------------------------------------------------------
-- Optional: "smart gaps" (no gaps/border/rounding when a workspace has a single window).
-- Uncomment all four blocks to enable.
----------------------------------------------------------------------------------------
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0 })
-- hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, rounding = 0 })
-- hl.window_rule({ match = { float = false, workspace = "f[1]" },   border_size = 0 })
-- hl.window_rule({ match = { float = false, workspace = "f[1]" },   rounding = 0 })

----------------------------------------------------------------------------------------
-- Optional: blur behind Waybar (its CSS background is 90% opaque, so blur shows subtly).
-- This changes the look, so it is off by default.
----------------------------------------------------------------------------------------
-- hl.layer_rule({ name = "waybar-blur", match = { namespace = "^waybar$" }, blur = true, ignore_alpha = 0.5 })
