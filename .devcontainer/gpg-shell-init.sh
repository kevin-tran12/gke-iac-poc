# This file is sourced by interactive shells inside the Dev Container.
# GPG pinentry needs the terminal that is current after each container restart.
case $- in
  *i*) ;;
  *) return 0 ;;
esac

gpg_tty=$(tty 2>/dev/null) || return 0
export GPG_TTY=$gpg_tty
unset gpg_tty
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
