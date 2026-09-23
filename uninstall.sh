#!/usr/bin/env bash
# omarchy-akbari uninstaller. Mirrors install.sh: asks before every removal,
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
keys, hypr-goldenspiral, the numlock-on-boot setup older versions installed
(cleanup only), the Limine Windows entry,
xwayland-primary-monitor, Plymouth boot screen theming (and its theme-set
hook), the System menu's Reboot to Windows entry, the Claude app
launcher, the graphical sudo password prompt, the Chromium hybrid GPU
wrapper, and (if present) the personal-only monitor layout, Chromium flags,
CoolerControl fan curves, web apps, and package list. Also the xrdp and wayvnc remote desktop setups
and the Obsidian vault sync (never your vaults or your Google Drive folder).

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

# 4. Numlock on boot: cleanup only. install.sh no longer sets this up (it was
# buggy and was dropped), but machines installed earlier still have it.
SDDM_HYPR=/usr/share/sddm/hyprland.lua
SDDM_HYPR_BAK="$SDDM_HYPR.bak.omarchy-akbari"
# Made under the old repo name (omarchy-shakir) on machines set up before the rename.
[ -f "$SDDM_HYPR_BAK" ] || SDDM_HYPR_BAK="$SDDM_HYPR.bak.omarchy-shakir"
if [ -f /etc/systemd/system/numlock-console.service ] || [ -f /etc/sddm.conf.d/50-numlock.conf ] || [ -f "$SDDM_HYPR_BAK" ]; then
  if confirm "Disable numlock-on-boot and remove its files (needs sudo)?"; then
    sudo systemctl disable --now numlock-console.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/numlock-console.service
    sudo rm -f /etc/sddm.conf.d/50-numlock.conf
    sudo systemctl daemon-reload
    if [ -f "$SDDM_HYPR_BAK" ]; then
      sudo mv "$SDDM_HYPR_BAK" "$SDDM_HYPR"
      say "restored $SDDM_HYPR from $SDDM_HYPR_BAK"
    fi
    say "numlock-on-boot removed"
  else
    say "left numlock-on-boot in place"
  fi
else
  say "numlock-on-boot not installed, nothing to do"
fi

# 5. Limine: remove the Windows entry this repo added ------------------------- #
# /boot is usually root-only, so reads of it need sudo (see install.sh).
if ! sudo test -f "$LIMINE_CONF"; then
  say "no $LIMINE_CONF, nothing to do"
elif ! sudo grep -Eq 'comment: added by omarchy-(akbari|shakir)' "$LIMINE_CONF" 2>/dev/null; then
  say "no omarchy-akbari (or older omarchy-shakir) Limine entry found, nothing to do"
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
      if ($0 ~ /added by omarchy-(akbari|shakir)/) skip = 1
      next
    }
    { print }
    END { if (buf != "" && !skip) printf "%s", buf }
  ' <(sudo cat "$LIMINE_CONF") > "$tmp"
  sudo cp "$tmp" "$LIMINE_CONF"
  rm -f "$tmp"
  say "removed the Windows entry from $LIMINE_CONF"
  warn "the Limine timeout (if set to 5s) is left as is; restore a /boot/limine.conf.bak.* if you want it back"
else
  say "left the Limine Windows entry in place"
fi

# 6. Remmina: restore the default Host key ------------------------------------ #
REMMINA_PREF="$CONFIG_DIR/remmina/remmina.pref"
if [ -f "$REMMINA_PREF" ] && grep -qF "hostkey=65300" "$REMMINA_PREF"; then
  if confirm "Restore Remmina's Host key from Scroll Lock back to Right Ctrl (Remmina's default) in $REMMINA_PREF?"; then
    if pgrep -x remmina >/dev/null 2>&1; then
      warn "Remmina is running and rewrites this file on exit, which would undo this; quit Remmina (check the tray, not just the window) and re-run"
    else
      sed -i 's/^hostkey=.*/hostkey=65508/; s/^shortcutkey_grab=.*/shortcutkey_grab=65508/' "$REMMINA_PREF"
      say "restored Remmina's Host key to Right Ctrl (65508) in $REMMINA_PREF"
    fi
  else
    say "left Remmina's Host key as is"
  fi
