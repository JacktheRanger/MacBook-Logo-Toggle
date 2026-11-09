#!/bin/zsh
# Builds "MacBook Logo Toggle.app":
#   - MacBookLogoToggle.applescript compiled into the app, with logo-light.sh, install-nopasswd.sh and
#     eject-installer.sh bundled in Resources (self-contained);
#   - logo.svg → the app icon (make-icon.swift) and the custom symbol of the Control Center switch (make-symbol.py);
#   - the Control Center switch extension in Control/ (xcodebuild), embedded in the app's PlugIns.
#
# Usage: ./build.sh        install it into ~/Applications
#        ./build.sh dmg    package it as release/MacBook-Logo-Toggle.dmg (the download the README links
#                          to) without installing anything; needs dmgbuild (pip install dmgbuild)
#
# Everything is assembled in a temporary directory first; the installed app or the DMG is only
# replaced once every step has succeeded, so a failed build leaves the working copy alone.
# Keep only one installed copy: the Control Center switch reaches the app through its URL scheme,
# and LaunchServices can hand that URL to any other copy that claims the same scheme.
set -euo pipefail
cd "${0:A:h}"

MODE=${1:-install}
case $MODE in
  install | dmg) ;;
  *)
    echo "Usage: ./build.sh [install|dmg]" >&2
    exit 2
    ;;
esac

# The installer window (dmg/settings.py) is laid out by dmgbuild, the tool electron-builder uses for
# its DMGs too; check for it before spending a build on it. Without -I, unlike the other Python calls:
# pip installs into the user's site-packages when the system one isn't writable, and -I hides that.
if [[ $MODE == dmg ]] && ! python3 -c 'import dmgbuild' 2>/dev/null; then
  echo "./build.sh dmg needs dmgbuild: python3 -m pip install dmgbuild" >&2
  exit 1
fi

