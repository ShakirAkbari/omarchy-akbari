#!/usr/bin/env bash
# omarchy-akbari installer. Idempotent: safe to re-run after a git pull.
# Asks before every change it makes, so a re-run only touches what you say
# yes to. Needs a real terminal to ask; piped in via `curl | bash` with no
# tty, every question defaults to no and nothing gets installed.
#
# Default: config that is safe and useful for anyone (keybindings, look'n'feel,
# a Limine boot menu with a real timeout).
#
# -p / --personal: also offers machine-specific pieces (monitor layout,
# full package list) that only make sense on the author's own machines.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_DIR/hypr"
BIN_DIR="$HOME/.local/bin"
PROJECTS_DIR="$HOME/Projects"
PERSONAL=0

say()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m !!\033[0m %s\n' "$*"; }
err()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: install.sh [-p|--personal] [-h|--help]

  -p, --personal   Also install machine-specific config (monitor layout,
                    full personal package list). Skip this on someone
                    else's machine.
  -h, --help       Show this help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--personal) PERSONAL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument: $1"; usage; exit 1 ;;
  esac
  shift
done

# Ask a yes/no question on the real terminal, even when this script is
# piped in via `curl | bash`. Defaults to no if there's no terminal at all.
confirm() {
  local prompt="$1" reply
  if [ -t 0 ]; then
    read -r -p "$prompt [y/N] " reply
  elif { exec 3<>/dev/tty; } 2>/dev/null; then
    # /dev/tty exists as a node but opening it can still fail (ENXIO) when
    # this process has no controlling terminal at all, e.g. detached from a
    # session; `[ -e /dev/tty ]` alone doesn't catch that. The brace group
    # keeps the stderr silencing scoped to this attempt, not the whole shell.
    read -r -p "$prompt [y/N] " reply <&3
    exec 3<&-
  else
    warn "no terminal available, assuming no for: $prompt"
    return 1
  fi
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# link <src> <dest>: symlink, backing up an existing non-symlink target once.
link() {
  local src="$1" dest="$2"
  if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
    return 0
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    warn "backed up existing $dest"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  say "linked $dest -> $src"
}

# require_line <file> <line>: append a line if it is not already present.
require_line() {
  local file="$1" line="$2"
  if ! grep -qF "$line" "$file" 2>/dev/null; then
    printf '\n%s\n' "$line" >> "$file"
    say "added '$line' to $file"
  fi
}

if ! command -v omarchy >/dev/null 2>&1; then
  err "this needs Omarchy: https://omarchy.org (the 'omarchy' command was not found)"
  exit 1
fi

say "This installs the omarchy-akbari config, one piece at a time."
say "Each step below explains what it does, then asks yes/no; say no to skip it."
say "  Nothing here is silent: every change is announced as it happens, and"
say "  anything it would overwrite is backed up next to itself first."
[ "$PERSONAL" -eq 1 ] && say "Running with --personal: machine-specific steps (monitor layout, full package list) will be offered too."
printf '\n'

# 1. Keybindings and look'n'feel -------------------------------------------- #
say "Keybindings and look'n'feel: adds these on top of Omarchy's defaults:"
say "  - SUPER+SPACE: Spotlight-style app search (was: Omarchy root menu)"
say "  - SUPER+ALT+SPACE: Omarchy root menu (moved here)"
say "  - Media Play key: launch/play Spotify (was: play/pause current media)"
say "  - Media Stop key: stop Spotify, double-press to quit"
say "  - Window-move animation gets a slight overshoot instead of a hard snap"
say "  - Blur turned on for the golden-spiral dock (Omarchy ships this off)"
if confirm "Install bindings.lua and looknfeel.lua into $HYPR_DIR?"; then
  link "$REPO/config/hypr/bindings.lua" "$HYPR_DIR/bindings.lua"
  link "$REPO/config/hypr/looknfeel.lua" "$HYPR_DIR/looknfeel.lua"
else
  say "skipped keybindings and look'n'feel"
fi

# 2. Spotify media-key scripts ----------------------------------------------- #
say "Spotify media-key scripts: the two scripts behind step 1's Play/Stop"
say "  bindings above."
say "  - spotify-play-key: launches Spotify if it isn't running yet,"
say "    otherwise toggles play/pause."
say "  - spotify-stop-key: a single press pauses playback; a second press"
say "    within 400ms quits Spotify instead (asks it to quit cleanly first,"
say "    falls back to SIGTERM)."
if confirm "Install these into $BIN_DIR?"; then
  mkdir -p "$BIN_DIR"
  for script in spotify-play-key spotify-stop-key; do
    link "$REPO/bin/$script" "$BIN_DIR/$script"
    chmod +x "$REPO/bin/$script"
  done
else
  say "skipped Spotify media-key scripts"
fi

# 3. Golden-spiral layout + chronobar taskbar --------------------------------- #
say "Golden-spiral layout + chronobar taskbar:"
say "  - hypr-goldenspiral: a custom Hyprland tiling layout. The window"
say "    you're working in becomes a large mainstage; every other window"
say "    reflows into a golden-ratio-proportioned column around it, so a"
say "    new window gets the biggest free tile instead of splitting the"
say "    screen in half again."
say "  - hypr-chronobar: a companion app bar/taskbar; goldenspiral carves"
say "    space out for it automatically whenever it's running."
say "  Clones both from github.com/ShakirAkbari into $PROJECTS_DIR (or pulls"
say "  updates if already cloned), and wires goldenspiral into hyprland.lua."
if confirm "Install golden-spiral + chronobar?"; then
  GOLDENSPIRAL_DIR="$PROJECTS_DIR/hypr-goldenspiral"
  mkdir -p "$PROJECTS_DIR"
  if [ -d "$GOLDENSPIRAL_DIR/.git" ]; then
    say "updating hypr-goldenspiral"
    git -C "$GOLDENSPIRAL_DIR" pull --ff-only
  else
    say "cloning hypr-goldenspiral"
    git clone https://github.com/ShakirAkbari/hypr-goldenspiral.git "$GOLDENSPIRAL_DIR"
  fi
  sh "$GOLDENSPIRAL_DIR/install.sh"
  require_line "$HYPR_DIR/hyprland.lua" 'require("hypr.goldenspiral")'
else
  say "skipped hypr-goldenspiral"
fi

# 4. Windows dual-boot: pick which entry, if more than one --------------------- #
# Not personal-only, and independent of whether the Limine and System-menu
# steps below are used or even applicable on this machine. There's no
# UEFI-level "most recently booted" to sort out which Windows Boot Manager
# entry is the real one when there's more than one (a stale leftover from
# a previous install, or a since-removed drive, is common) -- firmware
# doesn't track that -- so this asks once and saves the answer; the steps
# below only offer anything Windows-related once this (or a single
# unambiguous entry) resolves. Declining, or a non-interactive run, just
# leaves those steps with nothing to offer this time, rather than
# guessing which entry is real.
if command -v efibootmgr >/dev/null 2>&1; then
  chmod +x "$REPO/bin/omarchy-pick-windows-boot-entry"
  if ! "$REPO/bin/omarchy-pick-windows-boot-entry" >/dev/null 2>&1; then
    mapfile -t win_entries < <("$REPO/bin/omarchy-pick-windows-boot-entry" --list 2>/dev/null)
    if [ "${#win_entries[@]}" -gt 1 ]; then
      say "Windows dual-boot: efibootmgr reports more than one Windows Boot"
      say "  Manager entry on this machine (a stale leftover from a previous"
      say "  install, or a since-removed drive, is common; firmware doesn't"
      say "  track which one is current)."
      say "  Picking one here feeds both the Limine boot menu entry (step 5)"
      say "  and the System menu's Reboot to Windows entry (step 11) below;"
      say "  skipping this leaves both with nothing to offer this run."
      i=1
      for entry in "${win_entries[@]}"; do
        IFS=$'\t' read -r _ name _ <<< "$entry"
        printf '  %d) %s\n' "$i" "$name"
        i=$((i + 1))
      done
      choice=""
      if [ -t 0 ] || [ -e /dev/tty ]; then
        read -r -p "Which one is your real Windows install? [1-${#win_entries[@]}, blank to skip] " choice < /dev/tty
      fi
      if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "${#win_entries[@]}" ] 2>/dev/null; then
        IFS=$'\t' read -r _ picked_name picked_guid <<< "${win_entries[$((choice - 1))]}"
        WINDOWS_STATE_FILE="$HOME/.local/state/omarchy-akbari/windows-boot-guid"
        mkdir -p "$(dirname "$WINDOWS_STATE_FILE")"
        printf '%s\n' "$picked_guid" > "$WINDOWS_STATE_FILE"
        say "saved '$picked_name' as the Windows entry to use"
      else
        say "no choice made; the Limine and System-menu Windows steps below will have nothing to offer this run"
      fi
    fi
  fi