fi

# 7. Remmina: restore the default audio redirect setting --------------------- #
if [ -f "$REMMINA_PREF" ] && grep -qF "sound=local" "$REMMINA_PREF"; then
  if confirm "Restore Remmina's default new-connection audio redirect to off (Remmina's default) in $REMMINA_PREF?"; then
    if pgrep -x remmina >/dev/null 2>&1; then
      warn "Remmina is running and rewrites this file on exit, which would undo this; quit Remmina (check the tray, not just the window) and re-run"
    else
      sed -i 's/^sound=.*/sound=off/' "$REMMINA_PREF"
      say "restored Remmina's default new-connection audio redirect to off in $REMMINA_PREF"
    fi
  else
    say "left Remmina's audio redirect default as is"
  fi
fi

# 8. xwayland-primary-monitor ------------------------------------------------ #
if [ -L "$BIN_DIR/xwayland-primary-monitor" ]; then
  if confirm "Remove xwayland-primary-monitor from $BIN_DIR and its autostart line from $HYPR_DIR/autostart.lua?"; then
    unlink_ours "$REPO/bin/xwayland-primary-monitor" "$BIN_DIR/xwayland-primary-monitor"
    remove_line "$HYPR_DIR/autostart.lua" 'o.exec_on_start("xwayland-primary-monitor")'
  else
    say "left xwayland-primary-monitor in place"
  fi
else
  say "xwayland-primary-monitor not installed, nothing to do"
fi

# 9. Personal-only: monitor layout, Chromium flags, package list ------------- #
if [ -L "$HYPR_DIR/monitors.lua" ]; then
  if confirm "Remove the personal monitor layout from $HYPR_DIR/monitors.lua?"; then
    unlink_ours "$REPO/config/hypr/monitors.lua.personal" "$HYPR_DIR/monitors.lua"
  else
    say "left the personal monitor layout in place"
  fi
else
  say "personal monitor layout not installed, nothing to do"
fi

PLUGIN_DIR="$CONFIG_DIR/omarchy/plugins/shakir.workspaces"
if [ -L "$PLUGIN_DIR/Workspaces.qml" ]; then
  if confirm "Remove the shakir.workspaces bar widget and swap it back to omarchy.workspaces?"; then
    unlink_ours "$REPO/config/omarchy/plugins/shakir.workspaces/manifest.json" "$PLUGIN_DIR/manifest.json"
    unlink_ours "$REPO/config/omarchy/plugins/shakir.workspaces/Workspaces.qml" "$PLUGIN_DIR/Workspaces.qml"
    rmdir "$PLUGIN_DIR" 2>/dev/null || true
    SHELL_JSON="$CONFIG_DIR/omarchy/shell.json"
    if [ -f "$SHELL_JSON" ] && command -v jq >/dev/null 2>&1; then
      SHELL_JSON_TMP=$(mktemp)
      jq '(.bar.layout.left, .bar.layout.center, .bar.layout.right) |= map(if .id == "shakir.workspaces" then .id = "omarchy.workspaces" else . end)' "$SHELL_JSON" > "$SHELL_JSON_TMP"
      mv "$SHELL_JSON_TMP" "$SHELL_JSON"
      say "swapped shakir.workspaces -> omarchy.workspaces in $SHELL_JSON"
    else
      warn "no $SHELL_JSON or jq not found; swap shakir.workspaces back to omarchy.workspaces yourself"
    fi
  else
    say "left the shakir.workspaces bar widget in place"
  fi
else
  say "shakir.workspaces bar widget not installed, nothing to do"
fi

