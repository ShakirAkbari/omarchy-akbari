#!/usr/bin/env bash
# omarchy-shakir installer. Idempotent: safe to re-run after a git pull.
# Asks before every change it makes, so a re-run only touches what you say
# yes to. Needs a real terminal to ask; piped in via `curl | bash` with no
# tty, every question defaults to no and nothing gets installed.
#
# Default: config that is safe and useful for anyone (keybindings, look'n'feel,
# numlock on boot, a Limine boot menu with a real timeout).
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
if confirm "Install keybindings and look'n'feel (config/hypr/bindings.lua, looknfeel.lua) into $HYPR_DIR?"; then
  link "$REPO/config/hypr/bindings.lua" "$HYPR_DIR/bindings.lua"
  link "$REPO/config/hypr/looknfeel.lua" "$HYPR_DIR/looknfeel.lua"
else
  say "skipped keybindings and look'n'feel"
fi

# 2. Spotify media-key scripts ----------------------------------------------- #
if confirm "Install Spotify media-key scripts into $BIN_DIR?"; then
  mkdir -p "$BIN_DIR"
  for script in spotify-play-key spotify-stop-key; do
    link "$REPO/bin/$script" "$BIN_DIR/$script"
    chmod +x "$REPO/bin/$script"
  done
else
  say "skipped Spotify media-key scripts"
fi

# 3. Golden-spiral layout + chronobar taskbar --------------------------------- #
if confirm "Clone/update hypr-goldenspiral into $PROJECTS_DIR and wire it into hyprland.lua?"; then
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

# 4. Numlock on boot, before any login screen --------------------------------- #
if confirm "Enable numlock on boot (SDDM greeter config + its own Hyprland config + a systemd service, needs sudo)?"; then
  sudo install -Dm644 "$REPO/config/sddm/50-numlock.conf" /etc/sddm.conf.d/50-numlock.conf
  sudo install -Dm644 "$REPO/config/systemd/numlock-console.service" /etc/systemd/system/numlock-console.service
  # The SDDM Wayland greeter runs its own Hyprland instance with its own
  # config, separate from the session config that require("hypr.goldenspiral")
  # etc. get wired into. It ignores input.numlock_by_default unless this file
  # sets it too, and is owned by the omarchy-settings package, so it gets
  # overwritten back to Omarchy's default by every `omarchy update` that
  # touches that package: this step needs re-running after such an update.
  # It pre-exists (unlike the two installs above), so back it up once, the
  # same way the Limine step does, rather than losing Omarchy's original.
  sddm_hypr=/usr/share/sddm/hyprland.lua
  if [ -f "$sddm_hypr" ] && [ ! -f "$sddm_hypr.bak.omarchy-shakir" ] && \
     ! cmp -s "$REPO/config/sddm/hyprland.lua" "$sddm_hypr"; then
    sudo cp "$sddm_hypr" "$sddm_hypr.bak.omarchy-shakir"
    say "backed up $sddm_hypr"
  fi
  sudo install -Dm644 "$REPO/config/sddm/hyprland.lua" "$sddm_hypr"
  sudo systemctl daemon-reload
  sudo systemctl enable --now numlock-console.service
  say "numlock enabled"
else
  say "skipped numlock setup"
fi

# 5. Limine boot menu: real timeout + auto-detected Windows entry ------------ #
LIMINE_CONF="/boot/limine.conf"
if [ ! -f "$LIMINE_CONF" ]; then
  warn "no $LIMINE_CONF, skipping Limine setup (not using Limine, or ESP mounted elsewhere)"
elif confirm "Set a real Limine boot menu timeout (5s) in $LIMINE_CONF (backs it up first, needs sudo)?"; then
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

  if grep -qE '^timeout: *(0|no) *$' "$LIMINE_CONF" 2>/dev/null || \
     ! grep -qE '^timeout:' "$LIMINE_CONF" 2>/dev/null; then
    limine_backup
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
        limine_backup
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
else
  say "skipped Limine timeout"
fi

# 6. Personal-only: monitor layout, Chromium flags, full package list -------- #
if [ "$PERSONAL" -eq 1 ]; then
  if confirm "Install personal monitor layout (hardcoded for the author's hardware) into $HYPR_DIR/monitors.lua?"; then
    link "$REPO/config/hypr/monitors.lua.personal" "$HYPR_DIR/monitors.lua"
  else
    say "skipped personal monitor layout"
  fi

  # shakir.workspaces: a clone of Omarchy's built-in workspaces bar widget
  # (the id itself is personal, hence -p only) that always shows a spiral
  # icon for workspace 10, where golden-spiral lives instead of a plain
  # number. Swaps it in for omarchy.workspaces in shell.json's bar layout.
  if confirm "Install the shakir.workspaces bar widget (replaces omarchy.workspaces in $CONFIG_DIR/omarchy/shell.json with a golden-spiral-aware version)?"; then
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
  if confirm "Install the shakir.spotify bar widget (Spotify now-playing, added to $CONFIG_DIR/omarchy/shell.json's bar layout)?"; then
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

  # NVIDIA VA-API hardware video decode in Chromium. Chromium's own VA-API
  # wrapper skips any driver named "nvidia" by default; VaapiIgnoreDriverChecks
  # and VaapiOnNvidiaGPUs bypass that, letting libva-nvidia-driver (installed
  # below) actually get used for decode instead of falling back to software.
  # Only meaningful with an NVIDIA GPU, hence personal-only.
  if confirm "Enable NVIDIA hardware video decode flags for Chromium ($CONFIG_DIR/chromium-flags.conf)?"; then
    link "$REPO/config/chromium/chromium-flags.conf" "$CONFIG_DIR/chromium-flags.conf"
    warn "chromium-flags.conf may get overwritten by omarchy-refresh-chromium; re-run install.sh -p if so"
  else
    say "skipped Chromium hardware video decode flags"
  fi

  if [ -f "$REPO/packages-personal.txt" ] && confirm "Install the personal package list (gaming, virtualization, NVIDIA drivers, work apps) via omarchy pkg add?"; then
    say "installing personal packages"
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages-personal.txt")
    omarchy pkg add "${pkgs[@]}"
  else
    say "skipped personal package list"
  fi
fi

echo
say "done. Run: hyprctl reload && hyprctl configerrors"
