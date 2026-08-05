"""Turn the supplied logo mock-up into an App Store compliant 1024x1024 icon.

The source is a *presentation* of an icon: a rounded tile with a drop shadow,
floating on a light background. Apple wants the artwork itself — full bleed,
square, opaque, no corner rounding (iOS masks it, and a pre-rounded icon renders
as a square-inside-a-square).

So: find the tile, crop to it, push the interior colour out into the four
rounded corners, and drop the alpha channel.
"""

import sys
from PIL import Image, ImageDraw, ImageFilter

SRC = sys.argv[1]
DST = sys.argv[2]

im = Image.open(SRC).convert("RGB")
w, h = im.size
px = im.load()

# The outer background, sampled well away from the tile and its shadow.
bg = px[2, 2]


def differs(p, tol):
    return max(abs(p[i] - bg[i]) for i in range(3)) > tol


# A high tolerance finds the solid tile edge while ignoring the soft shadow,
# which fades gradually out of the background.
TOL = 25
xs = [x for x in range(w) if any(differs(px[x, y], TOL) for y in range(0, h, 4))]
ys = [y for y in range(h) if any(differs(px[x, y], TOL) for x in range(0, w, 4))]
left, right, top, bottom = xs[0], xs[-1], ys[0], ys[-1]

# The shadow sits below and right of the tile, so those edges over-report.
# Trust the tile being square and re-derive from the shorter, cleaner side.
side = min(right - left, bottom - top) + 1
tile = im.crop((left, top, left + side, top + side))
print(f"source {w}x{h}  bg {bg}  tile ({left},{top}) {side}px")

# Fill the rounded corners with interior colour.
#
# The kept region is deliberately more generous than the tile's actual corner radius
# (0.225) and inset from the edge. The mock-up renders the tile as a physical object,
# with a lit rim along the top-left and a darker one bottom-right; keeping exactly the
# rounded rect would leave that rim as a visible arc once iOS applies its own mask.
# Over-cropping costs nothing here because the discarded area is flat colour.
radius = int(side * 0.30)
inset = int(side * 0.012)
mask = Image.new("L", (side, side), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    [inset, inset, side - 1 - inset, side - 1 - inset], radius=radius, fill=255
)

# Blurring the tile directly would smear the light outer background — which still
# occupies the corners — back inward, leaving them pale. Flood the corners with the
# tile's own mean colour first, then blur, so the bleed only ever carries tile colour.
stats = tile.convert("RGB")
n = 0
acc = [0, 0, 0]
for yy in range(0, side, 7):
    for xx in range(0, side, 7):
        if mask.getpixel((xx, yy)):
            p = stats.getpixel((xx, yy))
            for i in range(3):
                acc[i] += p[i]
            n += 1
mean = tuple(v // n for v in acc)

base = Image.composite(tile, Image.new("RGB", (side, side), mean), mask)
bleed = base.filter(ImageFilter.GaussianBlur(side * 0.06))
filled = Image.composite(tile, bleed, mask)
print(f"interior mean {mean}")

icon = filled.resize((1024, 1024), Image.LANCZOS).convert("RGB")
icon.save(DST, "PNG", optimize=True)

check = Image.open(DST)
print(f"wrote {DST}  {check.size}  mode={check.mode}  alpha={'A' in check.mode}")
print(f"corner pixel {check.convert('RGB').getpixel((3, 3))}  centre {check.convert('RGB').getpixel((512, 512))}")
