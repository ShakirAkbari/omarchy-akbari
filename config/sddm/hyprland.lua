-- Minimal Hyprland config for the SDDM Wayland greeter.
-- SDDM starts the greeter itself after the compositor is ready.
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },

  animations = {
    enabled = false,
  },

  input = {
    -- Match the main session: without this the greeter's own compositor
    -- starts with numlock off, so numpad digits don't work when typing
    -- the login password.
    numlock_by_default = true,
  },
})