fi

# 5. Limine boot menu: real timeout + Windows dual-boot entry ---------------- #
LIMINE_CONF="/boot/limine.conf"
say "Limine boot menu: sets a 5-second timeout (Omarchy's default has none, so"
say "  the menu flashes past) and can add a Windows entry. Backs up the file first."
# /boot is usually root-only (the ESP is mounted with umask 0077), so every
# read of the file goes through sudo; a plain [ -f ] or grep as the user would
# see nothing there and silently skip this whole step. The question comes
# first so the sudo password prompt isn't a surprise.
if ! confirm "Update the Limine boot menu? (asks for your sudo password)"; then
  say "skipped Limine timeout"
elif ! sudo test -f "$LIMINE_CONF"; then
  warn "no $LIMINE_CONF, skipping Limine setup (not using Limine, or ESP mounted elsewhere)"
else
  # Only back up once per run, and only if a write actually happens below,
  # so re-running with nothing left to change doesn't pile up .bak files.
  limine_backed_up=0
  limine_backup() {
    if [ "$limine_backed_up" -eq 0 ]; then
      sudo cp "$LIMINE_CONF" "$LIMINE_CONF.bak.$(date +%s)"
      say "backed up $LIMINE_CONF"
      limine_backed_up=1
    fi
  }

  if sudo grep -qE '^timeout: *(0|no) *$' "$LIMINE_CONF" 2>/dev/null || \
     ! sudo grep -qE '^timeout:' "$LIMINE_CONF" 2>/dev/null; then
    limine_backup
    if sudo grep -qE '^#?timeout:' "$LIMINE_CONF"; then
      sudo sed -i -E 's/^#?timeout:.*/timeout: 5/' "$LIMINE_CONF"
    else
      printf 'timeout: 5\n' | sudo tee -a "$LIMINE_CONF" > /dev/null
    fi
    say "set Limine menu timeout to 5s"
  else
    say "Limine timeout already active, left as-is"
  fi

  if sudo grep -qE '^[[:space:]]*/+linux[[:space:]]*$' "$LIMINE_CONF" 2>/dev/null; then
    limine_backup
    sudo sed -i -E 's|^([[:space:]]*/+)linux[[:space:]]*$|\1Arch Linux|' "$LIMINE_CONF"
    say "renamed 'linux' kernel entries to 'Arch Linux' in the boot menu"
  fi

  if command -v efibootmgr >/dev/null 2>&1 && ! sudo grep -q '^/+Windows' "$LIMINE_CONF"; then
    # Same picker step 4 above already made executable and, if there was
    # more than one entry, already asked about; this just uses its answer.
    if ! pick="$("$REPO/bin/omarchy-pick-windows-boot-entry")"; then
      say "no Windows Boot Manager entry resolved (none found, or more than"
      say "  one with nothing chosen in step 4), skipping dual-boot entry"
    else
      IFS=$'\t' read -r _ name guid <<< "$pick"
      if confirm "Add a Limine entry chainloading '$name' at partition $guid?"; then
        limine_backup
        {
          printf '\n/+%s\n' "$name"
          printf '    comment: added by omarchy-akbari\n'
          printf '    protocol: efi\n'
          printf '    path: guid(%s):/EFI/Microsoft/Boot/bootmgfw.efi\n' "$guid"
        } | sudo tee -a "$LIMINE_CONF" > /dev/null
        say "added Windows entry to Limine menu"
      else
        say "skipped adding the Windows entry"
      fi
    fi
  fi
