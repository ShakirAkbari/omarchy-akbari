# omarchy-shakir

Post-install setup for [Omarchy](https://omarchy.org). Run this once after a
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
|  Limine timeout + Windows     ---->  /boot/limine.conf           |
|                                       (auto-detected via         |
|                                        efibootmgr, asks first)   |
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
|    chromium-flags.conf      ---->  ~/.config/chromium-flags.conf |
|    Plymouth boot screen       ---->  /usr/share/plymouth/themes/  |
|                                       omarchy/omarchy.script       |
|                                       (patched, backed up)         |
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
hypr-goldenspiral, numlock, Limine, Remmina's Host key, Remmina's audio
redirect default, xwayland-primary-monitor, and each personal-only piece),
so you can decline
anything you don't want on a given run. Piped in with no terminal attached
(`curl ... | bash`), every question defaults to no.

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

Add `-p` / `--personal` only on my own machines: it also installs a hardcoded
monitor layout, Chromium flags enabling NVIDIA hardware video decode, a
Plymouth boot screen recolored to match whichever theme is currently selected
plus a small signature watermark, and my full extra package list (gaming,
virtualization, NVIDIA drivers, work apps). Skip it everywhere else.

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
`libva-nvidia-driver` (installed alongside the NVIDIA packages above) bridges
VA-API to NVDEC just fine. `VaapiIgnoreDriverChecks` and `VaapiOnNvidiaGPUs`
bypass that check so hardware video decode actually gets used instead of
silently falling back to software. Since `chromium-flags.conf` only applies
from a cold start, this needs a full Chromium quit and relaunch to take
effect, and running `omarchy-refresh-chromium` will overwrite it back to the
Omarchy default (re-run `install.sh -p` to restore it).

## Why the Plymouth watermark patches the script directly

Omarchy's own `omarchy plymouth set` / `set-by-theme` commands only ever
touch colors and the logo image, there's no supported way to add extra text
to the boot/unlock screen. So this step reads the currently selected theme
straight from `~/.local/state/omarchy/current/theme.name` and calls
`omarchy plymouth set-by-theme` with it (for the theme recolor, which also
carries over to SDDM's login theme); if that file is missing or empty, it
falls back to `omarchy plymouth reset` instead, Omarchy's own stock
Plymouth/SDDM look, rather than guessing a theme. Either way it then patches
the installed
`/usr/share/plymouth/themes/omarchy/omarchy.script` directly: it inserts a
small `Image.Text` sprite right after the main logo sprite is created,
anchored to the bottom-right corner. The patch is idempotent (checks for its
own marker text first) and the pre-patch script is backed up once to
`omarchy.script.bak.omarchy-shakir`. That file is owned by the
`omarchy-settings` package, so re-running `omarchy plymouth set*` yourself,
or an `omarchy update` that touches that package, overwrites both the
recolor and the watermark; re-run `install.sh -p` if the boot screen reverts
to stock Omarchy branding. This is also a one-shot recolor rather than a live
hook, so switching themes afterward with `omarchy theme set` leaves the boot
screen on whichever theme was active when `install.sh -p` last ran, until you
re-run it.

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
