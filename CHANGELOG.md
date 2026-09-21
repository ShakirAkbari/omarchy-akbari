# Changelog

## Unreleased

- `install.sh` / `uninstall.sh`: Chromium hybrid GPU fix. On a machine with
  an NVIDIA GPU plus an AMD or Intel one, Omarchy's session-wide
  `LIBVA_DRIVER_NAME=nvidia` made Chromium decode video on the NVIDIA card
  while it renders on the other GPU, so YouTube video was black or frozen
  (`Failed to create EGLImage` in the logs, sometimes a GPU process crash).
  New `bin/chromium` wrapper (unsets `LIBVA_DRIVER_NAME` and `NVD_BACKEND`
  for Chromium only, linked to `~/.local/bin/chromium`) plus a generated
  `~/.local/share/applications/chromium.desktop` that launches it. The NVDEC
  flags step is now only offered on NVIDIA-only machines; on a hybrid one the
  wrapper is offered instead. On a hybrid machine that already linked
  `chromium-flags.conf` from an earlier install, the step also offers to
  remove that link and restore the backed-up Omarchy default flags;
  `uninstall.sh` removes both pieces.
- Renamed the project from `omarchy-shakir` to `omarchy-akbari`. Backups,
  the Limine entry comment and the saved-state directory now use the new
  name (`*.bak.omarchy-akbari`, `comment: added by omarchy-akbari`,
  `~/.local/state/omarchy-akbari/`). Files an older install already made
  under `omarchy-shakir` are still recognized: `install.sh` won't re-back
  up over an existing `.bak.omarchy-shakir`, `bin/omarchy-pick-windows-boot-entry`
  falls back to the old state file, and `uninstall.sh` restores from or
  removes the old-named backups and Limine entry too. Symlinks installed
  under the old checkout path need re-running `install.sh` from the renamed
  directory (or re-linking) once.
- `install.sh` / `uninstall.sh`: new Claude app launcher step. Adds
  `Claude.desktop` (opens `claude` in a tiled terminal via
  `xdg-terminal-exec --app-id=TUI.tile`, like Omarchy's own Docker and Disk
  Usage entries) and a Claude icon to the app launcher. Only offered when
  `claude` is on PATH.