fi

# 6. Fix Right Ctrl in Remmina (remap host key) ------------------------------ #
REMMINA_PREF="$CONFIG_DIR/remmina/remmina.pref"
if [ -f "$REMMINA_PREF" ]; then
  say "Remmina Right Ctrl fix: Remmina's default Host key is Right Ctrl,"
  say "  which intercepts every Right-Ctrl combo (Ctrl+Shift+Arrow, for"
  say "  example) before it reaches the remote session, instead of passing"
  say "  it through."
  say "  Remaps the Host key to Scroll Lock in $REMMINA_PREF, a key nothing"
  say "  else needs during a remote session."
  if confirm "Fix Right Ctrl in Remmina?"; then
    if pgrep -x remmina >/dev/null 2>&1; then
      warn "Remmina is running and rewrites this file on exit, which would undo this;"
      warn "  quit Remmina (check the tray, not just the window) and re-run"
    else
      sed -i 's/^hostkey=.*/hostkey=65300/; s/^shortcutkey_grab=.*/shortcutkey_grab=65300/' "$REMMINA_PREF"
      say "set Remmina's Host key to Scroll Lock (65300) in $REMMINA_PREF"
    fi
  else
    say "skipped Remmina host key"
  fi
fi

# 7. Remmina: default new RDP connections to local audio redirect ------------ #
if [ -f "$REMMINA_PREF" ]; then
  say "Remmina RDP audio: Remmina's default for a new RDP connection is"
  say "  sound=off, so remote audio goes nowhere unless you change it per"
  say "  connection. Sets sound=local as the default in $REMMINA_PREF, so"
  say "  new connections redirect remote audio to this computer's speakers."
  say "  Only changes the default for new connections; existing saved ones"
  say "  are untouched."
  if confirm "Default new Remmina RDP connections to local audio redirect?"; then
    if pgrep -x remmina >/dev/null 2>&1; then
      warn "Remmina is running and rewrites this file on exit, which would undo this;"
      warn "  quit Remmina (check the tray, not just the window) and re-run"
    else
      if grep -q '^sound=' "$REMMINA_PREF"; then
        sed -i 's/^sound=.*/sound=local/' "$REMMINA_PREF"
      else
        printf 'sound=local\n' >> "$REMMINA_PREF"
      fi
      say "set new RDP connections to default sound=local in $REMMINA_PREF"
    fi
  else
    say "skipped Remmina audio redirect default"
  fi
fi

# 8. XWayland: make the largest connected monitor the primary output -------- #
say "XWayland primary monitor: Hyprland/XWayland never pick a primary output"
say "  on their own; whichever monitor enumerates first (often just whichever"
say "  one happens to be plugged in first) ends up primary, regardless of"
say "  size or orientation. X11 apps that ask for 'the' monitor instead of a"
say "  specific one (Steam and Proton games going fullscreen, for example)"
say "  land there too, which is how a smaller or rotated secondary monitor"
say "  ends up showing the game instead of the main display."
say "  Fix: at every session start, picks the connected monitor with the"
say "  largest resolution (width x height, not physical screen size) and"
say "  sets it as the X11/XWayland primary via 'xrandr --output <name>"
say "  --primary'. If your biggest-resolution monitor isn't the one you want"
say "  games to open on, this picks the wrong one; skip it and set an"
say "  explicit primary with xrandr yourself instead."
if confirm "Install xwayland-primary-monitor into $BIN_DIR and run it at session start?"; then
  link "$REPO/bin/xwayland-primary-monitor" "$BIN_DIR/xwayland-primary-monitor"
  chmod +x "$REPO/bin/xwayland-primary-monitor"
  require_line "$HYPR_DIR/autostart.lua" 'o.exec_on_start("xwayland-primary-monitor")'
