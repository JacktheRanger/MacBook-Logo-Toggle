#!/bin/zsh -f
# Ejects the app's installer disk image (release/MacBook-Logo-Toggle.dmg from ./build.sh dmg) if it is
# still mounted. MacBook Logo Toggle.app bundles this script and runs it in the background whenever it
# is opened directly from where it is installed.
#
# Only the app itself can do this: a disk image is passive, and nothing runs when the app is dragged
# into Applications. What can be done is ejecting it the first time the installed app is opened, which
# a downloaded copy needs anyway (Open Anyway, see the README). It saves leaving the installer mounted
# next to the installed app, and mounting a second, near-identically named volume when installing again.
#
# The image is recognised by its names only; nothing on the volume is read, because reading files on
# a removable volume makes macOS ask for permission. Both names must match:
#   - the image file starts with the DMG's base name and ends in .dmg (a browser's " (1)" for a
#     repeated download keeps the start);
#   - the volume is named after the app, optionally followed by the " 1" macOS adds when a volume of the
#     same name is already mounted.
# Both names come from build.sh, which writes them into the app's Info.plist (InstallerImageName,
# InstallerVolumeName), so the two can't drift apart.
#
# Accepted costs: a mounted installer of a newer version that hasn't been dragged in yet is ejected too
# when the installed app is opened (by name, "already installed" can't be told from "not installed
# yet"); double-clicking the DMG mounts it again. An unrelated image that happens to have both names
# would be ejected as well, which no real software would.
#
# Never forced: a volume in use (Quick Look on a file in it, a shell cd'd into it) stays mounted. A
# volume the app itself runs from is skipped too, though the app doesn't run this from a disk image.
# Failures are only printed: this is tidying up, and must never get in the user's way.

set -uo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

CONTENTS=${0:A:h:h}
APP=${CONTENTS:h}
image_name=$(plutil -extract InstallerImageName raw -o - "$CONTENTS/Info.plist") || exit 0
volume_name=$(plutil -extract InstallerVolumeName raw -o - "$CONTENTS/Info.plist") || exit 0
image_base=${image_name%.dmg}

info=$(mktemp) || exit 0
trap 'rm -f "$info"' EXIT
hdiutil info -plist >"$info" || { echo "Couldn't list mounted disk images" >&2; exit 0; }

# plutil prints an array's length for "raw"; a missing key fails, which ends the loop.
image_count=$(plutil -extract images raw -o - "$info" 2>/dev/null) || exit 0
for (( i = 0; i < image_count; i++ )); do
  image_path=$(plutil -extract "images.$i.image-path" raw -o - "$info" 2>/dev/null) || continue
  [[ ${image_path:t} == "$image_base"*.dmg ]] || continue

  mount_point= device= runs_here=
  entity_count=$(plutil -extract "images.$i.system-entities" raw -o - "$info" 2>/dev/null) || continue
  for (( j = 0; j < entity_count; j++ )); do
    entry=$(plutil -extract "images.$i.system-entities.$j.dev-entry" raw -o - "$info" 2>/dev/null) || entry=
    # The whole disk (/dev/diskN, not a slice): ejecting it detaches the image itself
    [[ $entry == /dev/disk<-> ]] && device=$entry
    point=$(plutil -extract "images.$i.system-entities.$j.mount-point" raw -o - "$info" 2>/dev/null) || continue
    [[ $APP == "$point"/* ]] && runs_here=1
    name=${point:t}
    [[ $name == "$volume_name" || $name == "$volume_name "<-> ]] && mount_point=$point
  done
  [[ -n $mount_point && -z $runs_here ]] || continue

  if diskutil eject "${device:-$mount_point}" >/dev/null; then
    echo "Ejected the installer $mount_point"
  else
    echo "Left the installer $mount_point mounted (it may be in use)" >&2
  fi
done
exit 0
