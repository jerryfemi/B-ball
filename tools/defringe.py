"""Remove white halos from cut-out PNG/WebP sprites (trees, bushes, props).

usage: python defringe.py input.webp output.webp [--bg 255,255,255] [--erode 2] [--tighten 0.12]

1. Un-blends the old background colour out of semi-transparent edge pixels
   (edge = a*F + (1-a)*BG  ->  F = (edge - (1-a)*BG) / a).
2. Shrinks the alpha edge by a couple of pixels to cut off opaque white rims.
3. Bleeds real edge colours outward into transparent pixels so bilinear
   scaling never pulls in white.
4. Saves WebP with exact=True so the bled colours are kept.
"""
import sys
import numpy as np
from PIL import Image

def main():
    args = sys.argv[1:]
    src, dst = args[0], args[1]
    bg = np.array([255, 255, 255], dtype=np.float32)
    tighten = 0.12
    erode = 2
    if '--bg' in args:
        bg = np.array([float(v) for v in args[args.index('--bg') + 1].split(',')], dtype=np.float32)
    if '--erode' in args:
        erode = int(args[args.index('--erode') + 1])
    if '--tighten' in args:
        tighten = float(args[args.index('--tighten') + 1])

    im = np.array(Image.open(src).convert('RGBA')).astype(np.float32)
    rgb, a = im[..., :3], im[..., 3:4] / 255.0

    # 1. un-blend the background from partially transparent pixels
    semi = (a > 0.02) & (a < 0.98)
    safe_a = np.maximum(a, 0.02)
    unblended = (rgb - (1.0 - a) * bg) / safe_a
    rgb = np.where(semi, np.clip(unblended, 0, 255), rgb)

    # 2. shrink the edge by `erode` px (removes opaque white rims the cut-out
    #    tool left behind), then tighten the soft edge
    a2 = a[..., 0]
    for _ in range(erode):
        m = a2.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.minimum(m, np.roll(a2, (dy, dx), (0, 1)))
        a2 = m
    a = np.clip((a2[..., None] - tighten) / (1.0 - tighten), 0.0, 1.0)

    # 3. bleed colours into transparent pixels (16 passes, 4-neighbour average)
    known = (a[..., 0] > 0.5)
    for _ in range(16):
        acc = np.zeros_like(rgb); cnt = np.zeros(known.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), (0, 1))
            acc += np.roll(rgb, (dy, dx), (0, 1)) * k[..., None]
            cnt += k
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow

    out = np.concatenate([rgb, a * 255.0], axis=-1).round().astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(dst, 'WEBP', quality=92, method=6, exact=True)

if __name__ == '__main__':
    main()