else
  say "skipped xwayland-primary-monitor"
fi

# 9. Chromium video on NVIDIA machines --------------------------------------- #
# Not personal-only: gated on actually having an NVIDIA GPU (via lspci)
# instead of the -p flag, so it's offered on any machine that has one, not
# just the author's own. Which piece is offered depends on whether there is
# also an AMD or Intel GPU: the NVDEC flags only work when Chromium renders
# on the NVIDIA GPU itself, and break video on a hybrid machine.
HAS_NVIDIA=0
HAS_OTHER_GPU=0
if lspci -d '10de:' 2>/dev/null | grep -qE 'VGA compatible controller|3D controller'; then
  HAS_NVIDIA=1
fi
if lspci -nn 2>/dev/null | grep -E 'VGA compatible controller|3D controller|Display controller' | grep -qE '\[(1002|8086):'; then
  HAS_OTHER_GPU=1
fi

CHROMIUM_SYSTEM_DESKTOP="/usr/share/applications/chromium.desktop"
CHROMIUM_USER_DESKTOP="$HOME/.local/share/applications/chromium.desktop"
CHROMIUM_DESKTOP_MARK="# added by omarchy-akbari"

if [ "$HAS_NVIDIA" = 1 ] && [ "$HAS_OTHER_GPU" = 1 ]; then
  say "Chromium video on an NVIDIA + AMD/Intel machine: Omarchy exports"
  say "  LIBVA_DRIVER_NAME=nvidia session-wide, but Chromium draws on the"
  say "  other GPU, so frames decoded on the NVIDIA card can't be imported"
  say "  (black or frozen video, GPU process crashes, YouTube included)."
  say "  Installs a chromium wrapper into $BIN_DIR that unsets those"
  say "  variables for Chromium only, and a user chromium.desktop that"
  say "  launches it (so the app menu and omarchy-launch-browser use it)."
  say "  Chromium then decodes on the AMD/Intel GPU instead."
  if [ ! -f "$CHROMIUM_SYSTEM_DESKTOP" ]; then
    warn "$CHROMIUM_SYSTEM_DESKTOP not found (Chromium not installed?), skipping"
  elif confirm "Install the Chromium hybrid GPU wrapper?"; then
    link "$REPO/bin/chromium" "$BIN_DIR/chromium"
    chmod +x "$REPO/bin/chromium"
    tmp="$(mktemp)"
    { sed "s|^Exec=/usr/bin/chromium|Exec=$BIN_DIR/chromium|" "$CHROMIUM_SYSTEM_DESKTOP"; printf '%s\n' "$CHROMIUM_DESKTOP_MARK"; } > "$tmp"
    if ! grep -qF "Exec=$BIN_DIR/chromium" "$tmp"; then
      warn "$CHROMIUM_SYSTEM_DESKTOP has no Exec=/usr/bin/chromium line to rewrite, skipping the launcher"
      rm -f "$tmp"
    elif [ -f "$CHROMIUM_USER_DESKTOP" ] && cmp -s "$tmp" "$CHROMIUM_USER_DESKTOP"; then
      rm -f "$tmp"
    else
      if [ -e "$CHROMIUM_USER_DESKTOP" ] && ! grep -qF "$CHROMIUM_DESKTOP_MARK" "$CHROMIUM_USER_DESKTOP"; then
        mv "$CHROMIUM_USER_DESKTOP" "$CHROMIUM_USER_DESKTOP.bak.$(date +%s)"
        warn "backed up existing $CHROMIUM_USER_DESKTOP"
      fi
      mkdir -p "$(dirname "$CHROMIUM_USER_DESKTOP")"
      mv "$tmp" "$CHROMIUM_USER_DESKTOP"
      chmod 644 "$CHROMIUM_USER_DESKTOP"
      say "wrote $CHROMIUM_USER_DESKTOP"
    fi
    update-desktop-database "$(dirname "$CHROMIUM_USER_DESKTOP")" >/dev/null 2>&1 || true
    warn "quit Chromium fully and reopen it from the app menu to pick this up"
  else
    say "skipped the Chromium hybrid GPU wrapper"
  fi
  # An earlier install (or the NVIDIA-only step) may have linked the NVDEC
  # flags. They do nothing useful on a hybrid machine, so offer to undo that,
  # putting back whatever link() backed up (Omarchy's own default flags).
  if [ -L "$CONFIG_DIR/chromium-flags.conf" ] && [ "$(readlink -f "$CONFIG_DIR/chromium-flags.conf")" = "$(readlink -f "$REPO/config/chromium/chromium-flags.conf")" ]; then
    say "  $CONFIG_DIR/chromium-flags.conf still links the NVIDIA decode flags"
    say "  from an earlier install. They are pointless on this machine."
    if confirm "Remove them and go back to Omarchy's default Chromium flags?"; then
      rm -f "$CONFIG_DIR/chromium-flags.conf"
      say "removed $CONFIG_DIR/chromium-flags.conf"
      latest="$(ls -t "$CONFIG_DIR"/chromium-flags.conf.bak.* 2>/dev/null | head -1 || true)"
      if [ -n "$latest" ]; then
        mv "$latest" "$CONFIG_DIR/chromium-flags.conf"
        say "restored $CONFIG_DIR/chromium-flags.conf from $latest"
      else
        warn "no backup to restore; run omarchy-refresh-chromium to get Omarchy's default flags back"
      fi
    else
      say "left the NVIDIA decode flags in place"
    fi
  fi
