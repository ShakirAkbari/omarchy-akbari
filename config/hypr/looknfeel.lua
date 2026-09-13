-- Change the default Omarchy look'n'feel.

-- Layout is now the custom "lua:goldenspiral" registered in hypr/goldenspiral.lua
-- (required from hyprland.lua after this file). The dwindle experiment below is
-- kept commented for quick fallback.
-- hl.config({
--   general = { layout = "dwindle" },
--   dwindle = { default_split_ratio = 0.764, force_split = 2, preserve_split = false },
-- })

-- Slight overshoot when the layout repositions/resizes a window, so the
-- re-tiling reads as a slide rather than a hard snap.
hl.curve("offStage", { type = "bezier", points = { { 0.2, 1.3 }, { 0.4, 1 } } })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "offStage" })

-- Global blur, off in Omarchy defaults. Turned on for the Aero-glass app dock
-- (hypr/autostart.lua adds the per-layer blur rule). Omarchy's windows are
-- opaque, so this only shows where something is actually translucent.
hl.config({
  decoration = {
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      noise = 0.015,
      contrast = 1.1,
      brightness = 1.0,
      vibrancy = 0.2,
    },
  },
})

-- CENTER-MASTER LAYOUT (previous experiment, kept for quick toggle-back):
-- hl.config({
--   general = { layout = "master" },
--   master = {
--     new_status = "master", new_on_top = true, orientation = "center",
--     slave_count_for_center_master = 1, mfact = 0.72,
--   },
-- })


-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
