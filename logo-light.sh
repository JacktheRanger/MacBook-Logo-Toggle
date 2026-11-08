#!/bin/zsh -f
# Turns the glowing Apple logo on the back of a MacBook Pro (PROLED XDR Display) on or off.
#
# Based on Apple's support article https://support.apple.com/en-us/149248 :
#   off: defaults write com.apple.CoreBrightness LEBacklightMode -int 0
#        (the logo stays dark in all lighting conditions)
#   on:  defaults delete com.apple.CoreBrightness LEBacklightMode
#        (back to the default: lit while the Mac is awake, following display brightness and ambient light)
# The value lives in root's defaults domain and applies to every user account (including macOS
# Recovery), so reading and writing it both need root. Reinstalling macOS turns the light back on.
#
# Usage: logo-light.sh [status|on|off|toggle]   (default: toggle)
#
# install-nopasswd.sh installs this script as /usr/local/libexec/logo-light behind a passwordless
# sudo rule, so when it runs as root it must not trust the caller's environment:
#   - the shebang passes -f, so zsh skips user-writable startup files such as ~/.zshenv
#     (sudo on macOS keeps HOME);
#   - as root, PATH is reset and the LOGO_LIGHT_DOMAIN test hook is ignored.

set -euo pipefail

KEY=LEBacklightMode
if [[ $EUID -eq 0 ]]; then
  export PATH=/usr/bin:/bin:/usr/sbin:/sbin
  DOMAIN=com.apple.CoreBrightness
else
  # LOGO_LIGHT_DOMAIN is for tests only (it can point at a temporary plist); leave it unset.
  DOMAIN=${LOGO_LIGHT_DOMAIN:-com.apple.CoreBrightness}
fi

as_root() {
  if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Prints on or off. No key = system default = on; 0 = off; any other value is undocumented and treated as on.
current_state() {
  local value
  if value=$(as_root defaults read "$DOMAIN" "$KEY" 2>/dev/null) && [[ $value == 0 ]]; then
    echo off
  else
    echo on
  fi
}

turn_off() { as_root defaults write "$DOMAIN" "$KEY" -int 0; }

# delete fails when the key is already gone, which is exactly the target state, so that error is ignored.
turn_on() { as_root defaults delete "$DOMAIN" "$KEY" 2>/dev/null || true; }

report() {
  local state
  state=$(current_state)
  if [[ $state == off ]]; then
    echo "Apple logo light: Off"
  else
    echo "Apple logo light: On (follows display brightness)"
  fi
}

# Inside a zsh function $0 is the function's name, so take the script name out here.
PROG=${0:t}
usage() { echo "Usage: $PROG [status|on|off|toggle]   (default: toggle)"; }

action=${1:-toggle}
case $action in
  status | on | off | toggle) ;;
  -h | --help | help) usage; exit 0 ;;
  *)
    echo "Unknown argument: $action" >&2
    usage >&2
    exit 2
    ;;
esac

# As a normal user every step goes through sudo, and the reads above deliberately swallow errors
# (a missing key is reported as an error). Authenticate once up front so that a sudo failure
# (no tty, wrong password, non-admin account) stops here instead of being misreported as "On".
if [[ $EUID -ne 0 ]]; then
  sudo -v || { echo "sudo failed; nothing was changed." >&2; exit 1; }
fi

case $action in
  status) report ;;
  on)     turn_on;  report ;;
  off)    turn_off; report ;;
  toggle)
    state=$(current_state)
    if [[ $state == off ]]; then turn_on; else turn_off; fi
    report
    ;;
esac
