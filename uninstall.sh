#!/usr/bin/env bash
# omarchy-shakir uninstaller. Mirrors install.sh: asks before every removal,
# and only touches things it can verify it actually installed (a symlink
# still pointing at this repo, a require line still present, and so on).
# Safe to re-run: anything already removed is reported and skipped, not
# re-asked about. Needs a real terminal to ask; piped in with no tty,
# every question defaults to no and nothing gets removed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_DIR/hypr"
BIN_DIR="$HOME/.local/bin"
PROJECTS_DIR="$HOME/Projects"
GOLDENSPIRAL_DIR="$PROJECTS_DIR/hypr-goldenspiral"
LIMINE_CONF="/boot/limine.conf"

say()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m !!\033[0m %s\n' "$*"; }
err()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: uninstall.sh [-h|--help]

Asks before removing each piece install.sh installed: keybindings, Spotify
keys, hypr-goldenspiral, numlock, the Limine Windows entry, and (if present)
the personal-only monitor layout, Chromium flags, and package list.

  -h, --help   Show this help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
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

# unlink_ours <src> <dest>: remove dest only if it is still a symlink to src
# (install.sh's `link` helper). Leaves it alone otherwise, since that means
# it was already removed or someone else has since taken it over. Offers to
# restore a `link`-made backup (dest.bak.<timestamp>) if one exists.
unlink_ours() {
  local src="$1" dest="$2" latest
  if [ ! -L "$dest" ] || [ "$(readlink -f "$dest")" != "$(readlink -f "$src")" ]; then
    warn "$dest is not a symlink to $src (already removed, or hand-edited), leaving as is"
    return 0
  fi
  rm -f "$dest"
  say "removed $dest"
  latest="$(ls -t "$dest".bak.* 2>/dev/null | head -1 || true)"
  if [ -n "$latest" ] && confirm "Restore the previous $dest from backup ($latest)?"; then
    mv "$latest" "$dest"
    say "restored $dest from $latest"
  fi
}

# remove_line <file> <line>: delete an exact line if present (the inverse of
# install.sh's `require_line`).
remove_line() {
  local file="$1" line="$2" tmp
  if [ ! -f "$file" ] || ! grep -qF "$line" "$file"; then
    return 0
  fi
  tmp="$(mktemp)"
  grep -vF "$line" "$file" > "$tmp"
  mv "$tmp" "$file"
  say "removed '$line' from $file"
}

# 1. Keybindings and look'n'feel -------------------------------------------- #
if [ -L "$HYPR_DIR/bindings.lua" ] || [ -L "$HYPR_DIR/looknfeel.lua" ]; then
  if confirm "Remove keybindings and look'n'feel from $HYPR_DIR?"; then
    unlink_ours "$REPO/config/hypr/bindings.lua" "$HYPR_DIR/bindings.lua"
    unlink_ours "$REPO/config/hypr/looknfeel.lua" "$HYPR_DIR/looknfeel.lua"
  else
    say "left keybindings and look'n'feel in place"
  fi
else
  say "keybindings and look'n'feel not installed, nothing to do"
fi

# 2. Spotify media-key scripts ----------------------------------------------- #
if [ -L "$BIN_DIR/spotify-play-key" ] || [ -L "$BIN_DIR/spotify-stop-key" ]; then
  if confirm "Remove Spotify media-key scripts from $BIN_DIR?"; then
    for script in spotify-play-key spotify-stop-key; do
      unlink_ours "$REPO/bin/$script" "$BIN_DIR/$script"
    done
  else
    say "left Spotify media-key scripts in place"
  fi
else
  say "Spotify media-key scripts not installed, nothing to do"
fi

# 3. Golden-spiral layout + chronobar taskbar --------------------------------- #
REQUIRE_LINE='require("hypr.goldenspiral")'
if grep -qF "$REQUIRE_LINE" "$HYPR_DIR/hyprland.lua" 2>/dev/null; then
  if confirm "Remove the '$REQUIRE_LINE' line from $HYPR_DIR/hyprland.lua?"; then
    remove_line "$HYPR_DIR/hyprland.lua" "$REQUIRE_LINE"
  else
    say "left the hypr-goldenspiral require line in place"
  fi
else
  say "hypr-goldenspiral require line not present, nothing to do"
fi

if [ -d "$GOLDENSPIRAL_DIR" ]; then
  if [ -d "$GOLDENSPIRAL_DIR/.git" ] && [ -n "$(git -C "$GOLDENSPIRAL_DIR" status --porcelain 2>/dev/null)" ]; then
    warn "$GOLDENSPIRAL_DIR has uncommitted changes, leaving it in place (remove it yourself if you're sure)"
  elif confirm "Delete the cloned hypr-goldenspiral directory at $GOLDENSPIRAL_DIR entirely?"; then
    rm -rf "$GOLDENSPIRAL_DIR"
    say "removed $GOLDENSPIRAL_DIR"
  else
    say "left $GOLDENSPIRAL_DIR in place"
  fi
else
  say "hypr-goldenspiral directory not present, nothing to do"
fi

# 4. Numlock on boot ---------------------------------------------------------- #
if [ -f /etc/systemd/system/numlock-console.service ] || [ -f /etc/sddm.conf.d/50-numlock.conf ]; then
  if confirm "Disable numlock-on-boot and remove its files (needs sudo)?"; then
    sudo systemctl disable --now numlock-console.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/numlock-console.service
    sudo rm -f /etc/sddm.conf.d/50-numlock.conf
    sudo systemctl daemon-reload
    say "numlock-on-boot removed"
  else
    say "left numlock-on-boot in place"
  fi
else
  say "numlock-on-boot not installed, nothing to do"
fi

# 5. Limine: remove the Windows entry this repo added ------------------------- #
if [ ! -f "$LIMINE_CONF" ]; then
  say "no $LIMINE_CONF, nothing to do"
elif ! grep -q 'comment: added by omarchy-shakir' "$LIMINE_CONF" 2>/dev/null; then
  say "no omarchy-shakir Limine entry found, nothing to do"
  warn "the Limine timeout (if set to 5s) is left as is; restore a /boot/limine.conf.bak.* if you want it back"
elif confirm "Remove the Windows entry this repo added to $LIMINE_CONF (backs it up first, needs sudo)?"; then
  sudo cp "$LIMINE_CONF" "$LIMINE_CONF.bak.$(date +%s)"
  say "backed up $LIMINE_CONF"
  tmp="$(mktemp)"
  # Entries start at a line beginning with /, run until the next such line
  # or EOF. Drop whichever entry contains our marker comment, plus the
  # blank line that separates it from what came before.
  awk '
    /^\// {
      if (buf != "" && !skip) printf "%s", buf
      buf = $0 "\n"; skip = 0; next
    }
    buf != "" {
      buf = buf $0 "\n"
      if ($0 ~ /added by omarchy-shakir/) skip = 1
      next
    }
    { print }
    END { if (buf != "" && !skip) printf "%s", buf }
  ' "$LIMINE_CONF" > "$tmp"
  sudo cp "$tmp" "$LIMINE_CONF"
  rm -f "$tmp"
  say "removed the Windows entry from $LIMINE_CONF"
  warn "the Limine timeout (if set to 5s) is left as is; restore a /boot/limine.conf.bak.* if you want it back"
