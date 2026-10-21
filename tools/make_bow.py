"""Renders the foreground recurve bow for the archery game (archer's view).

The bow is modelled in 3D and drawn as seen from slightly to the side, so the
recurve profile is visible: limbs sweep back toward the archer and the tips
flick forward toward the target. Shaded as a varnished tube (diffuse + glossy
specular + edge falloff), two-tone wood (dark riser, warmer limbs), light
laminate stripes on the limbs, leather grip with stitching, a metal ring, an
arrow-shelf cut in the riser and bone-coloured tip overlays.

usage: python make_bow.py out.webp [--anchors]
Coordinates: image y down; bow plane depth z > 0 = toward the target (left on
screen); the grip sits at image height fraction GRIP_FY.
"""
import sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
W, H = 360, 2400
SS = 2
w, h = W * SS, H * SS

PHI = np.radians(20.0)          # view angle off the bow plane (shows the curve)
BOW_LEN = 1.70                  # metres tip to tip (arc, approx)
GRIP_FY = 0.52                  # grip centre as fraction of image height
M2PX = (h * 0.97) / BOW_LEN     # metres -> px (supersampled)
X_BASE = w * 0.34               # screen x of the grip back

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
        out += amp * value_noise(shape, (base[0] * 2 ** o, base[1] * 2 ** o), seed + o)
        tot += amp; amp *= 0.5
    return out / tot

# ---------------------------------------------------------------- geometry
rows = np.arange(h) + 0.5
yy = (rows - GRIP_FY * h) / M2PX          # metres from grip, + = down
t = np.abs(yy)                            # distance along bow from grip
half = BOW_LEN / 2

# depth profile z(t): riser almost straight, limbs sweep toward the archer
# (z negative), recurve flips the tips back toward the target.
# s runs 0..1 along each limb. The recurve term has zero slope where it
# starts, so the limb flows smoothly into the flicked-forward tip (no kink).
s = np.clip((t - 0.30) / (half - 0.30), 0, 1)
z = np.where(t < 0.30, -0.02 * (t / 0.30) ** 2,
             -0.02 - 0.24 * s ** 1.25 + 2.0 * np.maximum(0, s - 0.80) ** 2)
# upper limb a touch longer/stronger, like a real bow held in hand
z = np.where(yy < 0, z * 1.08, z)

# cross-section: width (side to side) and thickness (in the bow plane), metres
# arcade-chunky riser and grip (GamePigeon proportions), slim limbs
wid = np.interp(t, [0, .12, .20, .30, .40, .74, .82, half], [.052, .052, .047, .040, .038, .025, .017, .013])
thk = np.interp(t, [0, .12, .20, .30, .40, .74, .82, half], [.060, .060, .052, .030, .016, .010, .009, .008])
hw_m = 0.5 * np.sqrt((wid * np.cos(PHI)) ** 2 + (thk * np.sin(PHI)) ** 2)

xc = X_BASE - z * np.sin(PHI) * M2PX      # +z (toward target) goes left
hw = hw_m * M2PX
dxdy = np.gradient(xc)                    # px per px
theta = np.arctan(dxdy)                   # tangent lean

inside_rows = t <= half
Y, X = np.mgrid[0:h, 0:w].astype(np.float64)
XC = xc[:, None]; HW = hw[:, None]; TH = theta[:, None]
u = (X - XC) * np.cos(TH) / HW            # -1..1 across the limb
inside = (np.abs(u) <= 1.0) & inside_rows[:, None]

# rounded tips (cap the last few mm)
cap = (half - t)[:, None] * M2PX
inside &= ~((cap < HW) & (np.sqrt(np.maximum(0, 1 - ((HW - cap) / HW) ** 2)) < np.abs(u)))

uc = np.clip(u, -1, 1)
nz = np.sqrt(np.maximum(0.0, 1 - uc * uc))
# surface normal: across-limb direction is perpendicular to the tangent
nx = uc * np.cos(TH)
ny = -uc * np.sin(TH)
L = np.array([-0.55, -0.35, 0.76]); L /= np.linalg.norm(L)
Hh = L + np.array([0, 0, 1.0]); Hh /= np.linalg.norm(Hh)
ndl = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
ndh = np.clip(nx * Hh[0] + ny * Hh[1] + nz * Hh[2], 0, 1)

fy = (Y / h)
T = t[:, None]

# ---------------------------------------------------------------- materials
n_grain = fbm((h, w), (14, 3), 11)
n_fine = fbm((h, w), (420, 14), 23, octaves=3)
n_fig = fbm((h, w), (70, 20), 31, octaves=2)
grain = 0.5 + 0.5 * np.sin(2 * np.pi * (u * 4.0 + n_grain * 1.1))
grain = 0.6 * grain + 0.4 * n_fig

riser_dark = np.array([46, 22, 11.0]); riser_mid = np.array([92, 44, 22.0])
limb_dark = np.array([70, 36, 17.0]);  limb_mid = np.array([140, 78, 40.0])
is_riser = T < 0.30
blend = np.clip((T - 0.27) / 0.06, 0, 1)        # soft riser -> limb transition
dark = riser_dark * (1 - blend[..., None]) + limb_dark * blend[..., None]
mid = riser_mid * (1 - blend[..., None]) + limb_mid * blend[..., None]
albedo = dark + (mid - dark) * grain[..., None]
albedo *= (0.93 + 0.12 * n_fine)[..., None]

# light laminate stripes along the limbs (fibreglass edges)
lam = (T > 0.30) & (np.abs(np.abs(uc) - 0.72) < 0.07)
albedo = np.where(lam[..., None], np.array([214, 178, 128.0]) * (0.9 + 0.1 * n_fine)[..., None], albedo)

