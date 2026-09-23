#!/bin/sh
# Shell-lints install.sh and uninstall.sh. Skips quietly if shellcheck isn't
# installed locally; CI always has it.
set -eu

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed, skipping (CI still runs this)"
  exit 0
fi

shellcheck -S warning install.sh uninstall.sh