else
  say "left the Limine Windows entry in place"
fi

# 6. Personal-only: monitor layout, Chromium flags, package list ------------- #
if [ -L "$HYPR_DIR/monitors.lua" ]; then
  if confirm "Remove the personal monitor layout from $HYPR_DIR/monitors.lua?"; then
    unlink_ours "$REPO/config/hypr/monitors.lua.personal" "$HYPR_DIR/monitors.lua"
  else
    say "left the personal monitor layout in place"
  fi
else
  say "personal monitor layout not installed, nothing to do"
fi

if [ -L "$CONFIG_DIR/chromium-flags.conf" ]; then
  if confirm "Remove the NVIDIA hardware video decode Chromium flags ($CONFIG_DIR/chromium-flags.conf)?"; then
    unlink_ours "$REPO/config/chromium/chromium-flags.conf" "$CONFIG_DIR/chromium-flags.conf"
  else
    say "left the Chromium flags in place"
  fi
else
  say "Chromium hardware video decode flags not installed, nothing to do"
fi

if [ -f "$REPO/packages-personal.txt" ] && command -v omarchy >/dev/null 2>&1; then
  warn "removing the personal package list can remove GPU drivers and other packages other software depends on"
  if confirm "Remove the personal package list (gaming, virtualization, NVIDIA drivers, work apps) via omarchy pkg drop?"; then
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages-personal.txt")
    omarchy pkg drop "${pkgs[@]}"
    say "personal packages removed"
  else
    say "left the personal package list installed"
  fi
fi

echo
say "done. Run: hyprctl reload && hyprctl configerrors"