SPOTIFY_PLUGIN_DIR="$CONFIG_DIR/omarchy/plugins/shakir.spotify"
if [ -L "$SPOTIFY_PLUGIN_DIR/SpotifyWidget.qml" ]; then
  if confirm "Remove the shakir.spotify bar widget?"; then
    unlink_ours "$REPO/config/omarchy/plugins/shakir.spotify/manifest.json" "$SPOTIFY_PLUGIN_DIR/manifest.json"
    unlink_ours "$REPO/config/omarchy/plugins/shakir.spotify/SpotifyWidget.qml" "$SPOTIFY_PLUGIN_DIR/SpotifyWidget.qml"
    rmdir "$SPOTIFY_PLUGIN_DIR" 2>/dev/null || true
    SHELL_JSON="$CONFIG_DIR/omarchy/shell.json"
    if [ -f "$SHELL_JSON" ] && command -v jq >/dev/null 2>&1; then
      SHELL_JSON_TMP=$(mktemp)
      # Also drop the spacer install.sh added right after it (matched by
      # position, not size, in case it was ever hand-tuned) - not just the
      # widget itself, or its gap would linger as orphaned blank space.
      jq '
        (.bar.layout.left, .bar.layout.center, .bar.layout.right) |= (
          . as $arr
          | [range(0; length) as $i
             | select(
                 ($arr[$i].id != "shakir.spotify")
                 and (($i == 0) or ($arr[$i-1].id != "shakir.spotify") or ($arr[$i].id != "omarchy.spacer"))
               )
             | $arr[$i]
            ]
        )
      ' "$SHELL_JSON" > "$SHELL_JSON_TMP"
      mv "$SHELL_JSON_TMP" "$SHELL_JSON"
      say "removed shakir.spotify from $SHELL_JSON's bar layout"
    else
      warn "no $SHELL_JSON or jq not found; remove shakir.spotify from its bar layout yourself"
    fi
  else
    say "left the shakir.spotify bar widget in place"
  fi
else
  say "shakir.spotify bar widget not installed, nothing to do"
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

CHROMIUM_USER_DESKTOP="$HOME/.local/share/applications/chromium.desktop"
CHROMIUM_DESKTOP_MARK="# added by omarchy-akbari"
if [ -L "$BIN_DIR/chromium" ] || { [ -f "$CHROMIUM_USER_DESKTOP" ] && grep -qF "$CHROMIUM_DESKTOP_MARK" "$CHROMIUM_USER_DESKTOP"; }; then
  if confirm "Remove the Chromium hybrid GPU wrapper ($BIN_DIR/chromium and its chromium.desktop)?"; then
    if [ -L "$BIN_DIR/chromium" ]; then
      unlink_ours "$REPO/bin/chromium" "$BIN_DIR/chromium"
    fi
    if [ -f "$CHROMIUM_USER_DESKTOP" ] && grep -qF "$CHROMIUM_DESKTOP_MARK" "$CHROMIUM_USER_DESKTOP"; then
      rm -f "$CHROMIUM_USER_DESKTOP"
      say "removed $CHROMIUM_USER_DESKTOP"
      latest="$(ls -t "$CHROMIUM_USER_DESKTOP".bak.* 2>/dev/null | head -1 || true)"
      if [ -n "$latest" ] && confirm "Restore the previous $CHROMIUM_USER_DESKTOP from backup ($latest)?"; then
        mv "$latest" "$CHROMIUM_USER_DESKTOP"
        say "restored $CHROMIUM_USER_DESKTOP from $latest"
      fi
      update-desktop-database "$(dirname "$CHROMIUM_USER_DESKTOP")" >/dev/null 2>&1 || true
    fi
  else
    say "left the Chromium hybrid GPU wrapper in place"
  fi
else
  say "Chromium hybrid GPU wrapper not installed, nothing to do"
fi

