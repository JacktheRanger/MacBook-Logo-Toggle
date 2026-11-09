"""Renders the installer window's background: dmg/background.html -> dmg/background.tiff.

Usage: python3 -I dmg/render-background.py

Takes a screenshot of the page with headless Chrome at @1x and @2x and combines the two with
`tiffutil -cathidpicheck` into one HiDPI tiff; Finder uses the @2x layer on Retina displays.

Not part of ./build.sh: rendering needs Google Chrome (CHROME_PATH overrides where to find it), so the
output is committed and the build only copies it. Run this after changing background.html, or the
window size, icon size or icon positions in settings.py, then build the DMG and look at it.

The layout comes from settings.py only: this script executes it, the way dmgbuild does, and passes the
window size and icon positions to the page, which sizes itself and draws the arrow between the icons.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path

HERE = Path(__file__).resolve().parent


def fail(message):
    sys.exit(f"render-background: {message}")


def read_layout():
    # The same defines build.sh passes; their values don't matter for the layout.
    settings = {"defines": {"app": "MacBook Logo Toggle.app", "background": ""}}
    source = (HERE / "settings.py").read_text(encoding="utf-8")
    exec(compile(source, str(HERE / "settings.py"), "exec"), settings, settings)
    (_, (width, height)) = settings["window_rect"]
    locations = settings["icon_locations"]
    return {
        "width": width,
        "height": height,
        "iconSize": settings["icon_size"],
        "app": list(locations[settings["app_name"]]),
        "apps": list(locations["Applications"]),
    }


def pixel_size(png):
    out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", png], capture_output=True, text=True, check=True).stdout
    values = dict(line.split(":") for line in out.splitlines()[1:])
    return int(values["  pixelWidth"]), int(values["  pixelHeight"])


def main():
    chrome = os.environ.get("CHROME_PATH", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    if not os.path.isfile(chrome):
        fail(f"Google Chrome not found at {chrome}; set CHROME_PATH to its executable.")

    layout = read_layout()
    url = (HERE / "background.html").as_uri() + "?layout=" + urllib.parse.quote(json.dumps(layout))
    print(f"Background {layout['width']}x{layout['height']}pt; app {layout['app']}, Applications {layout['apps']}, icons {layout['iconSize']}pt")

    with tempfile.TemporaryDirectory() as work:
        shots = []
        for scale in (1, 2):
            shot = os.path.join(work, f"background@{scale}x.png")
            subprocess.run(
                [
                    chrome,
                    "--headless",
                    "--hide-scrollbars",
                    "--no-first-run",
                    "--no-default-browser-check",
                    f"--user-data-dir={work}/profile",  # never the user's own Chrome profile
                    f"--window-size={layout['width']},{layout['height']}",
                    f"--force-device-scale-factor={scale}",
                    "--virtual-time-budget=5000",  # let the logo image and fonts load first
                    f"--screenshot={shot}",
                    url,
                ],
                capture_output=True,
                check=True,
            )
            expected = (layout["width"] * scale, layout["height"] * scale)
            if pixel_size(shot) != expected:
                fail(f"@{scale}x screenshot is {pixel_size(shot)}, expected {expected}.")
            shots.append(shot)

        # -cathidpicheck only warns, and still exits 0, when the second image isn't exactly twice the
        # first (Finder then doesn't use it as @2x), so a warning counts as failure too. The committed
        # tiff is only replaced once the combined one has passed.
        combined = os.path.join(work, "background.tiff")
        result = subprocess.run(["tiffutil", "-cathidpicheck", *shots, "-out", combined], capture_output=True, text=True)
        report = result.stdout + result.stderr
        if result.returncode != 0 or "warning" in report.lower():
            fail(f"tiffutil failed: {report.strip()}")
        shutil.copyfile(combined, HERE / "background.tiff")
    print("Wrote dmg/background.tiff")


if __name__ == "__main__":
    main()
