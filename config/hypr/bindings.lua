-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Spotlight-style launcher: SUPER+SPACE opens the app search directly
-- (was: Omarchy root category menu). Type an app name, press Enter to launch.
-- Root menu is still available on SUPER+ALT+SPACE below.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Spotlight (apps)", "omarchy-menu toggle apps")
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Omarchy root menu", "omarchy-menu toggle")

-- Golden-spiral layout controls live in hypr/goldenspiral.lua
-- (SUPER+M rotate, SUPER+= / SUPER+- grow/shrink mainstage, SUPER+0 reset).

-- Media play button: launch Spotify if not running, else start playback
-- (was: play/pause current media).
hl.unbind("XF86AudioPlay")
o.bind("XF86AudioPlay", "Spotify: launch / play", "spotify-play-key", { locked = true })
-- Media stop button: 1 press stops playback, 2 quick presses quit Spotify.
o.bind("XF86AudioStop", "Spotify: stop / (2x) quit", "spotify-stop-key", { locked = true })
