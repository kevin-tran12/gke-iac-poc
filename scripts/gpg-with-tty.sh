#!/usr/bin/env bash
set -euo pipefail

# Git sends commit data to GPG over stdin, so `tty` cannot resolve the terminal
# here. The Git parent process still has the controlling terminal when the
# commit originated in an interactive shell.
tty_name=$(ps -o tty= -p "$PPID" | tr -d '[:space:]')
case "$tty_name" in
  pts/* | tty*)
    export GPG_TTY="/dev/${tty_name}"
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
    ;;
esac

exec /usr/bin/gpg "$@"
