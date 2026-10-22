"""Synthesises the archery sound effects (no samples, no licences).

usage: python tools/make_archery_sfx.py assets/archery
Writes sfx_draw / sfx_click / sfx_release / sfx_thunk / sfx_ding / sfx_thud .wav
(mono, 16-bit, 32 kHz). Deterministic: same files every run.
"""
import sys, wave
import numpy as np

SR = 32000
rng = np.random.default_rng(7)
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'


def t(sec):
    return np.arange(int(SR * sec)) / SR


def lp(x, cut):
    """One-pole low-pass, run twice (12 dB/oct)."""
    a = np.exp(-2 * np.pi * cut / SR)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def hp(x, cut):
    return x - lp(x, cut)


def bp(x, f, q):
    """Two-pole resonator (band-pass) at f Hz."""
    r = np.exp(-np.pi * f / (q * SR))
    c = 2 * r * np.cos(2 * np.pi * f / SR)
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    g = 1 - r
    for i, v in enumerate(x):
        y0 = g * v + c * y1 - r * r * y2
        y[i] = y0
        y2 = y1
        y1 = y0
    return y


def env(n, attack, decay):
    tt = np.arange(n) / SR
    a = np.clip(tt / max(attack, 1e-4), 0, 1)
    return a * np.exp(-tt / decay)


def save(name, x, peak=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    k = int(SR * 0.008)
    x[-k:] *= np.linspace(1, 0, k)
    d = (x * 32767).astype('<i2')
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(d.tobytes())
    print('wrote', name, f'{len(x) / SR:.2f}s')


# --- draw: wood/limb creak while pulling back (stick-slip grains) ----------
tt = t(0.55)
n = len(tt)
x = np.zeros(n)
pos = 0.0
while pos < 0.5:
    i = int(pos * SR)
    L = min(int(SR * 0.012), n - i)
    burst = rng.standard_normal(L) * np.exp(-np.arange(L) / (SR * 0.0025))
    x[i:i + L] += burst * (0.5 + 0.5 * rng.random())
    pos += 0.012 + 0.03 * rng.random() * (1 - pos)   # grains speed up
x = bp(x, 420, 6) * 0.8 + bp(x, 1150, 9) * 0.5 + bp(x, 2300, 12) * 0.2
x += 0.03 * np.sin(2 * np.pi * (90 + 60 * tt) * tt) * np.clip(tt / 0.3, 0, 1)
x *= np.clip(tt / 0.04, 0, 1) * np.clip((0.55 - tt) / 0.1, 0, 1)
save('sfx_draw', x, 0.5)

# --- click: arrow settling at full draw -----------------------------------
n = int(SR * 0.06)
x = rng.standard_normal(n) * env(n, 0.0005, 0.006)
x = bp(x, 2600, 8) + 0.5 * bp(x, 5200, 10)
save('sfx_click', x, 0.45)

# --- release: string slap + low twang + airy whoosh -----------------------
tt = t(0.6)
n = len(tt)
f0 = 98 * (1 + 0.35 * np.exp(-tt / 0.015))        # pitch settles after release
ph = 2 * np.pi * np.cumsum(f0) / SR
twang = sum((1 / k ** 1.3) * np.sin(k * ph) * np.exp(-tt * (9 + 5 * k)) for k in range(1, 9))
slap = rng.standard_normal(n) * env(n, 0.0003, 0.008)
slap = bp(slap, 1800, 2) + 0.6 * hp(slap, 3000)
whoosh = bp(rng.standard_normal(n), 900, 1.2) * np.exp(-((tt - 0.09) / 0.07) ** 2)
save('sfx_release', 0.9 * twang + 0.7 * slap + 0.35 * whoosh, 0.9)

# --- thunk: arrow into the target boss + shaft quiver rattle ---------------
tt = t(0.5)
n = len(tt)
body = np.sin(2 * np.pi * (70 + 80 * np.exp(-tt / 0.02)) * tt) * np.exp(-tt / 0.06)
crunch = lp(rng.standard_normal(n), 2200) * env(n, 0.0005, 0.025)
quiver = np.sin(2 * np.pi * 185 * tt) * np.sin(2 * np.pi * 18 * tt) ** 2 * np.exp(-tt / 0.12)
save('sfx_thunk', body + 0.8 * crunch + 0.18 * quiver, 0.95)

# --- ding: bright bell for a 10 / X (inharmonic partials) ------------------
tt = t(1.4)
f = 1318.5
partials = [(1.0, 1.0, 1.1), (2.76, 0.45, 0.6), (5.40, 0.25, 0.35), (8.93, 0.12, 0.2)]
x = sum(a * np.sin(2 * np.pi * f * m * tt) * np.exp(-tt / d) for m, a, d in partials)
save('sfx_ding', x * np.clip(tt / 0.002, 0, 1), 0.6)

# --- thud: arrow into the grass (miss) ------------------------------------
tt = t(0.35)
n = len(tt)
body = np.sin(2 * np.pi * (48 + 40 * np.exp(-tt / 0.015)) * tt) * np.exp(-tt / 0.05)
dirt = lp(rng.standard_normal(n), 900) * env(n, 0.001, 0.04)
save('sfx_thud', body + 0.7 * dirt, 0.8)
