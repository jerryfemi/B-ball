"""Renders the bow as the archer holds it (GamePigeon framing), arrow NOT included.

Measured from a GamePigeon recording (750x1334, game area 1137 px tall):
  * the bow stands right of the target, grip centre +0.25 refW from it;
  * the grip (leather, thin metal ring on top) spans 0.457..0.748 of the
    screen height; the wood is ~0.13 refW wide, the grip a bit wider;
  * above the grip the upper limb bends away to the right as it rises
    (+0.06 refW at the top edge); below the grip it runs almost straight
    down off the screen.

The image is drawn non-uniformly scaled: x in refW units (the camera's
reference width), y in screen heights, so it frames the same on any screen.
Image x = 0 at X_MIN refW, image y = 0 at Y_MIN screen heights.

usage: python tools/make_bow_view.py assets/archery/bow_view.webp
"""
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
X_MIN, X_MAX = -0.10, 0.16     # refW, relative to the grip centre line
Y_MIN, Y_MAX = -0.06, 1.06     # screen heights (0 = top of the screen)
PX_PER_REFW = 1000
PX_PER_H = 1700
SS = 2

W = int((X_MAX - X_MIN) * PX_PER_REFW)
H = int((Y_MAX - Y_MIN) * PX_PER_H)
w, h = W * SS, H * SS

GRIP_TOP, GRIP_BOT = 0.457, 0.748
RING = 0.007                   # metal ring height (screen heights)
LIP = 0.006                    # how much the grip's end ellipses bow down


def value_noise(shape, cells, seed):
    r = np.random.default_rng(seed)
    gy, gx = cells
    g = r.random((gy + 2, gx + 2))
    ys = np.linspace(0, gy, shape[0], endpoint=False)
    xs = np.linspace(0, gx, shape[1], endpoint=False)
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(shape, base, seed, octaves=4):
    out = np.zeros(shape)
    amp = 1.0
    tot = 0.0
    for o in range(octaves):
        out += amp * value_noise(shape, (base[0] * 2 ** o, base[1] * 2 ** o), seed + o)
        tot += amp
        amp *= 0.5
    return out / tot


# Screen-space coordinates of every pixel
ys = Y_MIN + (np.arange(h) + 0.5) / h * (Y_MAX - Y_MIN)          # screen heights
xs = X_MIN + (np.arange(w) + 0.5) / w * (X_MAX - X_MIN)          # refW
Y = ys[:, None]
X = xs[None, :]

# Centre line: upper limb bends right as it rises, lower part nearly straight.
up = np.clip((GRIP_TOP - ys) / GRIP_TOP, 0, None)
low = np.clip((ys - GRIP_BOT) / (1 - GRIP_BOT), 0, None)
xc = 0.062 * up ** 2.1 - 0.004 * low

# Half widths (refW)
hw_wood = np.where(ys < GRIP_TOP,
                   np.interp(ys, [Y_MIN, 0.0, 0.26, GRIP_TOP], [0.050, 0.052, 0.060, 0.064]),
                   np.interp(ys, [GRIP_BOT, 1.0, Y_MAX], [0.064, 0.062, 0.061]))
hw_grip = 0.071

u_w = (X - xc[:, None]) / hw_wood[:, None]          # -1..1 across the wood
u_g = (X - xc[:, None]) / hw_grip

# Grip band with elliptical ends (seen from slightly above: edges bow down)
sq = np.sqrt(np.clip(1 - u_g ** 2, 0, 1))
top_edge = GRIP_TOP + LIP * sq
bot_edge = GRIP_BOT + LIP * sq
in_grip = (Y >= top_edge) & (Y <= bot_edge) & (np.abs(u_g) <= 1)
in_ring = (Y >= top_edge - RING) & (Y < top_edge) & (np.abs(u_g) <= 1)
in_wood = (np.abs(u_w) <= 1) & ~in_grip & ~in_ring
inside = in_grip | in_ring | in_wood

u = np.where(in_wood, u_w, u_g)
uc = np.clip(u, -1, 1)
nz = np.sqrt(np.clip(1 - uc * uc, 0, 1))
L = np.array([-0.5, 0.0, 0.866])
ndl = np.clip(uc * L[0] + nz * L[2], 0, 1)
Hv = L + np.array([0, 0, 1.0])
Hv /= np.linalg.norm(Hv)
ndh = np.clip(uc * Hv[0] + nz * Hv[2], 0, 1)

# ---------------------------------------------------------------- wood
fig = fbm((h, w), (10, 6), 3)                       # big figure / knots
streak = fbm((h, w), (6, 30), 11)
wave = fbm((h, w), (36, 4), 17, octaves=3)
grain = 0.5 + 0.5 * np.sin(2 * np.pi * (uc * 1.6 + wave * 1.2 + fig * 1.1))
grain = 0.30 * grain + 0.35 * streak + 0.35 * fig
dark = np.array([62, 26, 12.0])
mid = np.array([100, 44, 21.0])
light = np.array([128, 60, 30.0])
g3 = grain[..., None]
wood = np.where(g3 < 0.5, dark + (mid - dark) * (g3 / 0.5), mid + (light - mid) * ((g3 - 0.5) / 0.5))

# ---------------------------------------------------------------- leather
gy = (Y - GRIP_TOP) / (GRIP_BOT - GRIP_TOP)
crease = fbm((h, w), (90, 10), 41, octaves=3)        # horizontal wrinkles
peb = fbm((h, w), (500, 60), 47, octaves=2)
leather = np.array([166, 72, 36.0]) * (0.74 + 0.38 * crease + 0.12 * peb)[..., None]

albedo = np.where(in_grip[..., None], leather, wood)
albedo = np.where(in_ring[..., None], np.array([210, 214, 220.0]), albedo)

# ---------------------------------------------------------------- shading
spec_exp = np.where(in_grip, 5.0, np.where(in_ring, 40.0, 26.0))
spec_amt = np.where(in_grip, 0.05, np.where(in_ring, 0.8, 0.16))
diffuse = 0.30 + 0.80 * ndl
edge = 0.35 + 0.65 * nz ** 0.7
col = albedo * diffuse[..., None] * edge[..., None]
col += 255.0 * ((ndh ** spec_exp) * spec_amt)[..., None]
# Dark rim under the grip's bottom lip and a soft shadow under the ring.
lip_shadow = in_wood & (Y > bot_edge) & (Y < bot_edge + 0.010)
col = np.where(lip_shadow[..., None], col * 0.55, col)
lip_line = in_grip & (Y > bot_edge - 0.004)
col = np.where(lip_line[..., None], col * 0.6, col)
col = np.clip(col, 0, 255)

alpha = inside.astype(float)
rgba = np.dstack([col, alpha[..., None] * 255.0])
pm = rgba.copy()
pm[..., :3] *= rgba[..., 3:4] / 255.0
small = np.array(Image.fromarray(pm.round().astype(np.uint8), 'RGBA').resize((W, H), Image.LANCZOS)).astype(np.float32)
a = small[..., 3:4]
rgb = np.where(a > 0, small[..., :3] * 255.0 / np.maximum(a, 1), 0)
out = np.concatenate([np.clip(rgb, 0, 255), a], -1).round().astype(np.uint8)
Image.fromarray(out, 'RGBA').save(OUT, 'WEBP', quality=90, method=6, exact=True)
print('saved', OUT, out.shape, 'x range', X_MIN, X_MAX, 'y range', Y_MIN, Y_MAX)
