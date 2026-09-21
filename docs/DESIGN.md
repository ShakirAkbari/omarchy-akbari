# Design notes

This is a post-install script, not a distro or a system image. It exists
because getting from a fresh Omarchy install to the desktop in the README's
diagram was 20+ manual steps across `~/.config`, `/etc`, and `/boot`, spread
across several sessions of trial and error. This repo collapses that back
into one idempotent script.

## Why a separate repo, not one big dotfiles dump

The layout and taskbar already live in their own repo,
[hypr-goldenspiral](https://github.com/ShakirAkbari/hypr-goldenspiral), with
its own install script, tests, and CI. Duplicating that code here would mean
two copies drifting apart. So `install.sh` clones and delegates to it instead
of vendoring it: this repo owns the things that don't have a home elsewhere
(keybindings, look'n'feel, the Limine menu) and orchestrates the
rest.

## Why `-p` / `--personal` exists

Two of the things this repo installs are not generic:

- **Monitor layout.** `hl.monitor(...)` calls that name exact monitor
  descriptions (e.g. `desc:Microstep MSI MAG401QR`). Shipping that as the
  default would break anyone whose monitors are not this exact pair.
- **Package list.** Steam, NVIDIA drivers, work apps (Teams, Outlook,
  OnlyOffice) are what I run, not a recommendation for anyone else's machine.

Rather than leave these out entirely, they're gated behind a flag so the
same repo serves both cases: `./install.sh` for anyone who wants the shared
parts (keybindings, look'n'feel, layout, boot menu), `./install.sh
-p` for setting up one of my own machines.

## Why the Limine entry is auto-detected, not hardcoded

A GPT partition GUID is per-machine (per-install, really: reinstalling
Windows can change it). Hardcoding one would only ever work on the machine
it was captured from. `efibootmgr -v` already knows where Windows Boot
Manager lives on this specific machine, so `install.sh` parses that instead
of asking the user to go find a GUID by hand. It's still a confirmation
prompt, not an unconditional write, because a machine can have more than
one Windows Boot Manager entry (stale ones from a prior install are common)
and picking the wrong one, while not destructive, means Windows won't
actually chain-load. If that happens, tell it apart from `efibootmgr -v`
and edit the GUID in `/boot/limine.conf` directly.

## What's deliberately out of scope

- **hardwareVVizard** (a live-metrics wallpaper via a custom `hyprwinwrap`
  build). It works, but it depends on rebuilding a Hyprland plugin against
  whatever `aquamarine` version happens to be installed, which breaks every
  time that library gets an ABI bump ahead of upstream Hyprland's pin. That
  is not something to hand to someone else's machine yet.
- **A full system image.** This installs config on top of an existing
  Omarchy install; it does not partition disks, install Omarchy itself, or
  manage encryption/TPM/Secure Boot. Those are Omarchy's job, not this
  repo's.
