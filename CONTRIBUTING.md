# Contributing

Small project, informal process. Issues and PRs welcome.

## Ground rules

- `install.sh` must stay idempotent: re-running it twice in a row should be a
  no-op the second time, aside from confirmations. Use the existing `link` and
  `require_line` helpers rather than raw `cp`/`ln`/`echo >>`.
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
sh tests/install-sh-shellcheck.sh   # installs nothing, just lints install.sh
bash -n install.sh                   # syntax check
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