PLYMOUTH_HOOK="$CONFIG_DIR/omarchy/hooks/theme-set.d/plymouth-theme-sync"
if [ -f "$PLYMOUTH_HOOK" ]; then
  if confirm "Remove the theme-set hook that auto-syncs the Plymouth boot screen on every theme switch?"; then
    rm -f "$PLYMOUTH_HOOK"
    say "removed $PLYMOUTH_HOOK"
  else
    say "left the theme-set hook in place"
  fi
else
  say "theme-set hook not installed, nothing to do"
fi

if [ -L "$BIN_DIR/plymouth-theme-sync" ]; then
  if confirm "Remove plymouth-theme-sync from $BIN_DIR?"; then
    unlink_ours "$REPO/bin/plymouth-theme-sync" "$BIN_DIR/plymouth-theme-sync"
  else
    say "left plymouth-theme-sync in place"
  fi
else
  say "plymouth-theme-sync not installed, nothing to do"
fi

PLYMOUTH_SCRIPT=/usr/share/plymouth/themes/omarchy/omarchy.script
PLYMOUTH_SCRIPT_BAK="$PLYMOUTH_SCRIPT.bak.omarchy-akbari"
# Made under the old repo name (omarchy-shakir) on machines set up before the rename.
[ -f "$PLYMOUTH_SCRIPT_BAK" ] || PLYMOUTH_SCRIPT_BAK="$PLYMOUTH_SCRIPT.bak.omarchy-shakir"
if [ -f "$PLYMOUTH_SCRIPT_BAK" ]; then
  if confirm "Restore the Plymouth boot/unlock screen from before the theme recolor, wordmark, and watermark (needs sudo, rebuilds the initramfs)?"; then
    sudo mv "$PLYMOUTH_SCRIPT_BAK" "$PLYMOUTH_SCRIPT"
    say "restored $PLYMOUTH_SCRIPT from $PLYMOUTH_SCRIPT_BAK"
    if command -v limine-mkinitcpio >/dev/null 2>&1; then
      sudo limine-mkinitcpio
    else
      sudo mkinitcpio -P
    fi
    warn "SDDM's login theme recolor is left as is; there's no backup of Omarchy's stock SDDM theme to restore it from"
  else
    say "left the Plymouth boot screen wordmark and watermark in place"
  fi
else
  say "Plymouth boot screen wordmark and watermark not installed, nothing to do"
fi

if [ -L "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc" ]; then
  if confirm "Remove the 'Reboot to Windows' entry from the System menu?"; then
    unlink_ours "$REPO/config/omarchy/omarchy-menu.jsonc" "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"
    omarchy menu refresh >/dev/null 2>&1 || true
  else
    say "left the Reboot to Windows menu entry in place"
  fi
else
  say "Reboot to Windows menu entry not installed, nothing to do"
fi

if [ -L "$BIN_DIR/omarchy-reboot-to-windows" ]; then
  if confirm "Remove omarchy-reboot-to-windows from $BIN_DIR?"; then
    unlink_ours "$REPO/bin/omarchy-reboot-to-windows" "$BIN_DIR/omarchy-reboot-to-windows"
  else
    say "left omarchy-reboot-to-windows in place"
  fi
else
  say "omarchy-reboot-to-windows not installed, nothing to do"
fi

if [ -L "$HOME/.local/share/applications/Claude.desktop" ]; then
  if confirm "Remove the Claude app launcher from the app launcher?"; then
    unlink_ours "$REPO/config/applications/Claude.desktop" "$HOME/.local/share/applications/Claude.desktop"
    unlink_ours "$REPO/config/icons/claude.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/claude.svg"
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  else
    say "left the Claude app launcher in place"
  fi
else
  say "Claude app launcher not installed, nothing to do"
fi

if [ -L "$HOME/.local/share/applications/Glances.desktop" ]; then
  if confirm "Remove the Glances app launcher from the app launcher?"; then
    unlink_ours "$REPO/config/applications/Glances.desktop" "$HOME/.local/share/applications/Glances.desktop"
    unlink_ours "$REPO/config/icons/glances.png" "$HOME/.local/share/icons/hicolor/256x256/apps/glances.png"
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
  else
    say "left the Glances app launcher in place"
  fi
