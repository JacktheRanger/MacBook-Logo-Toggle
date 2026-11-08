#!/usr/bin/env python3
"""Turns logo.svg into a custom SF Symbol for Xcode (the icon of the Control Center switch).

Writes <symbolset dir>/applelogo.cut.svg + Contents.json (SF Symbols template v3).
The logo has no weights, so the Ultralight-S / Regular-S / Black-S variants share one path and the
system interpolates the other weights and the M / L scales. build.sh regenerates it on every build;
don't edit the output by hand.
Usage: make-symbol.py <logo.svg> <xxx.symbolset directory>
"""
import json
import os
import re
import sys

logo_svg, out_dir = sys.argv[1:3]
NAME = "applelogo.cut"

src = open(logo_svg).read()
vb_w, vb_h = map(float, re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', src).groups())
d = re.search(r' d="([^"]+)"', src).group(1)

# Template S scale: baseline at y=696, capline at y=625.541 (cap height 70.459), y grows downward.
# The logo is a little taller than the cap height and sits roughly centred on the cap-height midline,
# dipping slightly below the baseline. TOP is relative to the baseline.
HEIGHT, TOP, SIDE = 86.0, -78.0, 3.0
s = HEIGHT / vb_h
width = vb_w * s

def transform(match):
    nums = [float(v) for v in match.group(2).split()]
    pts = [f"{x * s + SIDE:.3f} {y * s + TOP:.3f}" for x, y in zip(nums[::2], nums[1::2])]
    return match.group(1) + " ".join(pts)

# logo.svg only contains absolute M / C / Z commands (as written by trace-logo.py)
if re.search(r"[^MCZ\d\s.\-]", d):
    sys.exit("logo.svg uses path commands other than M/C/Z, which make-symbol.py does not support")
path = re.sub(r"([MC])([^MCZ]+)", transform, d)

advance = width + 2 * SIDE
columns = {"Ultralight-S": 560.0, "Regular-S": 1850.0, "Black-S": 2850.0}
guide = 'style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;"'
margin = 'style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;"'

lines = []
for name, x in columns.items():
    lines.append(f'  <line id="left-margin-{name}" {margin} x1="{x:.3f}" x2="{x:.3f}" y1="600.785" y2="720.121"/>')
    lines.append(f'  <line id="right-margin-{name}" {margin} x1="{x + advance:.3f}" x2="{x + advance:.3f}" y1="600.785" y2="720.121"/>')
symbols = "\n".join(
    f'  <g id="{name}" transform="matrix(1 0 0 1 {x:.3f} 696)">\n   <path d="{path}"/>\n  </g>'
    for name, x in columns.items()
)

svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <!-- Generated from logo.svg by make-symbol.py; do not edit by hand -->
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;font-weight:bold;" transform="matrix(1 0 0 1 263 322)">Weight/Scale Variations</text>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>
  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1951)">Requires Xcode 13 or greater</text>
  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1969)">Generated from {NAME}</text>
  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1987)">Typeset at 100 points</text>
 </g>
 <g id="Guides">
  <line id="Baseline-S" {guide} x1="263" x2="3036" y1="696" y2="696"/>
  <line id="Capline-S" {guide} x1="263" x2="3036" y1="625.541" y2="625.541"/>
  <line id="Baseline-M" {guide} x1="263" x2="3036" y1="1126" y2="1126"/>
  <line id="Capline-M" {guide} x1="263" x2="3036" y1="1055.54" y2="1055.54"/>
  <line id="Baseline-L" {guide} x1="263" x2="3036" y1="1556" y2="1556"/>
  <line id="Capline-L" {guide} x1="263" x2="3036" y1="1485.54" y2="1485.54"/>
{chr(10).join(lines)}
 </g>
 <g id="Symbols">
{symbols}
 </g>
</svg>
'''

os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, f"{NAME}.svg"), "w") as f:
    f.write(svg)
with open(os.path.join(out_dir, "Contents.json"), "w") as f:
    json.dump({"info": {"author": "xcode", "version": 1},
               "symbols": [{"filename": f"{NAME}.svg", "idiom": "universal"}]}, f, indent=2)
