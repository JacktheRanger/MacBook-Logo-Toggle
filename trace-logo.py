"""Traces the flat logo from a reference image: the opaque area is the apple + leaf, the dark grey arc is the cut.
Writes logo.svg (black fill; the cut is a real gap, no mask) and a preview PNG.
Only run by hand when re-tracing or adjusting the cut (needs Pillow); builds only use its output, logo.svg.
The cut follows the band's own width, which tapers from the lower left to the upper right; [cut scale] multiplies it.
Usage: python3 -I trace-logo.py <reference.png> <out.svg> <preview.png> [cut scale] [right end dx] [right end dy]
The current logo.svg was made with cut scale 1.7, right end dx 45, dy 50, from a 1024×1238 PNG of the classic silver Apple logo
(at scale 1 the upper right of the cut fades below a pixel at the Control Center symbol's size; 1.7 keeps the whole cut visible).
"""
import sys, math
from PIL import Image, ImageDraw, ImageFilter

src, out_svg, out_png = sys.argv[1:4]
# Cut width as a multiple of the band's measured width (step 2b)
CUT_SCALE = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
# Shift of the cut's right end (px), so it exits through the right shoulder instead of leaving a sliver along the top edge
END_DX = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0
END_DY = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0

im = Image.open(src).convert('RGBA')
W, H = im.size
px = im.load()

# 1) Centre line of the cut: on each row, find the grey band where the colour turns clearly darker and take its middle
arc = []
for y in range(300, H - 200):
    xs = None
    for x in range(14, W - 14):
        r, g, b, a = px[x, y]
        if a < 255:
            continue
        ref = px[x - 12, y]
        if ref[3] == 255 and ref[0] - r > 25 and r < 215:
            # Start of the dark band; walk right to find its end
            x2 = x
            while x2 < W - 1 and px[x2, y][0] < ref[0] - 15 and px[x2, y][3] == 255:
                x2 += 1
            if 8 <= x2 - x <= 60:
                xs = (x + x2) / 2
            break
    if xs is not None:
        arc.append((xs, y))