elif [ "$HAS_NVIDIA" = 1 ]; then
  say "NVIDIA video decode for Chromium: Chromium's VA-API wrapper skips"
  say "  any driver literally named 'nvidia' by default, so hardware video"
  say "  decode (YouTube included) silently falls back to software instead"
  say "  (higher CPU/power use) on an NVIDIA GPU."
  say "  Installs libva-nvidia-driver if it's missing, and sets"
  say "  VaapiIgnoreDriverChecks + VaapiOnNvidiaGPUs, which bypass that"
  say "  check, in $CONFIG_DIR/chromium-flags.conf."
  if confirm "Enable NVIDIA hardware video decode flags for Chromium?"; then
    if ! pacman -Qq libva-nvidia-driver >/dev/null 2>&1; then
      omarchy pkg add libva-nvidia-driver
    fi
    link "$REPO/config/chromium/chromium-flags.conf" "$CONFIG_DIR/chromium-flags.conf"
    warn "chromium-flags.conf may get overwritten by omarchy-refresh-chromium; re-run install.sh if so"
  else
    say "skipped Chromium hardware video decode flags"
  fi
fi

# 10. Plymouth boot/unlock screen: matches the theme, plus a signature ------- #
# Not personal-only: Plymouth theming has nothing to do with author-specific
# hardware, it just recolors whichever Omarchy theme is currently selected,
# so anyone running Omarchy benefits.
#
# Whichever Omarchy theme is currently selected (the last one `omarchy
# theme set` applied), read straight from Omarchy's own state file rather
# than hardcoded, purely to word the prompt below; bin/plymouth-theme-sync
# does its own detection (with the same stock-look fallback) either way.
THEME_NAME_FILE="$HOME/.local/state/omarchy/current/theme.name"
if [ -s "$THEME_NAME_FILE" ]; then
  PLYMOUTH_THEME="$(cat "$THEME_NAME_FILE")"
  PLYMOUTH_PROMPT="$PLYMOUTH_THEME"
else
  PLYMOUTH_THEME=""
  PLYMOUTH_PROMPT="Omarchy's stock look (no theme currently selected)"
fi
say "Plymouth boot screen: recolors the boot/unlock screen to match"
say "  $PLYMOUTH_PROMPT."
say "  Omarchy's own recolor drops the OMARCHY wordmark in favor of the"
say "  theme's icon; this adds the wordmark back under the icon, plus a"
say "  small '(w/ Shakir's postscripts)' watermark in the corner."
say "  Needs sudo and rebuilds the initramfs."
if confirm "Recolor the boot screen now?"; then
  mkdir -p "$BIN_DIR"
  link "$REPO/bin/plymouth-theme-sync" "$BIN_DIR/plymouth-theme-sync"
  chmod +x "$REPO/bin/plymouth-theme-sync"
  "$BIN_DIR/plymouth-theme-sync" "$PLYMOUTH_THEME"
  warn "/usr/share/plymouth/themes/omarchy/omarchy.script is owned by omarchy-settings"
  warn "  omarchy plymouth set/set-by-theme, or an omarchy update that touches that"
  warn "  package, overwrites the recolor, wordmark, and watermark alike; re-run"
  warn "  plymouth-theme-sync if so"

  say "Optional: a theme-set hook re-runs this automatically every time you"
  say "  'omarchy theme set' something new, so the boot screen never falls"
  say "  out of sync (needs sudo again on each switch; if it can't get sudo"
  say "  without a prompt, it opens a terminal to ask there instead of"
  say "  hanging silently)."
  if confirm "Install that hook?"; then
    omarchy hook install theme-set "$REPO/bin/plymouth-theme-sync"
    say "installed the theme-set hook: ~/.config/omarchy/hooks/theme-set.d/plymouth-theme-sync"
  else
    say "skipped the theme-set hook; re-run plymouth-theme-sync (or install.sh) by hand after switching themes"
  fi
else
  say "skipped Plymouth boot screen customization"
fi