# bone tip overlays with a dark string groove
tipzone = T > half - 0.05
albedo = np.where(tipzone[..., None], np.array([222, 210, 182.0]) * (0.92 + 0.1 * n_fine)[..., None], albedo)
groove = (np.abs(T - (half - 0.035)) < 0.004)
albedo = np.where(groove[..., None], np.array([60, 45, 30.0]), albedo)

# leather grip (below the shelf), metal ring above it
yg = yy[:, None]
grip = (yg > -0.005) & (yg < 0.115)
peb = fbm((h, w), (520, 30), 41, octaves=2)
wrap = 0.5 + 0.5 * np.sin(2 * np.pi * (yg * 160 + u * 0.4))
leather = np.array([128, 60, 32.0]) * (0.80 + 0.34 * peb)[..., None] * (0.9 + 0.12 * wrap)[..., None]
seam = grip & (np.abs(uc - 0.58) < 0.05) & (np.sin(2 * np.pi * yg * 260) > 0.2)
leather = np.where(seam[..., None], np.array([58, 30, 16.0]), leather)
bind = grip & ((yg < 0.006) | (yg > 0.108))
leather = np.where(bind[..., None], leather * 0.5, leather)
albedo = np.where(grip[..., None], leather, albedo)
ring = (yg > -0.016) & (yg <= -0.005)
albedo = np.where(ring[..., None], np.array([198, 202, 208.0]), albedo)

# arrow shelf: a notch cut into the target side of the riser above the ring
# soft-edged recess: deepest at the target-side edge, rounded top
sy0, sy1 = -0.068, -0.018
ys_ = np.clip((yg - sy0) / (sy1 - sy0), 0, 1)
notch_edge = -0.30 - 0.25 * (1 - np.sin(np.pi * ys_) ** 0.5)     # rounded profile
in_band = (yg > sy0) & (yg < sy1)
shelf_amt = in_band * np.clip((notch_edge - uc) / 0.12, 0, 1)
shelf_floor = (yg > -0.021) & (yg < -0.016) & (uc < -0.32)

# ---------------------------------------------------------------- shading
spec_exp = np.where(grip, 8.0, np.where(ring, 60.0, np.where(tipzone, 30.0, 52.0)))
spec_amt = np.where(grip, 0.07, np.where(ring, 0.9, np.where(tipzone, 0.25, 0.34)))
diffuse = 0.24 + 0.86 * ndl
edge = 0.45 + 0.55 * nz ** 0.55              # strong falloff = reads as round
col = albedo * diffuse[..., None] * edge[..., None]
col += 255.0 * ((ndh ** spec_exp) * spec_amt)[..., None]
# long varnish sheen streak following the curve
sheen = np.exp(-((uc + 0.42) / 0.09) ** 2) * (~grip) * (~tipzone) * 0.16
col += 255.0 * sheen[..., None]
# shelf: recessed and shadowed, with a lit floor
col = col * (1 - 0.55 * shelf_amt)[..., None]
col = np.where(shelf_floor[..., None], np.array([138, 96, 60.0]) * (0.9 + 0.2 * ndl)[..., None], col)
col = np.clip(col, 0, 255)

alpha = inside.astype(float)

# ---------------------------------------------------------------- string
# Straight from groove to groove on the archer side; drawn under the limbs.
gt = half - 0.035
r_top = int(np.argmin(np.abs(yy + gt)))
r_bot = int(np.argmin(np.abs(yy - gt)))
x0, y0 = xc[r_top], float(r_top)
x1, y1 = xc[r_bot], float(r_bot)
ldx, ldy = x1 - x0, y1 - y0
llen = np.hypot(ldx, ldy)
dist = np.abs((X - x0) * ldy - (Y - y0) * ldx) / llen
along = ((X - x0) * ldx + (Y - y0) * ldy) / (llen * llen)
s_half = 1.3 * SS
s_cov = np.clip(s_half + 0.5 - dist, 0, 1) * ((along >= 0) & (along <= 1))
s_col = np.array([236, 230, 214.0]) * (0.82 + 0.18 * np.clip(1 - dist / s_half, 0, 1))[..., None]
under = s_cov * (1 - alpha)
col = col * alpha[..., None] + s_col * under[..., None]
alpha = alpha + under

rgba = np.dstack([col, alpha[..., None] * 255.0])

# premultiplied downsample
pm = rgba.copy(); pm[..., :3] *= rgba[..., 3:4] / 255.0
small = np.array(Image.fromarray(pm.round().astype(np.uint8), 'RGBA').resize((W, H), Image.LANCZOS)).astype(np.float32)
a = small[..., 3:4]
rgb = np.where(a > 0, small[..., :3] * 255.0 / np.maximum(a, 1), 0)
out = np.concatenate([np.clip(rgb, 0, 255), a], -1).round().astype(np.uint8)
Image.fromarray(out, 'RGBA').save(OUT, 'WEBP', quality=93, method=6, exact=True)
print('saved', OUT, out.shape)

if '--anchors' in sys.argv:
    gi = int(GRIP_FY * h + 0.055 * M2PX)          # grip centre row
    si = int(GRIP_FY * h - 0.022 * M2PX)          # shelf floor row
    print('grip  (fx, fy) =', round(xc[gi] / w, 3), round(gi / h, 3))
    print('shelf (fx, fy) =', round((xc[si] - hw[si] * 0.9) / w, 3), round(si / h, 3))
