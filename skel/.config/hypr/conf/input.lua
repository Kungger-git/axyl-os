-- https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    kb_layout    = "us",
    follow_mouse = 1,
    sensitivity  = 0, -- -1.0 to 1.0, 0 = no modification

    touchpad = { natural_scroll = false },
  },
})

-- Touchpad workspace swipe (off, as before). Replaces the old gestures:workspace_swipe.
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Per-device example from the stock config; "epic-mouse-v1" is a placeholder name.
-- hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
