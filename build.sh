#!/bin/zsh
# Builds "MacBook Logo Toggle.app" and installs it into ~/Applications:
#   - MacBookLogoToggle.applescript compiled into the app, with logo-light.sh bundled in Resources (self-contained);
#   - logo.svg → the app icon (make-icon.swift) and the custom symbol of the Control Center switch (make-symbol.py);
#   - the Control Center switch extension in Control/ (xcodebuild), embedded in the app's PlugIns.
# Everything is assembled in a temporary directory first; the installed app is only replaced once
# every step has succeeded, so a failed build leaves the working copy alone.
# Keep only this one copy: Shortcuts and Control Center find the app by bundle id, and extra copies
# with the same id can be picked instead.
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
# Fixed bundle id: the shortcut's "Open App" action looks the app up by it, and the extension's id must use it as a prefix.
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
$LSREGISTER -f "$APP"
pluginkit -a "$APP/Contents/PlugIns/MacBookLogoToggleControl.appex"
echo "Installed: $APP"
