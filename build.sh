#!/bin/zsh
# Builds "MacBook Logo Toggle.app" and installs it into ~/Applications:
#   - MacBookLogoToggle.applescript compiled into the app, with logo-light.sh bundled in Resources (self-contained);
#   - logo.svg → the app icon (make-icon.swift) and the custom symbol of the Control Center switch (make-symbol.py);
#   - the Control Center switch extension in Control/ (xcodebuild), embedded in the app's PlugIns.
# Everything is assembled in a temporary directory first; the installed app is only replaced once
# every step has succeeded, so a failed build leaves the working copy alone.
# Keep only this one copy: the Control Center switch reaches the app through its URL scheme, and
# LaunchServices can hand that URL to any other copy that claims the same scheme.
set -euo pipefail
cd "${0:A:h}"

APP="$HOME/Applications/MacBook Logo Toggle.app"
BUNDLE_ID="local.macbook-logo-toggle"
# A new CFBundleVersion on every build: Control Center (chronod) only re-reads a control's name and
# description when the extension's version changes, and otherwise keeps showing its cached copy.
BUILD_VERSION=$(date +%Y%m%d.%H%M%S)
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
work=$(mktemp -d)
STAGE="$work/MacBook Logo Toggle.app"
# The staged copy carries the same bundle ids as the installed one. On success it is unregistered
# and deleted before the installed copy is registered (see step 4); unregistering it afterwards would
# also drop the freshly registered extension. Here it only needs cleaning up after a failed build.
cleanup() {
  [[ -d $STAGE ]] && $LSREGISTER -u "$STAGE" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

# 1) Control Center switch extension
python3 -I make-symbol.py logo.svg Control/Assets.xcassets/applelogo.cut.symbolset
xcodebuild -quiet -project MacBookLogoToggle.xcodeproj -target MacBookLogoToggleControl -configuration Release \
  SYMROOT="$work/sym" OBJROOT="$work/obj" CURRENT_PROJECT_VERSION="$BUILD_VERSION" build
APPEX="$work/sym/Release/MacBookLogoToggleControl.appex"

# 2) Icon
swift make-icon.swift logo.svg "$work/AppIcon.iconset"
iconutil -c icns -o "$work/applet.icns" "$work/AppIcon.iconset"

# 3) The app itself, assembled in the temporary directory
osacompile -o "$STAGE" MacBookLogoToggle.applescript
install -m 755 logo-light.sh "$STAGE/Contents/Resources/logo-light.sh"
cp "$work/applet.icns" "$STAGE/Contents/Resources/applet.icns"
INFO="$STAGE/Contents/Info.plist"
# Fixed bundle id: the extension's id must use it as a prefix.
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$INFO"
plutil -replace CFBundleVersion -string "$BUILD_VERSION" "$INFO"
# LSUIElement: no Dock icon while it runs, and it doesn't steal focus when triggered from Control Center.
plutil -replace LSUIElement -bool true "$INFO"
# Remove CFBundleIconName, otherwise macOS prefers osacompile's default script icon from Assets.car.
plutil -remove CFBundleIconName "$INFO" 2>/dev/null || true
# macbooklogotoggle://on|off: how the sandboxed Control Center extension (no root) asks the app to switch.
plutil -replace CFBundleURLTypes -json \
  '[{"CFBundleURLName":"'"$BUNDLE_ID"'","CFBundleURLSchemes":["macbooklogotoggle"]}]' "$INFO"

mkdir -p "$STAGE/Contents/PlugIns"
cp -R "$APPEX" "$STAGE/Contents/PlugIns/"

# Signing: xcodebuild already signed the extension with its sandbox entitlements; sign the outer app
# without --deep, which would re-sign the extension without them.
codesign --force --sign - "$STAGE"
codesign --verify --deep --strict "$STAGE"

# 4) Install: replace the old copy only now that everything above succeeded
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
  echo "The passwordless helper $HELPER differs from logo-light.sh; update it with: sudo ./install-nopasswd.sh" >&2
fi
