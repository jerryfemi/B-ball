"""Procedurally renders the foreground bow (archer's view, GamePigeon-style):
glossy varnished wood limbs + riser, leather grip wrap with stitching, a
metal ring at the top of the grip. Output: RGBA WebP, transparent background.
"""
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
W, H = 240, 2400          # final size
SS = 2                    # supersampling
w, h = W * SS, H * SS
rng = np.random.default_rng(7)

def value_noise(shape, cells, seed):
    r = np.random.default_rng(seed)
    gy, gx = cells
    g = r.random((gy + 2, gx + 2))
    ys = np.linspace(0, gy, shape[0], endpoint=False)
    xs = np.linspace(0, gx, shape[1], endpoint=False)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = ys - y0; fx = xs - x0
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]

def fbm(shape, base, seed, octaves=4):
    out = np.zeros(shape); amp = 1.0; tot = 0.0
    for o in range(octaves):
        cells = (base[0] * 2 ** o, base[1] * 2 ** o)
        out += amp * value_noise(shape, cells, seed + o); tot += amp; amp *= 0.5
    return out / tot

Y, X = np.mgrid[0:h, 0:w].astype(np.float64)
fy = Y / h

# centreline: limbs bend slightly away (top more, like GamePigeon)
xc = np.where(fy < 0.45,
              w * 0.42 + w * 0.12 * ((0.45 - fy) / 0.45) ** 2,
              w * 0.42 + w * 0.04 * ((fy - 0.45) / 0.55) ** 2)

# half-width profile (px at final scale -> * SS)
cy = [0, .08, .30, .37, .44, .495, .51, .70, .715, .78, .87, 1.0]
cw = [30, 35, 42, 46, 52, 57, 63, 63, 57, 50, 42, 33]
hw = np.interp(fy, cy, cw) * SS

u = (X - xc) / hw                       # -1..1 across the bow
inside = np.abs(u) <= 1.0
uc = np.clip(u, -1, 1)
nz = np.sqrt(np.maximum(0.0, 1 - uc * uc))

# light from upper-left, viewer straight on
L = np.array([-0.55, -0.25, 0.80]); L /= np.linalg.norm(L)
V = np.array([0.0, 0.0, 1.0])
Hh = (L + V); Hh /= np.linalg.norm(Hh)
ndl = np.maximum(0.0, uc * L[0] + nz * L[2])          # ny = 0 (vertical cylinder)
ndh = np.maximum(0.0, uc * Hh[0] + nz * Hh[2])

# --- wood albedo: long grain running along the bow ---
n1 = fbm((h, w), (10, 2), 11)
n2 = fbm((h, w), (300, 10), 23, octaves=3)
n3 = fbm((h, w), (60, 24), 31, octaves=2)
# straight, fine grain lines running along the bow, gently warped
stripes = np.sin(2 * np.pi * (u * 5.0 + n1 * 0.9))
grain = 0.5 + 0.5 * stripes
grain = 0.65 * grain + 0.35 * n3
dark = np.array([58, 26, 12], float)
mid = np.array([104, 52, 26], float)
light = np.array([132, 72, 38], float)
wood = dark + (mid - dark) * grain[..., None]
wood = wood + (light - mid) * (np.clip(grain - 0.7, 0, 1) * 2.0)[..., None]
wood *= (0.94 + 0.10 * n2)[..., None]
# darker laminate toward the tips
tip = np.clip(1 - np.minimum(fy, 1 - fy) / 0.10, 0, 1)
wood *= (1 - 0.35 * tip)[..., None]

# --- leather grip ---
grip = (fy >= 0.51) & (fy <= 0.70)
peb = fbm((h, w), (380, 30), 41, octaves=2)
leather = np.array([132, 66, 36], float) * (0.82 + 0.34 * peb)[..., None]
# wrap lines across the grip (slightly diagonal)
wrap = 0.5 + 0.5 * np.sin(2 * np.pi * ((fy - 0.51) * 260 + u * 0.6))
leather *= (0.9 + 0.12 * wrap)[..., None]
# stitched seam on the right side
seam = (np.abs(u - 0.62) < 0.05) & grip
dash = (np.sin(2 * np.pi * fy * 700) > 0.2)
leather[seam & dash] = [60, 34, 20]
# dark binding bands at both ends of the wrap
band = grip & ((fy < 0.517) | (fy > 0.693))
leather[band] *= 0.55

# --- metal ring at the top of the grip ---
ring = (fy > 0.497) & (fy < 0.51)
metal = np.array([196, 200, 206], float)

albedo = np.where(grip[..., None], leather, wood)
albedo = np.where(ring[..., None], metal[None, None, :] * np.ones_like(wood), albedo)

# --- shading: diffuse + glossy varnish highlight + edge darkening ---
diffuse = 0.30 + 0.80 * ndl
spec_exp = np.where(grip, 8.0, np.where(ring, 60.0, 48.0))
spec_amt = np.where(grip, 0.08, np.where(ring, 0.85, 0.30))
spec = (ndh ** spec_exp) * spec_amt
edge = 0.55 + 0.45 * nz ** 0.6
col = albedo * diffuse[..., None] * edge[..., None] + 255.0 * spec[..., None]
# soft secondary sheen streak (varnish) on the left-of-centre
sheen = np.exp(-((u + 0.38) / 0.10) ** 2) * (~grip) * 0.12
col += 255.0 * sheen[..., None]
col = np.clip(col, 0, 255)

alpha = inside.astype(float)
# rounded tips
# rounded caps at both ends
cap = np.minimum(fy, 1 - fy) * h
alpha = np.where(cap < hw, alpha * (np.sqrt(np.maximum(0, 1 - ((hw - cap) / hw) ** 2)) >= np.abs(uc)), alpha)

rgba = np.dstack([col, alpha[..., None] * 255.0]).astype(np.float32)
img = Image.fromarray(rgba.round().astype(np.uint8), 'RGBA')
# premultiplied-correct downsample: resize RGB*alpha and alpha separately
arr = np.array(img).astype(np.float32)
pm = arr.copy(); pm[..., :3] *= arr[..., 3:4] / 255.0
small = np.array(Image.fromarray(pm.astype(np.uint8), 'RGBA').resize((W, H), Image.LANCZOS)).astype(np.float32)
a = small[..., 3:4]
rgb = np.where(a > 0, small[..., :3] * 255.0 / np.maximum(a, 1), 0)
out = np.concatenate([np.clip(rgb, 0, 255), a], -1).round().astype(np.uint8)
Image.fromarray(out, 'RGBA').save(OUT, 'WEBP', quality=92, method=6, exact=True)
print('saved', OUT, out.shape)
