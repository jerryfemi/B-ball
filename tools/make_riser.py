"""Renders the close-up bow riser for the archery game (archer's-eye view).

GamePigeon framing: the bow is held at arm's length right in front of the
camera, so only the riser (handle) shows, running off the top and bottom of
the screen and seen from directly behind. No limbs, no string.

Shaded as a varnished wooden cylinder (diffuse + sharp clear-coat highlight +
edge falloff), long vertical grain, a leather grip with a stitched seam,
a thin metal band above the grip and an arrow shelf cut on the left.

usage: python tools/make_riser.py assets/archery/bow_riser.webp [--anchors]
Anchors are fractions of the image height (width is stretched at draw time).
"""
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
W, H = 160, 2400
SS = 2
w, h = W * SS, H * SS

# Vertical layout (fractions of image height)
BAND = (0.440, 0.452)      # metal band above the grip
GRIP = (0.452, 0.640)      # leather grip
SHELF = (0.553, 0.567)     # where the arrow rests (a third of the way down the grip)


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


fy = (np.arange(h) + 0.5) / h
in_grip = (fy >= GRIP[0]) & (fy < GRIP[1])
in_band = (fy >= BAND[0]) & (fy < BAND[1])

# Half-width profile (fraction of half image width): slimmer at the top,
# fullest at the grip, a touch slimmer below it.
half = np.interp(fy, [0.0, 0.30, 0.44, 0.46, 0.63, 0.65, 1.0],
                 [0.80, 0.86, 0.90, 0.97, 0.97, 0.90, 0.86])
half = np.where(in_band, 0.93, half)

Y, X = np.mgrid[0:h, 0:w].astype(np.float64)
u = (X + 0.5 - w / 2) / (w / 2) / half[:, None]      # -1..1 across the riser
inside = np.abs(u) <= 1.0

# Arrow shelf row (the nocked arrow covers it; only its shadow is drawn).
sy = (fy[:, None] - SHELF[0]) / (SHELF[1] - SHELF[0])

uc = np.clip(u, -1, 1)
nz = np.sqrt(np.maximum(0.0, 1 - uc * uc))
nx = uc
L = np.array([-0.55, 0.0, 0.83])
L /= np.linalg.norm(L)
Hh = L + np.array([0, 0, 1.0])
Hh /= np.linalg.norm(Hh)
ndl = np.clip(nx * L[0] + nz * L[2], 0, 1)
ndh = np.clip(nx * Hh[0] + nz * Hh[2], 0, 1)

# ---------------------------------------------------------------- wood
streak = fbm((h, w), (5, 26), 11)                    # long vertical streaks
wave = fbm((h, w), (40, 3), 17, octaves=2)
fine = fbm((h, w), (600, 40), 23, octaves=2)
grain = 0.5 + 0.5 * np.sin(2 * np.pi * (uc * 6.0 + wave * 1.6 + streak * 0.8))
grain = 0.55 * grain + 0.45 * streak
dark = np.array([58, 24, 11.0])
mid = np.array([118, 54, 26.0])
light = np.array([156, 82, 42.0])
g3 = grain[..., None]
albedo = np.where(g3 < 0.5, dark + (mid - dark) * (g3 / 0.5), mid + (light - mid) * ((g3 - 0.5) / 0.5))
albedo *= (0.92 + 0.14 * fine)[..., None]

# ---------------------------------------------------------------- grip
gy = (fy[:, None] - GRIP[0]) / (GRIP[1] - GRIP[0])
peb = fbm((h, w), (700, 26), 41, octaves=2)
wrap = 0.5 + 0.5 * np.sin(2 * np.pi * (gy * 46 + uc * 0.9))
leather = np.array([122, 50, 30.0]) * (0.80 + 0.32 * peb)[..., None] * (0.90 + 0.12 * wrap)[..., None]
seam = (np.abs(uc - 0.52) < 0.045) & (np.sin(2 * np.pi * gy * 120) > 0.1)
leather = np.where(seam[..., None], np.array([52, 22, 12.0]), leather)
edge_bind = (gy < 0.018) | (gy > 0.982)
leather = np.where(edge_bind[..., None], leather * 0.55, leather)
albedo = np.where(in_grip[:, None, None], leather, albedo)
albedo = np.where(in_band[:, None, None], np.array([196, 200, 208.0]), albedo)

# ---------------------------------------------------------------- shading
grip2 = in_grip[:, None]
band2 = in_band[:, None]
spec_exp = np.where(grip2, 6.0, np.where(band2, 50.0, 70.0))
spec_amt = np.where(grip2, 0.08, np.where(band2, 0.95, 0.30))
diffuse = 0.22 + 0.88 * ndl
edge = 0.40 + 0.60 * nz ** 0.6
col = albedo * diffuse[..., None] * edge[..., None]
col += 255.0 * ((ndh ** spec_exp) * spec_amt)[..., None]
# long clear-coat streak left of centre + faint rim light on the right
streak_hi = np.exp(-((uc + 0.38) / 0.07) ** 2) * (~grip2) * (~band2) * (0.09 + 0.06 * streak)
rim = np.exp(-((uc - 0.86) / 0.06) ** 2) * (~band2) * 0.07
col += 255.0 * (streak_hi + rim)[..., None]
# soft shadow just under the band and under the shelf
under_band = (fy[:, None] > BAND[1]) & (fy[:, None] < BAND[1] + 0.006)
col = np.where(under_band[..., None], col * 0.6, col)
shelf_shadow = (sy > 1) & (sy < 1.6) & (uc < -0.55)
col = np.where(shelf_shadow[..., None], col * 0.65, col)
col = np.clip(col, 0, 255)

alpha = inside.astype(float)
rgba = np.dstack([col, alpha[..., None] * 255.0])
pm = rgba.copy()
pm[..., :3] *= rgba[..., 3:4] / 255.0
small = np.array(Image.fromarray(pm.round().astype(np.uint8), 'RGBA').resize((W, H), Image.LANCZOS)).astype(np.float32)
a = small[..., 3:4]
rgb = np.where(a > 0, small[..., :3] * 255.0 / np.maximum(a, 1), 0)
out = np.concatenate([np.clip(rgb, 0, 255), a], -1).round().astype(np.uint8)
Image.fromarray(out, 'RGBA').save(OUT, 'WEBP', quality=92, method=6, exact=True)
print('saved', OUT, out.shape)
if '--anchors' in sys.argv:
    print('shelf y =', round((SHELF[0] + SHELF[1]) / 2, 4))
