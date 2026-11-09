# dmgbuild settings for the installer window of release/MacBook-Logo-Toggle.dmg. ./build.sh dmg runs
#   dmgbuild -s dmg/settings.py -D app=<staged .app> -D background=<dmg/background.tiff> <volume name> <output .dmg>
# dmgbuild executes this file with `defines` (the -D values) in scope and no __file__, so paths come
# in through defines. The volume and file names live in build.sh, which also writes them into the
# app's Info.plist for eject-installer.sh.
#
# The layout below is the single source for the icon positions: dmg/render-background.py reads it to
# draw the arrow between the two icons, so after changing it, run that script and commit the new
# dmg/background.tiff.
#
# Finder constraints the background is drawn for (from the same layout in OCR's installer, checked in
# Finder): the window is the size of the background image, and the title bar takes about 32pt off the
# bottom of the image; on a background image icon labels are always black, so the icons sit on the
# light part.
import os.path

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
app_name = os.path.basename(app)

format = "ULFO"  # LZFSE: smaller and faster to open than the default UDBZ; needs macOS 10.11+
files = [app]
symlinks = {"Applications": "/Applications"}
# The app's own icon on the mounted volume (Desktop, Finder sidebar)
icon = os.path.join(app, "Contents", "Resources", "applet.icns")
background = defines["background"]  # noqa: F821

window_rect = ((200, 120), (640, 432))
default_view = "icon-view"
icon_size = 100
text_size = 12
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

# Icon centres, relative to the top left of the window's content area (= of the background image).
# Vertically, icon plus label sit midway between the band at the top and the visible bottom edge.
icon_locations = {
    app_name: (196, 256),
    "Applications": (444, 256),
    # dmgbuild copies the volume icon and the background into the volume root without positions;
    # with hidden files shown (Cmd-Shift-.), Finder would then lay them out over the background.
    # Placed below the bottom edge they add a scroll bar at most, and don't cover anything.
    # (The invisible flag wouldn't help: with hidden files shown, Finder shows those files too.)
    ".background.tiff": (213, 432 + 512),
    ".VolumeIcon.icns": (427, 432 + 512),
}