else
  say "Glances app launcher not installed, nothing to do"
fi

if [ -L "$BIN_DIR/sudo-askpass" ] || [ -L "$CONFIG_DIR/environment.d/sudo-askpass.conf" ]; then
  if confirm "Remove the graphical sudo password prompt (sudo-askpass and its SUDO_ASKPASS setting; leaves the zenity package)?"; then
    unlink_ours "$REPO/bin/sudo-askpass" "$BIN_DIR/sudo-askpass"
    unlink_ours "$REPO/config/environment.d/sudo-askpass.conf" "$CONFIG_DIR/environment.d/sudo-askpass.conf"
    warn "log out and back in so the session drops SUDO_ASKPASS"
  else
    say "left the graphical sudo password prompt in place"
  fi
else
  say "graphical sudo password prompt not installed, nothing to do"
fi

WINDOWS_STATE_FILE="$HOME/.local/state/omarchy-akbari/windows-boot-guid"
# Saved under the old repo name (omarchy-shakir) on machines set up before the rename.
[ -f "$WINDOWS_STATE_FILE" ] || WINDOWS_STATE_FILE="$HOME/.local/state/omarchy-shakir/windows-boot-guid"
if [ -f "$WINDOWS_STATE_FILE" ]; then
  if confirm "Remove the saved Windows dual-boot choice ($WINDOWS_STATE_FILE)?"; then
    rm -f "$WINDOWS_STATE_FILE"
    say "removed $WINDOWS_STATE_FILE"
  else
    say "left the saved Windows dual-boot choice in place"
  fi
else
  say "no saved Windows dual-boot choice, nothing to do"
fi

if [ -f "$REPO/webapps-personal.txt" ] && command -v omarchy-webapp-remove >/dev/null 2>&1; then
  while IFS='|' read -r app_name app_url _; do
    # Only ours if the launcher still opens the URL this repo installed it for.
    grep -qF "$app_url" "$HOME/.local/share/applications/$app_name.desktop" 2>/dev/null || continue
    if confirm "Remove the $app_name web app from the app launcher?"; then
      omarchy-webapp-remove "$app_name" </dev/null || warn "could not remove the $app_name web app"
    else
      say "left the $app_name web app in place"
    fi
  done < <(grep -vE '^\s*(#|$)' "$REPO/webapps-personal.txt")
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

# Remote desktop (xrdp, wayvnc) ------------------------------------------------ #
# Before the Tailscale removal below: the ufw rules are on tailscale0.
if systemctl is-enabled --quiet xrdp.service 2>/dev/null || [ -L "$HOME/.xinitrc" ]; then
  warn "this also uninstalls the xrdp, xorgxrdp and icewm packages"
  if confirm "Remove xrdp (stop the service, drop its ufw rule, ~/.xinitrc and the packages, needs sudo)?"; then
    sudo systemctl disable --now xrdp.service xrdp-sesman.service 2>/dev/null || true
    sudo ufw delete allow in on tailscale0 to any port 3389 proto tcp >/dev/null 2>&1 || warn "no ufw rule for tcp/3389 on tailscale0 to remove (or ufw is missing)"
    if [ -L "$HOME/.xinitrc" ]; then
      unlink_ours "$REPO/config/xrdp/xinitrc" "$HOME/.xinitrc"
    fi
    omarchy pkg drop xorgxrdp xrdp icewm || warn "could not remove the xrdp packages"
    say "xrdp removed"
  else
    say "left xrdp in place"
  fi
else
  say "xrdp not installed, nothing to do"
fi

