# Contributing

Small project, informal process. Issues and PRs welcome.

## Ground rules

- `install.sh` and `uninstall.sh` must stay idempotent: re-running either
  twice in a row should be a no-op the second time, aside from confirmations.
  Use the existing `link`/`unlink_ours` and `require_line`/`remove_line`
  helpers rather than raw `cp`/`ln`/`echo >>`.
- Every step in both scripts asks before it does anything (see `confirm`).
  Adding a new install step means adding its uninstall counterpart too, and
  gating both behind their own confirmation.
- Anything that touches `/boot`, `/etc`, or a partition table asks for
  confirmation first (see the Limine step) and backs up what it's about to
  change. Don't add a step that silently rewrites boot or system config.
- Keep machine-specific content (exact monitor names, a hardcoded package
  list) behind `-p`/`--personal`. The default path should work on any
  Omarchy machine.
- `hardwareVVizard` stays out of this repo. It has its own repo and its own
  install path; it isn't finished enough to hand to other people yet.
- Plain ASCII punctuation in prose and comments: no em or en dashes (use `-`,
  `,`, `:` or `(...)`). CI enforces this via `tests/no-fancy-dashes.sh`.

## Tests

```sh
sh tests/no-fancy-dashes.sh
sh tests/install-sh-shellcheck.sh   # installs nothing, just lints install.sh and uninstall.sh
bash -n install.sh                   # syntax check
bash -n uninstall.sh
```

## Manual check

Run `./install.sh` on a real Omarchy machine (a VM is fine), then:

```sh
hyprctl reload
hyprctl configerrors        # must be empty
systemctl status numlock-console.service
```

Confirm numlock is on before any login prompt, and that `/boot/limine.conf`
picked up a `timeout:` line and, if you said yes to it, a `/+Windows 11`
entry with a real partition GUID.

## Attribution

Please keep the credit lines in `README.md` intact.