# Drop outliers: x decreases steadily as y grows along the arc, so filter with a sliding median
arc.sort(key=lambda p: p[1])
clean = []
for i, (x, y) in enumerate(arc):
    win = [p[0] for p in arc[max(0, i - 6):i + 7]]
    med = sorted(win)[len(win) // 2]
    if abs(x - med) < 10:
        clean.append((x, y))
arc = clean

# 2) Least-squares cubic Bezier fit (fixed end points, chord-length parameterisation)
P0, P3 = arc[-1], arc[0]  # lower left to upper right
pts = arc[::-1]
d = [0.0]
for a, b in zip(pts, pts[1:]):
    d.append(d[-1] + math.dist(a, b))
ts = [v / d[-1] for v in d]
# Solve for P1, P2 minimising sum |B(t) - p|^2
A11 = A12 = A22 = 0.0
Cx1 = Cy1 = Cx2 = Cy2 = 0.0
for t, (x, y) in zip(ts, pts):
    b0, b1, b2, b3 = (1 - t) ** 3, 3 * t * (1 - t) ** 2, 3 * t * t * (1 - t), t ** 3
    rx = x - b0 * P0[0] - b3 * P3[0]
    ry = y - b0 * P0[1] - b3 * P3[1]
    A11 += b1 * b1; A12 += b1 * b2; A22 += b2 * b2
    Cx1 += b1 * rx; Cy1 += b1 * ry; Cx2 += b2 * rx; Cy2 += b2 * ry
det = A11 * A22 - A12 * A12
P1 = ((Cx1 * A22 - Cx2 * A12) / det, (Cy1 * A22 - Cy2 * A12) / det)
P2 = ((A11 * Cx2 - A12 * Cx1) / det, (A11 * Cy2 - A12 * Cy1) / det)

def bez(t):
    m = 1 - t
    return (m**3 * P0[0] + 3 * m * m * t * P1[0] + 3 * m * t * t * P2[0] + t**3 * P3[0],
            m**3 * P0[1] + 3 * m * m * t * P1[1] + 3 * m * t * t * P2[1] + t**3 * P3[1])

# 2b) Width profile: the band is wide at the lower left and narrows towards the upper right.
# Measure it across the fitted centre line (before the right end is shifted below): from the centre, walk out along the
# normal on both sides until the colour is clearly lighter than the band (same contrast as step 1) or leaves the opaque area.
def red(x, y):
    x0, y0 = int(x), int(y); fx, fy = x - x0, y - y0
    if px[x0, y0][3] < 255 or px[x0 + 1, y0 + 1][3] < 255:
        return 999
    return (px[x0, y0][0] * (1 - fx) * (1 - fy) + px[x0 + 1, y0][0] * fx * (1 - fy)
            + px[x0, y0 + 1][0] * (1 - fx) * fy + px[x0 + 1, y0 + 1][0] * fx * fy)
samples = []
for i in range(3, 98):  # the ends meet the outline, where the band is cut off
    t = i / 100
    x, y = bez(t)
    a, b = bez(t - 0.005), bez(t + 0.005)
    n = math.dist(a, b); nx, ny = -(b[1] - a[1]) / n, (b[0] - a[0]) / n
    c = red(x, y)
    w = 0.0
    for sgn in (1, -1):
        s = 0.0
        while s < 60 and red(x + sgn * nx * s, y + sgn * ny * s) < c + 25:
            s += 0.25
        w += s
    samples.append((t, w))
# Smooth with a Gaussian kernel so the cut's edges stay smooth; past the measured range the width stays at its end value.
# A low-order polynomial can't follow this profile (it narrows slowly, then quickly, then hardly at all).
def band_width(t):
    t = min(max(t, samples[0][0]), samples[-1][0])
    wts = [math.exp(-((t - ts_) / 0.06) ** 2 / 2) for ts_, _ in samples]
    return sum(w_ * v for w_, (_, v) in zip(wts, samples)) / sum(wts)
print('band width (px) at t = 0, .25, .5, .75, 1:', [round(band_width(t), 1) for t in (0, .25, .5, .75, 1)])

P2 = (P2[0] + END_DX * 0.6, P2[1] + END_DY * 0.6)
P3 = (P3[0] + END_DX, P3[1] + END_DY)

err = max(min(math.dist(bez(i / 400), p) for i in range(401)) for p in pts[::5])
print(f'{len(pts)} arc points, max fit error {err:.1f}px, P0={P0} P3={P3}')

# Extend both ends along the tangent so the cut goes all the way through the outline
curve = [bez(i / 200) for i in range(201)]
def extend(a, b, L):
    vx, vy = a[0] - b[0], a[1] - b[1]
    n = math.hypot(vx, vy)
    return (a[0] + vx / n * L, a[1] + vy / n * L)
curve = [extend(curve[0], curve[3], L) for L in (80, 40)] + curve + [extend(curve[-1], curve[-4], L) for L in (40, 80)]

# 3) Cut the gap out of the outline mask (fully opaque pixels), supersample 2x and blur for sub-pixel smooth marching squares
S = 2
mask = Image.new('L', (W, H), 0)
mp = mask.load()
for y in range(H):
    for x in range(W):
        if px[x, y][3] == 255:
            mp[x, y] = 255
mask = mask.resize((W * S, H * S), Image.NEAREST)
# Draw the cut as a smooth band polygon (centre line offset by half the local width along the normal on each side); a thick polyline bulges at its joints
left_side, right_side = [], []
for i, (x, y) in enumerate(curve):
    a = curve[max(i - 1, 0)]; b = curve[min(i + 1, len(curve) - 1)]
    tx, ty = b[0] - a[0], b[1] - a[1]
    n = math.hypot(tx, ty)
    t = min(max((i - 2) / 200, 0.0), 1.0)  # curve[2:203] are bez(0..1); the two extensions on each side reuse the end widths
    half = CUT_SCALE * band_width(t) / 2
    nx, ny = -ty / n * half, tx / n * half
    left_side.append(((x + nx) * S, (y + ny) * S))
    right_side.append(((x - nx) * S, (y - ny) * S))
ImageDraw.Draw(mask).polygon(left_side + right_side[::-1], fill=0)
mask = mask.filter(ImageFilter.GaussianBlur(radius=2.2 * S))

# 4) Marching squares (iso=128); the grid is padded with 0 so every contour closes
GW, GH = mask.size
g = list(mask.get_flattened_data()) if hasattr(mask, 'get_flattened_data') else list(mask.getdata())
def v(x, y):
    if x < 0 or y < 0 or x >= GW or y >= GH:
        return 0
    return g[y * GW + x]
ISO = 127.5
def lerp(a, b):
    return (ISO - a) / (b - a)
segs = {}
def add(k1, p1, k2, p2):
    segs.setdefault(k1, [p1, []])[1].append(k2)
    segs.setdefault(k2, [p2, []])[1].append(k1)
for y in range(-1, GH):
    for x in range(-1, GW):
        tl, tr, br, bl = v(x, y), v(x + 1, y), v(x + 1, y + 1), v(x, y + 1)
        c = (tl > ISO) << 3 | (tr > ISO) << 2 | (br > ISO) << 1 | (bl > ISO)
        if c in (0, 15):
            continue
        E = {}
        def top():    return (('h', x, y),     (x + lerp(tl, tr), y))
        def right():  return (('v', x + 1, y), (x + 1, y + lerp(tr, br)))
        def bottom(): return (('h', x, y + 1), (x + lerp(bl, br), y + 1))
        def left():   return (('v', x, y),     (x, y + lerp(tl, bl)))
        table = {
            1: [(left, bottom)], 2: [(bottom, right)], 3: [(left, right)], 4: [(top, right)],
            6: [(top, bottom)], 7: [(left, top)], 8: [(left, top)], 9: [(top, bottom)],
            11: [(top, right)], 12: [(left, right)], 13: [(bottom, right)], 14: [(left, bottom)],
        }
        if c in (5, 10):
            center = (tl + tr + br + bl) / 4 > ISO
            if c == 5:
                table[5] = [(left, top), (bottom, right)] if center else [(top, right), (left, bottom)]
            else:
                table[10] = [(top, right), (left, bottom)] if center else [(left, top), (bottom, right)]
        for e1, e2 in table[c]:
            (k1, p1), (k2, p2) = e1(), e2()
            add(k1, p1, k2, p2)

loops, seen = [], set()
for start in segs:
    if start in seen:
        continue
    loop, prev, cur = [], None, start
    while True:
        seen.add(cur)
        loop.append(segs[cur][0])
        nbrs = [n for n in segs[cur][1] if n != prev]
        nxt = next((n for n in nbrs if n not in seen), None)
        if nxt is None:
            break
        prev, cur = cur, nxt
    if len(loop) > 40:
        loops.append([(x / S, y / S) for x, y in loop])
print('contours:', len(loops), [len(l) for l in loops])

# 5) RDP simplification + Catmull-Rom to cubic Beziers (sharp turns keep their corners)
def rdp(points, eps):
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1e-9
    i_max, d_max = 0, -1
    for i in range(1, len(points) - 1):
        p = points[i]
        dd = abs(dy * (p[0] - a[0]) - dx * (p[1] - a[1])) / n
        if dd > d_max:
            i_max, d_max = i, dd
    if d_max > eps:
        return rdp(points[:i_max + 1], eps)[:-1] + rdp(points[i_max:], eps)
    return [a, b]

def closed_rdp(loop, eps):
    # Split at the point farthest from the start and run RDP on both halves
    far = max(range(len(loop)), key=lambda i: math.dist(loop[0], loop[i]))
    a = rdp(loop[:far + 1], eps)
    b = rdp(loop[far:] + [loop[0]], eps)
    return a[:-1] + b[:-1]

def to_path(P):
    n = len(P)
    def turn(i):
        a, b, c = P[i - 1], P[i], P[(i + 1) % n]
        v1 = (b[0] - a[0], b[1] - a[1]); v2 = (c[0] - b[0], c[1] - b[1])
        ang = math.atan2(v1[0] * v2[1] - v1[1] * v2[0], v1[0] * v2[0] + v1[1] * v2[1])
        return abs(math.degrees(ang))
    corner = [turn(i) > 55 for i in range(n)]
    f = lambda p: f'{p[0]:.1f} {p[1]:.1f}'
    out = [f'M{f(P[0])}']
    for i in range(n):
        p0, p1, p2, p3 = P[i - 1], P[i], P[(i + 1) % n], P[(i + 2) % n]
        c1 = p1 if corner[i] else (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = p2 if corner[(i + 1) % n] else (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f'C{f(c1)} {f(c2)} {f(p2)}')
    return ''.join(out) + 'Z'

simplified = [closed_rdp(l, 0.6) for l in loops]
print('points after simplification:', [len(s) for s in simplified])
allp = [p for s in simplified for p in s]
x0, y0 = min(p[0] for p in allp), min(p[1] for p in allp)
x1, y1 = max(p[0] for p in allp), max(p[1] for p in allp)
shift = [[(x - x0, y - y0) for x, y in s] for s in simplified]
vb_w, vb_h = x1 - x0, y1 - y0
d_attr = ''.join(to_path(s) for s in shift)
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vb_w:.1f} {vb_h:.1f}" width="{vb_w:.0f}" height="{vb_h:.0f}">
  <!-- Flat logo: the classic apple + leaf with an arc cut from lower left to upper right, narrowing as it rises (the cut is a real gap, no mask).
       Traced from a reference image by trace-logo.py; the single source for the app icon and the Control Center symbol. -->
  <path fill="#000000" fill-rule="evenodd" d="{d_attr}"/>
</svg>
'''
open(out_svg, 'w').write(svg)

prev = Image.new('RGBA', (W, H), (255, 255, 255, 255))
dr = ImageDraw.Draw(prev)
for s in simplified:
    dr.polygon(s, fill=(0, 0, 0, 255))
prev.thumbnail((512, 620))
prev.save(out_png)
print('viewBox', round(vb_w, 1), round(vb_h, 1))
