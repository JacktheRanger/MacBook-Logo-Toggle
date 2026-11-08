#!/bin/zsh
# Builds "Logo Light Toggle.app" and installs it into ~/Applications:
#   - LogoLightToggle.applescript compiled into the app, with logo-light.sh bundled in Resources (self-contained);
#   - logo.svg → the app icon (make-icon.swift) and the custom symbol of the Control Center switch (make-symbol.py);
#   - the Control Center switch extension in Control/ (xcodebuild), embedded in the app's PlugIns.
# Everything is assembled in a temporary directory first; the installed app is only replaced once
# every step has succeeded, so a failed build leaves the working copy alone.
# Keep only this one copy: Shortcuts and Control Center find the app by bundle id, and extra copies
# with the same id can be picked instead.
set -euo pipefail
cd "${0:A:h}"

APP="$HOME/Applications/Logo Light Toggle.app"
BUNDLE_ID="local.logo-light-toggle"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
work=$(mktemp -d)
STAGE="$work/Logo Light Toggle.app"
cleanup() {
  [[ -d $STAGE ]] && $LSREGISTER -u "$STAGE" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

# 1) Control Center switch extension
python3 -I make-symbol.py logo.svg Control/Assets.xcassets/applelogo.cut.symbolset
xcodebuild -quiet -project LogoToggle.xcodeproj -target LogoLightControl -configuration Release \
  SYMROOT="$work/sym" OBJROOT="$work/obj" build
APPEX="$work/sym/Release/LogoLightControl.appex"

# 2) Icon
swift make-icon.swift logo.svg "$work/AppIcon.iconset"
iconutil -c icns -o "$work/applet.icns" "$work/AppIcon.iconset"

# 3) The app itself, assembled in the temporary directory
osacompile -o "$STAGE" LogoLightToggle.applescript
install -m 755 logo-light.sh "$STAGE/Contents/Resources/logo-light.sh"
cp "$work/applet.icns" "$STAGE/Contents/Resources/applet.icns"
INFO="$STAGE/Contents/Info.plist"
# Fixed bundle id: the shortcut's "Open App" action looks the app up by it, and the extension's id must use it as a prefix.
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$INFO"
# LSUIElement: no Dock icon while it runs, and it doesn't steal focus when triggered from Control Center.
plutil -replace LSUIElement -bool true "$INFO"
# Remove CFBundleIconName, otherwise macOS prefers osacompile's default script icon from Assets.car.
plutil -remove CFBundleIconName "$INFO" 2>/dev/null || true
# logolighttoggle://on|off: how the sandboxed Control Center extension (no root) asks the app to switch.
plutil -replace CFBundleURLTypes -json \
  '[{"CFBundleURLName":"'"$BUNDLE_ID"'","CFBundleURLSchemes":["logolighttoggle"]}]' "$INFO"

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
codesign --verify --deep --strict "$APP"
$LSREGISTER -f "$APP"
pluginkit -a "$APP/Contents/PlugIns/LogoLightControl.appex"
echo "Installed: $APP"
