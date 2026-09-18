# omarchy-shakir

A post-install setup for [Omarchy](https://omarchy.org). Run this once after a
fresh Omarchy install and it gets a machine to the state I actually use:
keybindings, look'n'feel, the [golden-spiral layout](https://github.com/ShakirAkbari/hypr-goldenspiral)
and its taskbar, numlock on before you ever see a login screen, and a Limine
boot menu that actually shows up and can chainload Windows.

```
+-----------------------------------------------------------------+
|  install.sh                                                     |
|                                                                  |
|  bindings.lua, looknfeel.lua  ---->  ~/.config/hypr/            |
|  spotify-play-key, -stop-key  ---->  ~/.local/bin/               |
|  hypr-goldenspiral (cloned)   ---->  ~/Projects/, its own        |
|                                       install.sh (which in turn  |
|                                       clones/updates and wires   |
|                                       up hypr-chronobar as a     |
|                                       dependency), then wired    |
|                                       into hyprland.lua          |
|  numlock (sddm + systemd)     ---->  /etc/sddm.conf.d/,          |
|                                       /etc/systemd/system/,      |
|                                       /usr/share/sddm/           |
|                                       hyprland.lua (backed up)   |
|  Windows dual-boot entry      ---->  ~/.local/state/            |
|                                       omarchy-shakir/             |
|                                       windows-boot-guid (only     |
|                                       asked about when            |
|                                       efibootmgr reports more     |
|                                       than one)                   |
|  Limine timeout + Windows     ---->  /boot/limine.conf           |
|                                       (uses the entry above,      |
|                                        asks first)                |
|  Remmina Host key             ---->  ~/.config/remmina/          |
|                                       remmina.pref (Right Ctrl    |
|                                       -> Scroll Lock, if present) |
|  Remmina audio redirect       ---->  ~/.config/remmina/          |
|                                       remmina.pref (new RDP       |
|                                       connections default to      |
|                                       sound=local, if present)    |
|  xwayland-primary-monitor     ---->  ~/.local/bin/, wired into    |
|                                       autostart.lua               |
|                                       (o.exec_on_start)           |
|  chromium-flags.conf          ---->  ~/.config/                  |
|                                       chromium-flags.conf (NVIDIA |
|                                       video decode, only offered  |
|                                       if an NVIDIA GPU is found)  |
|  plymouth-theme-sync           ---->  ~/.local/bin/, patches       |
|                                       /usr/share/plymouth/themes/  |
|                                       omarchy/omarchy.script       |
|                                       (backed up), optionally a    |
|                                       theme-set hook               |
|  omarchy-reboot-to-windows     ---->  ~/.local/bin/, wired into    |
|                                       the System menu via          |
|                                       ~/.config/omarchy/           |
|                                       extensions/                  |
|                                       omarchy-menu.jsonc           |
|                                                                  |
|  -p / --personal only:                                          |
|    monitors.lua.personal      ---->  ~/.config/hypr/monitors.lua |
|    shakir.workspaces plugin   ---->  ~/.config/omarchy/plugins/, |
|                                       swapped in for              |
|                                       omarchy.workspaces in       |
|                                       shell.json's bar layout     |
|    shakir.spotify plugin      ---->  ~/.config/omarchy/plugins/, |
|                                       added to shell.json's        |
|                                       bar layout (right section)  |
|    packages-personal.txt      ---->  omarchy pkg add             |
+-----------------------------------------------------------------+
```

## Install

```sh
git clone https://github.com/ShakirAkbari/omarchy-shakir.git ~/Projects/omarchy-shakir
cd ~/Projects/omarchy-shakir
./install.sh
```

It asks a yes/no question before each step (keybindings, Spotify keys,
hypr-goldenspiral, numlock, Limine, fix Right Ctrl in Remmina (remap host
key), Remmina's audio redirect default, xwayland-primary-monitor, NVIDIA
hardware video decode for Chromium (only offered if an NVIDIA GPU is
detected), Plymouth boot screen theming, the System menu's Reboot to
Windows entry, and each personal-only piece), so you can decline anything
you don't want on a given run. Piped in with no terminal attached
(`curl ... | bash`), every question defaults to no.

One step is a numbered choice instead of yes/no: if efibootmgr reports more
than one Windows Boot Manager entry (a stale leftover from a previous
install, or a since-removed drive, is common), it asks which one is your
real Windows install and remembers the answer. The Limine dual-boot entry
and the System menu's Reboot to Windows entry both depend on this
resolving to exactly one entry, so on a machine with more than one and no
answer given (or none to begin with), those two steps have nothing to
offer that run rather than guessing.

Re-running is safe and does not create duplicates: existing files it would
overwrite get backed up next to themselves as `<file>.bak.<timestamp>`
(once, the first time, not on every run), already-correct symlinks and
already-present `hyprland.lua` require lines are left alone, and the Limine
config is only backed up when it's actually about to change.

Remmina's default Host key is Right Ctrl, which it grabs locally for its own
shortcuts (fullscreen, keyboard grab toggle, disconnect, etc.) instead of
forwarding it to the remote session. That eats combos like Ctrl+Shift+Arrow
when you use the right-hand Ctrl key. If `~/.config/remmina/remmina.pref`
already exists, install.sh offers to rebind the Host key to Scroll Lock
instead, freeing Right Ctrl back up. Remmina rewrites that file on exit, so
quit it first (including the tray icon, not just the window) or the change
gets clobbered.

Remmina's default for a new RDP connection is `sound=off`, so remote audio
never reaches your speakers unless you turn it on per connection. install.sh
offers to flip the default to `sound=local` in `remmina.pref`'s `[remmina]`
section instead, so every new RDP connection you create starts out
redirecting remote audio to this computer. It only changes the default for
connections created from then on, not any `.remmina` profile that already
exists. Same caveat as the Host key: quit Remmina first, or it clobbers the
change on exit.

Hyprland and XWayland never designate a primary monitor on their own: X11
apps that ask for "the" monitor instead of a specific one just get whichever
output happened to enumerate first, size and orientation aside. That's how a
Steam/Proton game in fullscreen can land on a small or 90 degree rotated
secondary monitor showing a portrait window, instead of the main display.
install.sh offers to install `xwayland-primary-monitor`, a script that picks
the connected output with the largest pixel area and sets it as the X11
primary, wired into `~/.config/hypr/autostart.lua` so it reruns (and thus
persists) every session, since XWayland forgets this setting on every
restart.

install.sh also offers to recolor the Plymouth boot/unlock screen (and
SDDM's login theme) to match whichever Omarchy theme is currently selected,
plus an OMARCHY wordmark and a small signature watermark, optionally kept in
sync automatically on every future theme switch via a hook. See
[Why plymouth-theme-sync patches the script directly, and how it stays
synced](#why-plymouth-theme-sync-patches-the-script-directly-and-how-it-stays-synced)
below for details. Not personal-only: this benefits anyone running Omarchy.

Add `-p` / `--personal` only on my own machines: it also installs a hardcoded
monitor layout, the startup-workspace fix, both bar widgets, and my full
extra package list (gaming, virtualization, NVIDIA drivers, work apps). Skip
it everywhere else.

```sh
./install.sh --personal
```

## Uninstall

```sh
./uninstall.sh
```

Mirrors `install.sh`: asks a yes/no question before removing each piece, and
only touches something if it can verify this repo actually put it there (a
symlink still pointing here, a require line still present, an omarchy-shakir
comment marker in `/boot/limine.conf`). Anything it doesn't recognize, or
that's already gone, is reported and left alone rather than guessed at.

A few things it won't do for you:

- The Limine boot timeout is left at 5s rather than reverted, since there's
  no single reliable "previous value" to go back to. Restore a
  `/boot/limine.conf.bak.*` yourself if you want it back.
- `hypr-goldenspiral`'s cloned directory is only offered for deletion if its
  git tree is clean; uncommitted changes there are left in place with a
  warning.
- Removing the personal package list (`omarchy pkg drop`) can remove GPU
  drivers and other packages other software depends on. It asks, but the
  warning is real: don't say yes to this on a whim.

## What it does not touch

- `hardwareVVizard` (a live-metrics wallpaper) is a separate, less-finished
  project and is intentionally not part of this repo.
- `input.lua` and `hyprland.lua`'s body are left as-is, beyond adding the
  one `require("hypr.goldenspiral")` line if it's missing.
  `autostart.lua` is left as-is too, beyond adding the one
  `o.exec_on_start("xwayland-primary-monitor")` line if you confirm that
  step.
- Anything not listed in the diagram above. This installs config, not a
  full system image.

## Requirements

- Omarchy (checked at the top of `install.sh`; the `o.*` / `hl.*` Lua config
  API this repo uses is Omarchy's, not vanilla Hyprland).
- `sudo` access, for the numlock service and (if you confirm it) the Limine
  edit.
- Limine as the bootloader, for the boot-menu step. If it's not present,
  that step is skipped with a message; everything else still runs.

## Why numlock needs three fixes

SDDM's own `Numlock=on` setting is ignored once autologin is enabled, which
is Omarchy's default. So this also installs a small systemd service that
turns numlock on for every virtual console (`setleds -D +num`) before any
login screen renders, independent of SDDM.

Neither of those reaches the greeter you actually see, though: on Omarchy,
SDDM's Wayland greeter is itself a Hyprland session, started via its own
config at `/usr/share/sddm/hyprland.lua` (separate from `~/.config/hypr/`,
and owned by the `omarchy-settings` package, not this repo). That config
doesn't set `input.numlock_by_default`, so numpad digits don't register when
typing your password there even with the other two fixes in place. This repo
installs a copy of that file with `numlock_by_default = true` added, backed
up once to `hyprland.lua.bak.omarchy-shakir` so uninstall can restore
Omarchy's original. It gets overwritten back to Omarchy's default by any
`omarchy update` that touches `omarchy-settings`, so re-run `install.sh`
after one if numlock stops working at the greeter again.

## Why shakir.spotify reads Mpris directly instead of Omarchy's media service

Omarchy ships a built-in `omarchy.media` service with full MPRIS metadata and
play/pause/skip, but it's only reachable through `firstPartyServiceFor`, and
that call is sandboxed to `kind: "bar"` plugins (full bar replacements) and
clones of `omarchy.indicators` specifically; an ordinary third-party
bar-widget like this one gets `null` back, silently. `SpotifyWidget.qml`
instead imports `Quickshell.Services.Mpris` directly (the same module
`omarchy.media`'s own service is built on) and reimplements the small slice
of play/pause/skip logic it needs against whichever player's `dbusName` or
`desktopEntry` matches Spotify.

## Why the Chromium flags need VaapiIgnoreDriverChecks

Chromium's own VA-API wrapper skips any driver named "nvidia" by default,
since NVIDIA's backend isn't on Google's supported list, even though
`libva-nvidia-driver` bridges VA-API to NVDEC just fine. `VaapiIgnoreDriverChecks`
and `VaapiOnNvidiaGPUs` bypass that check so hardware video decode (YouTube
included) actually gets used instead of silently falling back to software.
Not personal-only: `install.sh` detects an NVIDIA GPU itself (`lspci -d
'10de:'`) and offers this step on any machine that has one, installing
`libva-nvidia-driver` if it isn't already present. Since `chromium-flags.conf`
only applies from a cold start, this needs a full Chromium quit and relaunch
to take effect, and running `omarchy-refresh-chromium` will overwrite it
back to the Omarchy default (re-run `install.sh` to restore it).

## Why plymouth-theme-sync patches the script directly, and how it stays synced

Omarchy's own `omarchy plymouth set` / `set-by-theme` commands only ever
touch colors and the logo image; a themed recolor actually swaps out
Omarchy's `logo.png` (the pixel-art OMARCHY wordmark itself) for the theme's
own icon-only `unlock.png`, and there's no supported way to add extra text
back to that screen. `bin/plymouth-theme-sync` (installed to
`~/.local/bin/`) handles both: it calls `omarchy plymouth set-by-theme` with
either the theme slug it's given, or (with none) whichever theme is
currently selected, read from `~/.local/state/omarchy/current/theme.name`;
missing or empty, it falls back to `omarchy plymouth reset` instead,
Omarchy's own stock Plymouth/SDDM look, rather than guessing a theme. It then
patches the installed
`/usr/share/plymouth/themes/omarchy/omarchy.script` directly: an OMARCHY
`Image.Text` wordmark centered under the icon (in place of the one themed
recolor swapped out), and a small signature watermark in the bottom-right
corner, in a color sampled straight back out of a freshly recolored asset
(`bullet.png`) rather than re-derived separately, so both always match
whatever the recolor above just did, theme-agnostically. The password field
(and everything positioned relative to it: lock icon, bullets, progress bar)
shifts down to sit under the wordmark instead of directly under the icon.
Inserting the wordmark and watermark is one-time (each guarded on its own
marker text, and the pre-patch script backed up once to
`omarchy.script.bak.omarchy-shakir`), but recoloring them is not: every run
repaints both to the current sampled color, so a later theme switch updates
them the same way it already updates the icon, lock, entry, and bullet
images.

`install.sh` runs `plymouth-theme-sync` once, and optionally installs it
as a `theme-set` hook via `omarchy hook install theme-set` (Omarchy runs
every script under `~/.config/omarchy/hooks/theme-set.d/` after `omarchy
theme set`, passing the new theme's slug as `$1`), so it reruns on its own
after every future theme switch, receiving exactly the argument
`plymouth-theme-sync` already expects. A hook has no terminal to answer a
sudo password prompt (the theme switcher itself is a graphical, non-terminal
trigger), and this setup has no askpass helper or polkit agent configured
either, so `plymouth-theme-sync` only proceeds unattended when sudo can
already go non-interactively (a still-warm credential cache, `sudo -n true`).
Otherwise, rather than hanging on a prompt nothing can answer, it opens a
held-open terminal (`omarchy-launch-terminal`) that re-runs itself there, so
the sudo prompt lands somewhere you'll see it and the sync still completes;
if `omarchy-launch-terminal` itself isn't available, it falls back to a
desktop notification (if `notify-send` is available) telling you to run it
yourself.

`/usr/share/plymouth/themes/omarchy/omarchy.script` is owned by the
`omarchy-settings` package, so re-running `omarchy plymouth set*` yourself,
or an `omarchy update` that touches that package, overwrites the recolor,
wordmark, and watermark alike; re-run `plymouth-theme-sync` (or `install.sh`)
if the boot screen reverts to stock Omarchy branding.

## Why the Limine step asks before writing

Every step asks before it does anything, but the Limine one asks twice: once
before touching `/boot/limine.conf` at all, and again before adding a
Windows entry specifically. The Windows entry is built from a partition GUID
read out of `efibootmgr`.
If a machine has multiple Windows Boot Manager entries (stale ones from a
previous install are common), this picks the first and tells you what else
it found. Confirm before it writes anything; if it picked the wrong one,
edit the GUID in `/boot/limine.conf` yourself afterward.

## License

MIT, see `LICENSE`.
