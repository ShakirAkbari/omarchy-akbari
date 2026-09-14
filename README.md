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
|                                       install.sh, then wired     |
|                                       into hyprland.lua          |
|  numlock (sddm + systemd)     ---->  /etc/sddm.conf.d/,          |
|                                       /etc/systemd/system/,      |
|                                       /usr/share/sddm/           |
|                                       hyprland.lua (backed up)   |
|  Limine timeout + Windows     ---->  /boot/limine.conf           |
|                                       (auto-detected via         |
|                                        efibootmgr, asks first)   |
|                                                                  |
|  -p / --personal only:                                          |
|    monitors.lua.personal      ---->  ~/.config/hypr/monitors.lua |
|    chromium-flags.conf      ---->  ~/.config/chromium-flags.conf |
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
hypr-goldenspiral, numlock, Limine, and each personal-only piece), so you
can decline anything you don't want on a given run. Piped in with no
terminal attached (`curl ... | bash`), every question defaults to no.

Re-running is safe and does not create duplicates: existing files it would
overwrite get backed up next to themselves as `<file>.bak.<timestamp>`
(once, the first time, not on every run), already-correct symlinks and
already-present `hyprland.lua` require lines are left alone, and the Limine
config is only backed up when it's actually about to change.

Add `-p` / `--personal` only on my own machines: it also installs a hardcoded
monitor layout, Chromium flags enabling NVIDIA hardware video decode, and my
full extra package list (gaming, virtualization, NVIDIA drivers, work apps).
Skip it everywhere else.

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
- `autostart.lua`, `input.lua`, and `hyprland.lua`'s body are left as-is,
  beyond adding the one `require("hypr.goldenspiral")` line if it's missing.
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
