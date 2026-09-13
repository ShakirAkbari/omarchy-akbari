# Changelog

## Unreleased

- Initial release: `install.sh` with default and `-p`/`--personal` modes.
- Keybindings (`config/hypr/bindings.lua`) and look'n'feel
  (`config/hypr/looknfeel.lua`), symlinked into `~/.config/hypr/`.
- Spotify media-key scripts (`bin/spotify-play-key`, `bin/spotify-stop-key`).
- Clones and wires up [hypr-goldenspiral](https://github.com/ShakirAkbari/hypr-goldenspiral)
  (layout + chronobar taskbar).
- Numlock on before any login screen: SDDM greeter `Numlock=on` plus a
  `numlock-console.service` systemd unit for the virtual consoles, since
  SDDM ignores its own numlock setting under autologin.
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