if [ -L "$CONFIG_DIR/systemd/user/wayvnc.service" ] || [ -L "$BIN_DIR/wayvnc-tailscale" ]; then
  warn "this also uninstalls the wayvnc package"
  if confirm "Remove wayvnc (stop the service, drop its ufw rule, config, certificate and the package)?"; then
    systemctl --user disable --now wayvnc.service 2>/dev/null || true
    unlink_ours "$REPO/config/systemd/user/wayvnc.service" "$CONFIG_DIR/systemd/user/wayvnc.service"
    systemctl --user daemon-reload
    unlink_ours "$REPO/bin/wayvnc-tailscale" "$BIN_DIR/wayvnc-tailscale"
    unlink_ours "$REPO/config/wayvnc/config" "$CONFIG_DIR/wayvnc/config"
    # Generated by install.sh, not linked from the repo, so unlink_ours
    # doesn't apply; nothing else uses them.
    rm -f "$CONFIG_DIR/wayvnc/cert.pem" "$CONFIG_DIR/wayvnc/key.pem"
    rmdir "$CONFIG_DIR/wayvnc" 2>/dev/null || true
    sudo ufw delete allow in on tailscale0 to any port 5900 proto tcp >/dev/null 2>&1 || warn "no ufw rule for tcp/5900 on tailscale0 to remove (or ufw is missing)"
    omarchy pkg drop wayvnc || warn "could not remove wayvnc"
    say "wayvnc removed"
  else
    say "left wayvnc in place"
  fi
else
  say "wayvnc not installed, nothing to do"
fi

if grep -qF omarchy.tailscale "$CONFIG_DIR/omarchy/shell.json" 2>/dev/null && command -v omarchy-remove-service-tailscale >/dev/null 2>&1; then
  warn "this also uninstalls the tailscale package and logs this machine out of your tailnet"
  if confirm "Remove Tailscale (bar icon, admin web app, daemon, package)?"; then
    omarchy-remove-service-tailscale || warn "could not fully remove Tailscale"
  else
    say "left Tailscale in place"
  fi
fi

if [ -x "$REPO/bin/coolercontrol-apply-fans" ] && systemctl is-active --quiet coolercontrold.service; then
  if confirm "Put the fans back to automatic and delete the CoolerControl fan curves this repo added?"; then
    "$REPO/bin/coolercontrol-apply-fans" --remove || warn "could not remove the fan curves"
  else
    say "left the CoolerControl fan curves in place"
  fi
fi

if [ -L "$BIN_DIR/obsidian-sync" ] || [ -L "$CONFIG_DIR/systemd/user/obsidian-sync.timer" ]; then
  if confirm "Remove the Obsidian vault sync (stop the timer, drop the script, filter and unit files)?"; then
    systemctl --user disable --now obsidian-sync.timer 2>/dev/null || true
    systemctl --user stop obsidian-sync.service 2>/dev/null || true
    unlink_ours "$REPO/config/systemd/user/obsidian-sync.timer" "$CONFIG_DIR/systemd/user/obsidian-sync.timer"
    unlink_ours "$REPO/config/systemd/user/obsidian-sync.service" "$CONFIG_DIR/systemd/user/obsidian-sync.service"
    systemctl --user daemon-reload
    unlink_ours "$REPO/bin/obsidian-sync" "$BIN_DIR/obsidian-sync"
    unlink_ours "$REPO/config/rclone/obsidian-filter.txt" "$CONFIG_DIR/rclone/obsidian-filter.txt"
    # A marker install.sh wrote, not linked from the repo, so unlink_ours
    # doesn't apply. Removing it makes a later install redo the first sync.
    rm -f "$HOME/.local/state/omarchy-akbari/obsidian-sync-seeded"
    say "Obsidian vault sync removed"
    say "  Left alone on purpose: your vaults, the gdrive:Obsidian folder, the"
    say "  rclone remote and login (~/.config/rclone/rclone.conf) and the rclone package."
  else
    say "left the Obsidian vault sync in place"
  fi
else
  say "Obsidian vault sync not installed, nothing to do"
fi

echo
say "done. Run: hyprctl reload && hyprctl configerrors"