- Removed the numlock-on-boot step from `install.sh` (the SDDM greeter
  config, the patched `/usr/share/sddm/hyprland.lua` and the
  `numlock-console` systemd service): it was buggy. `config/sddm/` and
  `config/systemd/` are gone and the remaining install steps are
  renumbered. `uninstall.sh` still offers to remove what an older install
  left behind (disables the service, deletes its files, restores the
  greeter's Hyprland config from backup), so run it on any machine that
  already has numlock-on-boot installed.
- `install.sh` and `uninstall.sh`: fix the Limine step silently doing
  nothing. `/boot` is root-only on a stock Omarchy install (the ESP is
  mounted with umask 0077), so `[ -f /boot/limine.conf ]` and the `grep`
  checks run as the user all failed, and the step reported "no
  /boot/limine.conf, skipping" with the timeout and Windows entry never
  applied. Every read of the file now goes through `sudo`.
- `install.sh -p`: new services step after the package list. Asks about
  enabling and starting `libvirtd`, `tailscaled`, `coolercontrold` and
  `ollama` one by one (skipping any whose package isn't installed or
  whose unit is already enabled), and offers to add the user to the
  `libvirt` group.
- `packages-personal.txt`: dropped `linux-headers`. Omarchy boots
  `linux-omarchy`, which ships its own headers, so the stock kernel's
  headers only made DKMS build every module a second time.
- `install.sh`: the personal package list (`-p`) installed nothing, because
  `omarchy pkg add` is pacman-only and one AUR entry (e.g. `coolercontrol`,
  `zoom`) made pacman abort the whole transaction with `target not found`.
  Packages are now split by `pacman -Si` into repo packages
  (`omarchy pkg add`) and AUR packages (`omarchy pkg aur add`). Each
  package not already installed is now asked about individually, and only
  the ones answered yes are installed.
- `install.sh`: the NVIDIA hardware video decode Chromium flags
  (`chromium-flags.conf`) are no longer gated behind `-p`/`--personal`.
  `install.sh` now detects an NVIDIA GPU itself (`lspci -d '10de:'`) and
  offers the step on any machine that has one, installing
  `libva-nvidia-driver` first if it isn't already present, instead of
  relying on it being pulled in by the personal package list.
- Adds a "Reboot to Windows" entry to the Omarchy System menu
  (`bin/omarchy-reboot-to-windows`, wired in via
  `config/omarchy/omarchy-menu.jsonc`): sets the UEFI BootNext flag to
  whichever Windows Boot Manager entry `efibootmgr` reports and reboots.
  BootNext is one-shot, so BootOrder, and Omarchy as the regular default,
  is untouched on every boot after that. Only offered by `install.sh`, and
  only shows in the menu, on a machine efibootmgr reports a Windows entry
  for.
- New `bin/omarchy-pick-windows-boot-entry`: resolves which Windows Boot
  Manager entry is "the" one to use, shared by `install.sh`'s Limine
  dual-boot step and `omarchy-reboot-to-windows` so both agree instead of
  running their own copy of the logic. A machine can carry more than one
  such entry (a stale leftover from a previous install, or a
  since-removed drive, is common), and there's no UEFI-level "most
  recently booted" to sort that out automatically, so `install.sh` asks
  once (a new step 5) and saves the choice; a single entry needs no
  asking. Neither Windows step below offers anything until this resolves,
  rather than guessing.
- `install.sh`: the Limine boot menu step now also renames the lowercase
  `linux` kernel entry (and its Snapper history entries) to `Arch Linux`,
  matching the title case of the `Omarchy` and `Windows 11` entries
  alongside it. Backs up `limine.conf` first; once renamed, re-running the
  step finds nothing left to do and skips it.
- `bin/plymouth-theme-sync`: when the theme-set hook fires with no terminal
  and no cached sudo credentials, it now opens a held-open terminal
  (`omarchy-launch-terminal`) that re-runs the sync there instead of just
  notifying and giving up, so a theme switch's sudo prompt lands somewhere
  you'll actually see it and the boot/login screen recolor still happens.
  Falls back to the old notify-send message if `omarchy-launch-terminal`
  isn't available.
- `-p`/`--personal`: `config/hypr/monitors.lua.personal` now pins workspace 1
  to the main ultrawide (`hl.workspace_rule({ workspace = "1", monitor =
  "..." })`) so it stays that monitor's normal home workspace and never gets
  claimed by the portrait monitor below, and gives the portrait monitor
  (Dell U2211H) its own dedicated workspace 11, outside the 1-9 range used
  for SUPER + `<number>` switching, as its default so it's always what's
  showing there at session start instead of whatever Hyprland last
  remembered.
- `shakir.workspaces`: always shows workspace 11 (the portrait monitor's
  dedicated workspace) the same way as workspace 10 (golden-spiral), since
  nothing keeps either in Hyprland's live workspace list while unoccupied.
  Shows a monitor-on-a-stand glyph instead of the number (tall screen,
  narrow neck with a hinge dot, flat base, all square-cornered), sized to
  fill nearly the whole button (95% of it) since it has no outer frame
  unlike the golden-spiral icon's boxed square, then follows the normal
  occupied/focused dimming rule (unlike 10, which stays bright regardless
  since golden-spiral/chronobar keeps it permanently occupied).
- `-p`/`--personal`: `install.sh` now offers to start every session on
  golden-spiral's workspace (10, on the main ultrawide) via
  `~/.config/hypr/autostart.lua` (`o.exec_on_start`). Monitors attach
  asynchronously at boot, and whichever one attaches last tends to end up as
  Hyprland's initially focused monitor regardless of the `workspace_rule`
  `default` settings above (those pick which workspace shows on a monitor,
  not which monitor holds keyboard/cursor focus, and don't force a workspace
  switch on an already-running session); since the portrait monitor is
  declared second in `monitors.lua.personal`, it was winning that race, so
  the session could start on whatever workspace instead of golden-spiral,
  and anything that opens on "the active monitor" (the Spotlight launcher
  included) landed on the portrait monitor right after login. This build of
  Hyprland (Omarchy's Lua config layer) doesn't take plain `hyprctl dispatch
  <dispatcher> <args>`; dispatchers are Lua calls under `hl.dsp.*` run via
  `hl.dispatch(...)`. Switching straight to workspace 10
  (`hl.dispatch(hl.dsp.focus({ workspace = "10" }))`, the same call
  `bindings.lua` uses for SUPER + `<number>`) both puts golden-spiral on
  screen and pulls monitor focus onto the ultrawide as a side effect, since a
  workspace only ever lives on one monitor. Confirmed via `hyprctl eval`:
  forced focus onto the portrait monitor's workspace 11 first, then this
  moved both the active workspace and the focused monitor back in one call.
- New `bin/plymouth-theme-sync`, installed to
  `~/.local/bin/`, recolors the Plymouth boot/unlock screen (and SDDM's
  login theme) to match a given Omarchy theme, or whichever theme is
  currently selected if none is given (`~/.local/state/omarchy/current/theme.name`,
  falling back to `omarchy plymouth reset`, Omarchy's stock look, if that's
  unreadable), via `omarchy plymouth set-by-theme`. A themed recolor swaps
  Omarchy's own `logo.png`, the pixel-art OMARCHY wordmark, for the theme's
  icon-only `unlock.png`; since there's no Omarchy-supported way to add
  extra text back to that screen, this also patches
  `/usr/share/plymouth/themes/omarchy/omarchy.script` directly: an OMARCHY
  `Image.Text` wordmark centered under the icon, and a small
  `(w/ Shakir's postscripts)` watermark in the bottom-right corner, both in
  a color sampled straight back out of a freshly recolored asset so they
  stay theme-agnostic, and the password field repositioned to sit under the
  wordmark. Inserting them is one-time (backed up once to
  `omarchy.script.bak.omarchy-shakir`), but recoloring them happens on every
  run. `install.sh` runs it once (not personal-only: the recolor just
  follows whichever Omarchy theme is already selected, nothing hardware- or
  author-specific), and can also install it as a
  `theme-set` hook (`omarchy hook install theme-set`) so it reruns
  automatically after every future `omarchy theme set`; the hook only
  proceeds unattended when sudo can go non-interactive (a still-warm
  credential cache), since it has no terminal or askpass/polkit agent to
  answer a password prompt otherwise, and bails with a desktop notification
  instead of hanging when it can't. Everything here gets overwritten by a
  manual `omarchy plymouth set*` or an `omarchy update` touching
  `omarchy-settings`, same caveat as the numlock SDDM config below.
  `uninstall.sh` mirrors this: removes the hook, the `~/.local/bin/` symlink,
  and restores the pre-patch script from its backup if present.
- `install.sh` now offers to install `bin/xwayland-primary-monitor` into
  `~/.local/bin/` and wire it into `~/.config/hypr/autostart.lua`
  (`o.exec_on_start`). Hyprland/XWayland never pick a primary monitor on
  their own, so X11 apps that ask for "the" monitor rather than a specific
  one (Steam/Proton games going fullscreen) can land on whichever output
  happens to enumerate first, regardless of size or orientation, which is
  how a fullscreen game ended up on a rotated secondary monitor instead of
  the main ultrawide. The script waits for XWayland to come up (it starts
  lazily, on first X11 client), then sets whichever connected output has
  the largest pixel area as primary. Runs once per session via autostart so
  it survives reboots, since XWayland does not remember the setting across
  restarts. `uninstall.sh` mirrors this: removes the symlink and the
  autostart line, only if both are still present.
- `install.sh` now offers to default new Remmina RDP connections to
  `sound=local` in `~/.config/remmina/remmina.pref`'s `[remmina]` section,
  instead of Remmina's own default of `sound=off`. Remote audio then
  redirects to this computer's speakers out of the box for any RDP
  connection created afterward, without having to flip it per connection.
  `uninstall.sh` mirrors this, restoring `sound=off`, but only when it finds
  `sound=local` still set. Both scripts check for a running Remmina first,
  since it rewrites this file on exit and would otherwise clobber the change.
- `install.sh` now offers to rebind Remmina's Host key from Right Ctrl to
  Scroll Lock in `~/.config/remmina/remmina.pref`, if that file exists.
  Right Ctrl as the Host key gets grabbed locally for Remmina's own
  shortcuts, which was swallowing Ctrl+Shift+Arrow (and other right-Ctrl
  combos) before they reached the remote session. `uninstall.sh` mirrors
  this, restoring 65508 (Right Ctrl), but only when it can verify the value
  is still what this repo set (65300). Both scripts check for a running
  Remmina first, since it rewrites this file on exit and would otherwise
  clobber the change.
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
