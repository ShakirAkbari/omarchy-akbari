# Changelog

## Unreleased

- Initial release: `install.sh` with default and `-p`/`--personal` modes.
- Keybindings (`config/hypr/bindings.lua`) and look'n'feel
  (`config/hypr/looknfeel.lua`), symlinked into `~/.config/hypr/`.
- Spotify media-key scripts (`bin/spotify-play-key`, `bin/spotify-stop-key`).
- Clones and wires up [hypr-goldenspiral](https://github.com/ShakirAkbari/hypr-goldenspiral)
  (layout + chronobar taskbar).
- Numlock on before any login screen: SDDM greeter `Numlock=on` plus a
  `numlock-console.service` systemd unit for the virtual consoles, since
  SDDM ignores its own numlock setting under autologin.
- Numlock also needed a third fix: the SDDM Wayland greeter runs its own
  Hyprland instance via `/usr/share/sddm/hyprland.lua` (owned by the
  `omarchy-settings` package), which doesn't set `input.numlock_by_default`
  the way the session config does. `install.sh` now installs a copy of that
  file with the setting added, backing up Omarchy's original once so
  `uninstall.sh` can restore it.
- `shakir.workspaces` (the cloned workspace-bar plugin): workspace 10, where
  golden-spiral lives, only showed its spiral icon when Hyprland's live
  workspace list already contained it, which stopped happening once the bar
  became a separate layer-shell dock instead of a tiled window pinned there.
  Hardcoded it into the widget's always-shown ids, same as 1-5.
- Limine boot menu: enables a real `timeout:`, and auto-detects a Windows
  Boot Manager entry via `efibootmgr` to offer as a chainload entry (asks
  for confirmation before writing).
- `-p`/`--personal`: hardcoded monitor layout
  (`config/hypr/monitors.lua.personal`) and a personal package list
  (`packages-personal.txt`) installed via `omarchy pkg add`.
- `-p`/`--personal`: `config/chromium/chromium-flags.conf` symlinked to
  `~/.config/chromium-flags.conf`, enabling NVIDIA hardware video decode
  (`VaapiIgnoreDriverChecks`, `VaapiOnNvidiaGPUs`) which Chromium otherwise
  refuses to use with the NVIDIA driver.
- `hardwareVVizard` deliberately excluded, it's a separate, less-finished
  project.
- `install.sh` asks a yes/no question before every step instead of running
  them all unconditionally; declining a step skips just that one. Piped in
  with no terminal attached, every question defaults to no.
- Limine backup is now lazy: `/boot/limine.conf.bak.<timestamp>` is only
  created the first time a run actually writes to it, not on every re-run,
  and at most once per run even when both the timeout and the Windows entry
  change.
- Added `uninstall.sh`: mirrors `install.sh`, asking before removing each
  piece and only touching what it can verify this repo installed (a symlink
  still pointing here, a require line still present, its comment marker in
  `/boot/limine.conf`). Refuses to delete a dirty `hypr-goldenspiral`
  checkout, and warns before removing the personal package list since that
  can take GPU drivers with it.