APP="$HOME/Applications/MacBook Logo Toggle.app"
BUNDLE_ID="local.macbook-logo-toggle"
# The version people see (CFBundleShortVersionString, in Finder's Get Info), for the app and the
# extension alike: it overrides the extension project's MARKETING_VERSION. A release is tagged v$VERSION.
VERSION="1.0.0"
# The DMG's file and volume names. The app's Info.plist gets them too, for eject-installer.sh to
# recognise a mounted installer by.
DMG_FILE="MacBook-Logo-Toggle.dmg"
DMG_VOLUME="MacBook Logo Toggle"
# A new CFBundleVersion on every build: Control Center (chronod) only re-reads a control's name and
# description when the extension's version changes, and otherwise keeps showing its cached copy.
BUILD_VERSION=$(date +%Y%m%d.%H%M%S)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
work=$(mktemp -d)
STAGE="$work/MacBook Logo Toggle.app"
# The staged copy carries the same bundle ids as the installed one. When installing, it is
# unregistered and deleted before the installed copy is registered (see step 4b); unregistering it
# afterwards would also drop the freshly registered extension. Here it only needs cleaning up after a
# failed build or a DMG build, which never installs it.
# Under errexit a failing last command stops a trap too, and lsregister -u fails on a copy that was
# never registered, so its result is ignored: otherwise rm never runs and the build folder stays.
cleanup() {
  if [[ -d $STAGE ]]; then $LSREGISTER -u "$STAGE" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

# 1) Control Center switch extension
python3 -I make-symbol.py logo.svg Control/Assets.xcassets/applelogo.cut.symbolset
xcodebuild -quiet -project MacBookLogoToggle.xcodeproj -target MacBookLogoToggleControl -configuration Release \
  SYMROOT="$work/sym" OBJROOT="$work/obj" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_VERSION" build
APPEX="$work/sym/Release/MacBookLogoToggleControl.appex"

# 2) Icon
swift make-icon.swift logo.svg "$work/AppIcon.iconset"
iconutil -c icns -o "$work/applet.icns" "$work/AppIcon.iconset"

# 3) The app itself, assembled in the temporary directory
osacompile -o "$STAGE" MacBookLogoToggle.applescript
install -m 755 logo-light.sh "$STAGE/Contents/Resources/logo-light.sh"
# Run from the app's window to turn passwordless switching on or off; it installs the logo-light.sh
# next to it.
install -m 755 install-nopasswd.sh "$STAGE/Contents/Resources/install-nopasswd.sh"
# Run in the background when the app is opened, to eject the installer disk image if still mounted.
install -m 755 eject-installer.sh "$STAGE/Contents/Resources/eject-installer.sh"
cp "$work/applet.icns" "$STAGE/Contents/Resources/applet.icns"
INFO="$STAGE/Contents/Info.plist"
# Fixed bundle id: the extension's id must use it as a prefix.
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$INFO"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$INFO"
plutil -replace CFBundleVersion -string "$BUILD_VERSION" "$INFO"
# LSUIElement: no Dock icon while it runs, and it doesn't steal focus when triggered from Control Center.
plutil -replace LSUIElement -bool true "$INFO"
# Remove CFBundleIconName, otherwise macOS prefers osacompile's default script icon from Assets.car.
plutil -remove CFBundleIconName "$INFO" 2>/dev/null || true
# macbooklogotoggle://on|off: how the sandboxed Control Center extension (no root) asks the app to switch.
plutil -replace CFBundleURLTypes -json \
  '[{"CFBundleURLName":"'"$BUNDLE_ID"'","CFBundleURLSchemes":["macbooklogotoggle"]}]' "$INFO"
plutil -replace InstallerImageName -string "$DMG_FILE" "$INFO"
plutil -replace InstallerVolumeName -string "$DMG_VOLUME" "$INFO"

mkdir -p "$STAGE/Contents/PlugIns"
cp -R "$APPEX" "$STAGE/Contents/PlugIns/"

# Signing: xcodebuild already signed the extension with its sandbox entitlements; sign the outer app
# without --deep, which would re-sign the extension without them.
codesign --force --sign - "$STAGE"
codesign --verify --deep --strict "$STAGE"

# 4a) DMG: the app next to a link to /Applications on the background from dmg/, so it installs by
# dragging one onto the other (layout in dmg/settings.py). Downloads of it are blocked by Gatekeeper
# until opened once with Open Anyway: the signature is ad hoc, not a notarized Developer ID one (the
# README walks through that step).
if [[ $MODE == dmg ]]; then
  python3 -m dmgbuild -s dmg/settings.py -D app="$STAGE" -D background="$PWD/dmg/background.tiff" \
    "$DMG_VOLUME" "$work/$DMG_FILE" >/dev/null
  hdiutil verify -quiet "$work/$DMG_FILE"
  mkdir -p release
  mv -f "$work/$DMG_FILE" "release/$DMG_FILE"
  echo "Built: release/$DMG_FILE"
  exit 0
fi

# 4b) Install: replace the old copy only now that everything above succeeded
mkdir -p "${APP:h}"
rm -rf "$APP"
ditto "$STAGE" "$APP"
$LSREGISTER -u "$STAGE" 2>/dev/null || true
rm -rf "$STAGE"
codesign --verify --deep --strict "$APP"
# -trusted (undocumented; Xcode registers every app it builds with lsregister -f -R -trusted): a new
# LaunchServices record is "launch-disabled" unless it is registered trusted or replaces a trusted
# record at the same path, and other LaunchServices clients often drop the old record as soon as the
# copy above replaces it. linkd skips the App Intents of a launch-disabled app ("not trusted for
# binding"), so taps on the switch fail ("Encountered action intent without linkAction") and it
# snaps back. Should -trusted ever be refused, fall back to a plain registration and leave the trust
# to the launch below.
$LSREGISTER -f -trusted "$APP" || $LSREGISTER -f "$APP"
pluginkit -a "$APP/Contents/PlugIns/MacBookLogoToggleControl.appex"

# Launching the app through LaunchServices gets it marked trusted too, so this backs up -trusted with
# nothing to parse. The no-op launch URL leaves the light alone.
open -g -a "$APP" "macbooklogotoggle://launch" ||
  echo "Couldn't launch the app once; if the Control Center switch snaps back, run: open -g -a ${(qq)APP} \"macbooklogotoggle://launch\"" >&2
echo "Installed: $APP"

# With passwordless switching the app runs the root-owned copy of logo-light.sh that install-nopasswd.sh
# made, which this build can't update (it needs sudo). The copy is world-readable, so just compare.
# Like the README's own commands, the hint assumes a single account using the passwordless rule (the
# rule is one per Mac, granted to whoever runs install-nopasswd.sh) and a shell in the repo directory.
HELPER=/usr/local/libexec/logo-light
if [[ -e $HELPER ]] && ! cmp -s logo-light.sh "$HELPER"; then
  echo "The passwordless helper $HELPER differs from logo-light.sh; update it with: sudo ./install-nopasswd.sh (or Update Passwordless in the app's window)" >&2
fi
