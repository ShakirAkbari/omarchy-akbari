# Changelog

## Unreleased

- `-p`/`--personal`: `config/hypr/monitors.lua.personal` now binds golden-spiral's
  workspace (10) to the main ultrawide as its default via
  `hl.workspace_rule({ workspace = "10", monitor = "...", default = true })`,
  so it's what's showing after a fresh session start instead of whatever
  workspace Hyprland last remembered. Confirmed this merges cleanly with
  hypr-goldenspiral's own `hl.workspace_rule` call for the same workspace
  (which sets `layout`, not `monitor`/`default`) rather than one overwriting
  the other; checked via `hyprctl workspacerules` and `hyprctl activeworkspace`.
- `-p`/`--personal`: new `shakir.spotify` bar widget
  (`config/omarchy/plugins/shakir.spotify/`) showing Spotify's current track
  with play/pause/skip, added to the start of `shell.json`'s right bar
  section with an `omarchy.spacer` (size 400) right after it, so it sits in
  the gap between the clock/weather and the tray/network/etc. cluster
  instead of glued to either. Title flashes briefly on track change. Reads
  `Quickshell.Services.Mpris` directly rather than Omarchy's `omarchy.media`
  service, which third-party
  bar widgets can't reach (see the README section on why).
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
- `-p`/`--personal`: `install.sh` now actually installs the
  `shakir.workspaces` bar widget (`config/omarchy/plugins/shakir.workspaces/`)
  into `~/.config/omarchy/plugins/` and swaps it in for `omarchy.workspaces`
  in `shell.json`'s bar layout via `jq`. The plugin file had been tracked in
  the repo since an earlier commit but was never wired into `install.sh`, so
  a fresh clone never actually reproduced it.
- Fixed `bindings.lua`, `looknfeel.lua`, `monitors.lua`, `chromium-flags.conf`,
  and both spotify key scripts having silently become plain file copies on
  the author's machine instead of the symlinks `install.sh` creates (content
  matched, so nothing broke, but repo updates stopped propagating). Relinked;
  cause not fully diagnosed, but an editor doing an atomic write-then-rename
  over a symlinked path is the most likely explanation.
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