# 11. System menu: add a "Reboot to Windows" entry ---------------------------- #
# Not personal-only: the row only ever shows up in the menu when efibootmgr
# reports a Windows Boot Manager entry (see the "when" condition in
# config/omarchy/omarchy-menu.jsonc), so it's inert on a machine without one;
# this check just avoids asking about it at all in that case. Same picker
# bin/omarchy-reboot-to-windows itself uses (and step 4 above already made
# executable and, if needed, asked about), so "is there one to offer" and
# "which one gets used" never disagree.
if command -v efibootmgr >/dev/null 2>&1 && "$REPO/bin/omarchy-pick-windows-boot-entry" >/dev/null 2>&1; then
  say "System menu: adds a 'Reboot to Windows' entry to the System menu."
  say "  Sets the UEFI BootNext flag to the Windows Boot Manager entry"
  say "  resolved in step 4, then reboots into it."
  say "  One-shot: BootOrder (and Omarchy as the regular default) is"
  say "  untouched for every boot after that. Needs sudo, same as the"
  say "  reboot/shutdown entries already in that menu."
  if confirm "Add a 'Reboot to Windows' entry to the System menu?"; then
    mkdir -p "$BIN_DIR"
    link "$REPO/bin/omarchy-reboot-to-windows" "$BIN_DIR/omarchy-reboot-to-windows"
    chmod +x "$REPO/bin/omarchy-reboot-to-windows"
    link "$REPO/config/omarchy/omarchy-menu.jsonc" "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"
    omarchy menu refresh >/dev/null 2>&1 || true
    say "added 'Reboot to Windows' to the System menu"
  else
    say "skipped the Reboot to Windows menu entry"
  fi
else
  say "no Windows Boot Manager entry resolved (none found, or more than one"
  say "  with nothing chosen in step 4), skipping the Reboot to Windows"
  say "  menu entry"
fi

# 12. Claude app launcher ------------------------------------------------------ #
# Not personal-only: it only launches whatever `claude` is on PATH, so it's
# inert without Claude Code, and this check just avoids asking in that case.
# Same shape as Omarchy's own TUI entries (Docker, Disk Usage): a .desktop
# file that opens the command in a tiled terminal window, plus an icon.
if command -v claude >/dev/null 2>&1; then
  say "Claude app launcher: adds 'Claude' to the app launcher (SUPER+SPACE)"
  say "  like your other apps. It opens Claude Code in a tiled terminal"
  say "  window (the same way the Docker entry opens its TUI), with the"
  say "  Claude icon."
  if confirm "Add the Claude app launcher?"; then
    link "$REPO/config/applications/Claude.desktop" "$HOME/.local/share/applications/Claude.desktop"
    link "$REPO/config/icons/claude.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/claude.svg"
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    say "added Claude to the app launcher"
  else
    say "skipped the Claude app launcher"
  fi
else
  say "claude not found on PATH, skipping the Claude app launcher"
fi

