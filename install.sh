#!/usr/bin/env bash
# omarchy-shakir installer. Idempotent: safe to re-run after a git pull.
#
# Default: config that is safe and useful for anyone (keybindings, look'n'feel,
# numlock on boot, a Limine boot menu with a real timeout).
#
# -p / --personal: also installs machine-specific pieces (monitor layout,
# full package list) that only make sense on the author's own machines.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
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
  if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
    warn "no terminal available, assuming no for: $prompt"
    return 1
  fi
  read -r -p "$prompt [y/N] " reply < /dev/tty
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

# 1. Keybindings and look'n'feel -------------------------------------------- #
link "$REPO/config/hypr/bindings.lua" "$HYPR_DIR/bindings.lua"
link "$REPO/config/hypr/looknfeel.lua" "$HYPR_DIR/looknfeel.lua"

# 2. Spotify media-key scripts ----------------------------------------------- #
mkdir -p "$BIN_DIR"
for script in spotify-play-key spotify-stop-key; do
  link "$REPO/bin/$script" "$BIN_DIR/$script"
  chmod +x "$REPO/bin/$script"
done

# 3. Golden-spiral layout + chronobar taskbar --------------------------------- #
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

# 4. Numlock on boot, before any login screen --------------------------------- #
say "numlock: SDDM greeter + virtual consoles (needs sudo)"
sudo install -Dm644 "$REPO/config/sddm/50-numlock.conf" /etc/sddm.conf.d/50-numlock.conf
sudo install -Dm644 "$REPO/config/systemd/numlock-console.service" /etc/systemd/system/numlock-console.service
sudo systemctl daemon-reload
sudo systemctl enable --now numlock-console.service
say "numlock enabled"

# 5. Limine boot menu: real timeout + auto-detected Windows entry ------------ #
LIMINE_CONF="/boot/limine.conf"
if [ ! -f "$LIMINE_CONF" ]; then
  warn "no $LIMINE_CONF, skipping Limine setup (not using Limine, or ESP mounted elsewhere)"
else
  say "backing up $LIMINE_CONF"
  sudo cp "$LIMINE_CONF" "$LIMINE_CONF.bak.$(date +%s)"

  if grep -qE '^timeout: *(0|no) *$' "$LIMINE_CONF" 2>/dev/null || \
     ! grep -qE '^timeout:' "$LIMINE_CONF" 2>/dev/null; then
    if grep -qE '^#?timeout:' "$LIMINE_CONF"; then
      sudo sed -i -E 's/^#?timeout:.*/timeout: 5/' "$LIMINE_CONF"
    else
      printf 'timeout: 5\n' | sudo tee -a "$LIMINE_CONF" > /dev/null
    fi
    say "set Limine menu timeout to 5s"
  else
    say "Limine timeout already active, left as-is"
  fi

  if command -v efibootmgr >/dev/null 2>&1 && ! grep -q '^/+Windows' "$LIMINE_CONF"; then
    # Each match is "<boot entry name>\t<partition GUID>", one per Windows
    # Boot Manager entry found. A machine can have more than one (a stale
    # entry from a previous install is common), so this is a list, not a
    # single value.
    mapfile -t win_entries < <(efibootmgr -v 2>/dev/null \
      | grep -i 'bootmgfw\.efi' \
      | sed -E 's/^Boot[0-9A-Fa-f]{4}\*? +(.*)'$'\t''HD\([0-9]+,GPT,([0-9a-fA-F-]+),.*/\1'$'\t''\2/' \
      | awk -F'\t' '!seen[$2]++')
    if [ "${#win_entries[@]}" -eq 0 ]; then
      say "no Windows Boot Manager found in efibootmgr, skipping dual-boot entry"
    else
      # Prefer an entry with a distinctive name over the generic
      # "Windows Boot Manager" label, since the generic one is more often
      # the stale leftover. Falls back to whichever efibootmgr listed first.
      pick="${win_entries[0]}"
      for entry in "${win_entries[@]}"; do
        if [ "${entry%%$'\t'*}" != "Windows Boot Manager" ]; then
          pick="$entry"
          break
        fi
      done
      name="${pick%%$'\t'*}"
      guid="${pick##*$'\t'}"
      if [ "${#win_entries[@]}" -gt 1 ]; then
        warn "multiple Windows Boot Manager entries found, using: $name ($guid)"
        for entry in "${win_entries[@]}"; do
          [ "$entry" = "$pick" ] && continue
          printf '   also found: %s (%s)\n' "${entry%%$'\t'*}" "${entry##*$'\t'}"
        done
      fi
      if confirm "Add a Limine entry chainloading '$name' at partition $guid?"; then
        {
          printf '\n/+%s\n' "$name"
          printf '    comment: added by omarchy-shakir\n'
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

# 6. Personal-only: monitor layout and full package list --------------------- #
if [ "$PERSONAL" -eq 1 ]; then
  warn "personal mode: monitor layout is hardcoded for the author's hardware"
  link "$REPO/config/hypr/monitors.lua.personal" "$HYPR_DIR/monitors.lua"

  if [ -f "$REPO/packages-personal.txt" ]; then
    say "installing personal packages"
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages-personal.txt")
    omarchy pkg add "${pkgs[@]}"
  fi
fi

echo
say "done. Run: hyprctl reload && hyprctl configerrors"