# 13. Personal-only: monitor layout, startup workspace, full package list --- #
if [ "$PERSONAL" -eq 1 ]; then
  say "Personal monitor layout: hardcodes monitor positions, resolutions,"
  say "  and workspace assignments for the author's own multi-monitor setup"
  say "  (an ultrawide primary + a portrait secondary). Only useful if your"
  say "  hardware matches; on any other machine, write your own"
  say "  $HYPR_DIR/monitors.lua instead."
  if confirm "Install personal monitor layout into $HYPR_DIR/monitors.lua?"; then
    link "$REPO/config/hypr/monitors.lua.personal" "$HYPR_DIR/monitors.lua"
  else
    say "skipped personal monitor layout"
  fi

  # Monitors attach asynchronously at session start, and whichever one
  # attaches last tends to end up as Hyprland's initially focused monitor,
  # regardless of the workspace_rule "default" settings above (those pick
  # which workspace shows on a monitor, not which monitor holds keyboard/
  # cursor focus). Since the portrait monitor is declared second in
  # monitors.lua.personal, it was winning that race, so anything that opens
  # "on the active monitor" (the Spotlight launcher included) landed there
  # right after login instead of on the main ultrawide, and the session
  # could start on whatever workspace instead of golden-spiral (10).
  #
  # This build of Hyprland (Omarchy's Lua config layer) doesn't take plain
  # `hyprctl dispatch <dispatcher> <args>`; dispatchers are Lua calls under
  # hl.dsp.*, run via hl.dispatch(...). Switching straight to workspace 10
  # (hl.dsp.focus({ workspace = "10" }), same call bindings.lua uses for
  # SUPER + <number>) both puts golden-spiral on screen and pulls monitor
  # focus onto the ultrawide as a side effect, since a workspace only ever
  # lives on one monitor. Confirmed via `hyprctl eval`: forced focus onto the
  # portrait monitor's workspace 11 first, then this moved both the active
  # workspace and the focused monitor back in one call.
  say "Startup workspace: monitors attach asynchronously at login, and"
  say "  whichever one attaches last tends to win initial keyboard/cursor"
  say "  focus, regardless of per-workspace monitor defaults. With the"
  say "  portrait monitor attaching last, that lands the launcher/menu"
  say "  there instead of the main ultrawide right after login."
  say "  Fix: force-focuses golden-spiral's workspace (10, on the"
  say "  ultrawide) at the start of every session."
  if confirm "Start every session on golden-spiral's workspace (10)?"; then
    require_line "$HYPR_DIR/autostart.lua" 'o.exec_on_start([[hyprctl eval '"'"'hl.dispatch(hl.dsp.focus({ workspace = "10" }))'"'"']])'
  else
    say "skipped forcing the startup workspace"
  fi

  # shakir.workspaces: a clone of Omarchy's built-in workspaces bar widget
  # (the id itself is personal, hence -p only) that always shows a spiral
  # icon for workspace 10, where golden-spiral lives instead of a plain
  # number. Swaps it in for omarchy.workspaces in shell.json's bar layout.
  say "shakir.workspaces bar widget: a fork of Omarchy's built-in"
  say "  workspaces widget that shows a spiral icon for workspace 10"
  say "  (where golden-spiral lives) instead of a plain number. Swaps it in"
  say "  for omarchy.workspaces in $CONFIG_DIR/omarchy/shell.json's bar"
  say "  layout."
  if confirm "Install the shakir.workspaces bar widget?"; then
    plugin_dir="$CONFIG_DIR/omarchy/plugins/shakir.workspaces"
    mkdir -p "$plugin_dir"
    link "$REPO/config/omarchy/plugins/shakir.workspaces/manifest.json" "$plugin_dir/manifest.json"
    link "$REPO/config/omarchy/plugins/shakir.workspaces/Workspaces.qml" "$plugin_dir/Workspaces.qml"

    shell_json="$CONFIG_DIR/omarchy/shell.json"
    if [ ! -f "$shell_json" ] || ! command -v jq >/dev/null 2>&1; then
      warn "no $shell_json or jq not found; add {\"id\": \"shakir.workspaces\"} to its bar layout yourself"
    elif jq -e '[.bar.layout.left[]?, .bar.layout.center[]?, .bar.layout.right[]?] | any(.id == "shakir.workspaces")' "$shell_json" >/dev/null 2>&1; then
      say "shakir.workspaces already wired into $shell_json"
    elif jq -e '[.bar.layout.left[]?, .bar.layout.center[]?, .bar.layout.right[]?] | any(.id == "omarchy.workspaces")' "$shell_json" >/dev/null 2>&1; then
      shell_json_tmp=$(mktemp)
      jq '(.bar.layout.left, .bar.layout.center, .bar.layout.right) |= map(if .id == "omarchy.workspaces" then .id = "shakir.workspaces" else . end)' "$shell_json" > "$shell_json_tmp"
      mv "$shell_json_tmp" "$shell_json"
      say "swapped omarchy.workspaces -> shakir.workspaces in $shell_json"
    else
      warn "no omarchy.workspaces entry found in $shell_json's bar layout; add {\"id\": \"shakir.workspaces\"} yourself"
    fi
  else
    say "skipped shakir.workspaces bar widget"
  fi

  # shakir.spotify: Spotify now-playing + play/pause/skip in the bar, between
  # the center section (clock/weather) and the right-side icon cluster.
  # Reads Quickshell's Mpris module directly rather than Omarchy's own
  # omarchy.media service, which third-party bar widgets are sandboxed away
  # from (see the comment atop SpotifyWidget.qml).
  say "shakir.spotify bar widget: Spotify now-playing plus play/pause/skip"
  say "  in the bar, placed between the clock/weather section and the"
  say "  tray/network icon cluster. Reads Quickshell's Mpris module"
  say "  directly, since third-party widgets are sandboxed away from"
  say "  Omarchy's own media service. Added to"
  say "  $CONFIG_DIR/omarchy/shell.json's bar layout."
  if confirm "Install the shakir.spotify bar widget?"; then
    plugin_dir="$CONFIG_DIR/omarchy/plugins/shakir.spotify"
    mkdir -p "$plugin_dir"
    link "$REPO/config/omarchy/plugins/shakir.spotify/manifest.json" "$plugin_dir/manifest.json"
    link "$REPO/config/omarchy/plugins/shakir.spotify/SpotifyWidget.qml" "$plugin_dir/SpotifyWidget.qml"

    shell_json="$CONFIG_DIR/omarchy/shell.json"
    if [ ! -f "$shell_json" ] || ! command -v jq >/dev/null 2>&1; then
      warn "no $shell_json or jq not found; add {\"id\": \"shakir.spotify\"} to its bar layout yourself"
    elif jq -e '[.bar.layout.left[]?, .bar.layout.center[]?, .bar.layout.right[]?] | any(.id == "shakir.spotify")' "$shell_json" >/dev/null 2>&1; then
      say "shakir.spotify already wired into $shell_json"
    else
      shell_json_tmp=$(mktemp)
      # The spacer after it (not before: "right" is anchored to the screen's
      # right edge, so padding only has to go on the inner side) pushes it
      # away from the tray/network/etc. cluster so it reads as sitting in the
      # gap between the center section and that cluster, not glued to either.
      jq '.bar.layout.right = [{"id": "shakir.spotify"}, {"id": "omarchy.spacer", "size": 400}] + .bar.layout.right' "$shell_json" > "$shell_json_tmp"
      mv "$shell_json_tmp" "$shell_json"
      say "added shakir.spotify (with a spacer after it) to the start of $shell_json's right bar section"
    fi
  else
    say "skipped shakir.spotify bar widget"
  fi

  say "Personal packages (gaming, VMs, NVIDIA, work apps): asked one by one,"
  say "  already-installed ones are skipped."
  if [ -f "$REPO/packages-personal.txt" ] && confirm "Go through the personal package list?"; then
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages-personal.txt")
    repo_pkgs=() aur_pkgs=()
    for pkg in "${pkgs[@]}"; do
      pacman -Qq "$pkg" >/dev/null 2>&1 && continue
      # 'omarchy pkg add' is pacman-only, and pacman aborts the whole
      # transaction on one unresolvable target, so AUR packages have to be
      # split out or nothing installs at all.
      if pacman -Si "$pkg" >/dev/null 2>&1; then
        confirm "Install $pkg?" && repo_pkgs+=("$pkg")
      else
        confirm "Install $pkg (AUR)?" && aur_pkgs+=("$pkg")
      fi
    done
    if [ "${#repo_pkgs[@]}" -gt 0 ]; then
      say "installing repo packages: ${repo_pkgs[*]}"
      omarchy pkg add "${repo_pkgs[@]}" || warn "some repo packages failed to install"
    fi
    if [ "${#aur_pkgs[@]}" -gt 0 ]; then
      say "installing AUR packages: ${aur_pkgs[*]}"
      omarchy pkg aur add "${aur_pkgs[@]}" || warn "some AUR packages failed to install"
    fi
    [ "${#repo_pkgs[@]}" -eq 0 ] && [ "${#aur_pkgs[@]}" -eq 0 ] && say "no packages selected"
  else
    say "skipped personal package list"
  fi

  say "Web apps: launcher entries (SUPER+SPACE) that open a site in its own"
  say "  app window, like Omarchy's own web apps; asked one by one."
  if [ -f "$REPO/webapps-personal.txt" ] && command -v omarchy-webapp-install >/dev/null 2>&1; then
    while IFS='|' read -r app_name app_url app_icon; do
      [ -f "$HOME/.local/share/applications/$app_name.desktop" ] && continue
      if confirm "Add the $app_name web app ($app_url)?"; then
        omarchy-webapp-install "$app_name" "$app_url" "$REPO/$app_icon" </dev/null || warn "could not add the $app_name web app"
      fi
    done < <(grep -vE '^\s*(#|$)' "$REPO/webapps-personal.txt")
  else
    say "skipped web apps"
  fi

  say "Services: installed daemons start out disabled; asked one by one."
  for entry in \
    "libvirt:libvirtd.service:virtual machines for virt-manager" \
    "coolercontrol:coolercontrold.service:CoolerControl fan and cooling daemon" \
    "ollama-cuda:ollama.service:local LLM server"; do
    IFS=: read -r svc_pkg svc_unit svc_desc <<< "$entry"
    pacman -Qq "$svc_pkg" >/dev/null 2>&1 || continue
    systemctl is-enabled --quiet "$svc_unit" 2>/dev/null && continue
    if confirm "Enable and start $svc_unit ($svc_desc)?"; then
      sudo systemctl enable --now "$svc_unit" || warn "could not enable $svc_unit"
    fi
  done

  if pacman -Qq libvirt >/dev/null 2>&1 && ! id -nG "$USER" | tr ' ' '\n' | grep -qx libvirt; then
    if confirm "Add $USER to the libvirt group (manage VMs without sudo)?"; then
      sudo usermod -aG libvirt "$USER" || warn "could not add $USER to the libvirt group"
      say "added to libvirt; log out and back in for it to take effect"
    fi
  fi

  # Not in the services loop above: enabling tailscaled alone leaves it logged
  # out with no icon or panel. Omarchy's own installer also does the login, the
  # bar plugin, Taildrop and the admin web app, so this just runs that.
  if pacman -Qq tailscale >/dev/null 2>&1 && command -v omarchy-install-service-tailscale >/dev/null 2>&1 \
     && ! grep -qF omarchy.tailscale "$CONFIG_DIR/omarchy/shell.json" 2>/dev/null; then
    say "Tailscale: runs Omarchy's own setup. Enables tailscaled, logs in"
    say "  (prints a link to open), puts the Tailscale icon and panel in the bar,"
    say "  receives Taildrop files in ~/Downloads, and adds a Tailscale admin"
    say "  web app. Needs sudo."
    if confirm "Set up Tailscale (login, bar icon, admin web app)?"; then
      omarchy-install-service-tailscale || warn "Tailscale setup did not finish"
    else
      say "skipped the Tailscale setup"
    fi
  fi

  # Carried over from Windows FanControl; the settings live in
  # config/coolercontrol/fans.json (raw original in fancontrol-windows.json).
  # Goes through CoolerControl's REST API, since its config.toml is root-owned
  # and its profile format is the daemon's to write, not ours.
  if pacman -Qq coolercontrol >/dev/null 2>&1; then
    say "CoolerControl fan curves: one CPU-temperature curve (0% at 50C up to"
    say "  60% at 85C, 2C hysteresis) on the CPU and system fans, the pump fixed"
    say "  at 50%, matching the old Windows FanControl setup. Needs coolercontrold"
    say "  running; fans idle at 0 RPM below 50C, so check temps under load."
    if ! systemctl is-active --quiet coolercontrold.service; then
      say "coolercontrold is not running, skipping the fan curves (enable it above, then re-run)"
    elif confirm "Apply the fan curves to CoolerControl?"; then
      "$REPO/bin/coolercontrol-apply-fans" || warn "could not apply the fan curves"
    else
      say "skipped the CoolerControl fan curves"
    fi
  fi
fi

echo
say "done. Run: hyprctl reload && hyprctl configerrors"
