"""Every sound effect and ambience loop of Space Mission Designer, synthesized with numpy (no samples, no AI).
    python tools/audio/make_sounds.py [name ...]        no names = all of them
Physical sounds = transient (click or crack) + body (150 Hz-2 kHz, what a laptop plays) + weight (a falling
sine through tanh, so its harmonics carry it) + a baked tail. UI = short, bright, tonal, never harsh.
Mission control = band-passed beeps with static. Tonal sounds use D F G A C E (the music is in D minor).
Each sound is levelled to a loudness class (see SOUNDS), not to peak. Check the result with check.py."""
import sys
import numpy as np
from synth import *

D5, F5, A5, C6, D6, E6, F6, A6 = 587.33, 698.46, 880.0, 1046.5, 1174.66, 1318.51, 1396.91, 1760.0

def z(sec): return np.zeros(n_(sec))
def u(x): return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)
def drive(x, rms=0.25, d=1.6): return sat(u(x) * rms, d)
def tick(t, fr, tau, g=1.0): return sine(fr, t) * dec(t, tau) * g
def snip(t, g=0.4, hp=3000, tau=0.002): return f(nz(len(t)), "hp", hp) * dec(t, tau) * g
def thud(t, f0=170.0, f1=65.0, ptau=0.05, atau=0.09, d=3.0): return sat(sweep(t, f0, f1, ptau) * dec(t, atau), d)
def clack(t, lo=700, hi=3000, tau=0.02): return bp(nz(len(t)), lo, hi) * dec(t, tau)
def knock(t, lo=250, hi=1100, tau=0.035): return bp(nz(len(t)), lo, hi) * dec(t, tau)  # the body a laptop can play
def radio(x): return bp(x, 450, 3400)
def beep(fr, sec, h3=0.15):
    t = t_(sec)
    return fade(sine(fr, t) + h3 * sine(3 * fr, t), 0.005, 0.006)
def bell(fr, sec, tau=0.12):
    """Soft bell pluck: partials 1, 2, 3 and one inharmonic, higher ones die faster, tiny noise tick."""
    t = t_(sec)
    x = (sine(fr, t) * dec(t, tau) + 0.35 * sine(2 * fr, t) * dec(t, tau * 0.6)
         + 0.15 * sine(3 * fr, t) * dec(t, tau * 0.4) + 0.06 * sine(4.2 * fr, t) * dec(t, tau * 0.3))
    return x * np.minimum(t / 0.002, 1.0) + snip(t, 0.12, 3000, 0.0015)
def sawp(ph, k_top):
    """Saw from a phase array (so loops can be made exactly periodic)."""
    return sum(np.sin(k * ph) / k for k in range(1, k_top + 1)) * (2 / np.pi)
def slow(t, L, ms=(1, 2, 3, 5)):
    """Slow 0..1 curve made of whole cycles over the loop: gusts and swells that repeat without a seam."""
    y = sum(sine(m / L, t, uni(0, TAU)) / np.sqrt(m) for m in ms)
    return (y - y.min()) / (y.max() - y.min())

# ------------------------------------------------------------------ UI: crisp and friendly
def click(take=0):
    k = (1.0, 0.94, 1.07)[take]; t = t_(0.09)
    x = snip(t, 0.7, 2500, 0.003) + tick(t, 1900 * k, 0.010, 0.8) + tick(t, 760 * k, 0.022, 0.8) + tick(t, 210 * k, 0.03, 0.5)
    return sat(x * 1.3, 2.0)

def ui_hover(take=0):
    k = (1.0, 0.93)[take]; t = t_(0.04)
    return tick(t, 2400 * k, 0.006, 0.7) + snip(t, 0.2, 4000)

def ui_tab(take=0):
    x = z(0.14); t = t_(0.06)
    put(x, tick(t, 1250, 0.008) + snip(t), 0.0)
    put(x, tick(t, 1870, 0.009) + snip(t), 0.045)
    return x + bp(nz(len(x)), 2000, 6000) * np.hanning(len(x)) * 0.05

def _swish(up):
    w = np.hanning(n_(0.18)); r = np.linspace(0, 1, len(w)) if up else np.linspace(1, 0, len(w))
    return (bp(nz(len(w)), 500, 1600) * (1 - r) + bp(nz(len(w)), 1800, 5000) * r) * w
def ui_open(take=0):
    x = z(0.32); put(x, _swish(True), 0.0, 0.5)
    put(x, bell(D5, 0.2, 0.05), 0.02, 0.5); put(x, bell(A5, 0.22, 0.06), 0.09, 0.5)
    return x
def ui_close(take=0):
    x = z(0.30); put(x, _swish(False), 0.0, 0.5)
    put(x, bell(A5, 0.2, 0.05), 0.02, 0.5); put(x, bell(D5, 0.2, 0.06), 0.09, 0.5)
    return x

def ui_deny(take=0):
    x = z(0.22); t = t_(0.1)
    d = sat(sine(220, t) * dec(t, 0.03), 3) * 0.6 + sine(440, t) * dec(t, 0.02) * 0.5 + f(nz(len(t)), "lp", 1500) * dec(t, 0.012) * 0.8
    put(x, d, 0.0); put(x, d, 0.085, 0.85)
    return x

def confirm(take=0):
    x = z(0.5); put(x, bell(D5, 0.4, 0.11), 0.0); put(x, bell(A5, 0.38, 0.13), 0.11)
    return reverb(x, 0.35, 0.18)

def error(take=0):
    def stab(a, b):
        t = t_(0.1)
        return fade(f(saw(a, t, 3000) + saw(b, t, 3000), "lp", 1800), 0.004, 0.02)
    x = z(0.26); put(x, stab(440.0, 415.3), 0.0); put(x, stab(440.0, 415.3), 0.13)
    return reverb(x, 0.2, 0.1)

def coin(take=0):
    x = z(0.85)
    for i, fr in enumerate((A5, C6, D6, E6)):  # credit ticks counting up
        t = t_(0.035)
        put(x, fade(sine(fr, t) + 0.2 * sine(2 * fr, t), 0.002, 0.012), 0.05 * i, 0.6)
    t = t_(0.6)
    put(x, sine(E6, t) * dec(t, 0.16) + 0.5 * sine(2 * E6, t) * dec(t, 0.11) + 0.25 * sine(3 * E6, t) * dec(t, 0.07), 0.21)
    return reverb(x, 0.3, 0.15)

# ------------------------------------------------------------------ mission control: band-passed, Quindar-like
def blip(take=0):
    x = z(0.11); put(x, beep((A6, 1567.98)[take], 0.055, 0.1), 0.0)
    return radio(x + bp(nz(len(x)), 600, 3000) * dec(t_(0.11), 0.03) * 0.12)

def radio_blip(take=0):
    """Apollo Quindar tones: 2525 Hz opens the channel, 2475 Hz closes it; a breath of static after."""
    x = z(0.24); put(x, beep((2525.0, 2475.0)[take], 0.09, 0.0), 0.0)
    t = t_(0.14); put(x, bp(nz(len(t)), 300, 3000) * env(t, 0.005, 0.03), 0.085, 0.3)
    return radio(x)

def poll_blip(take=0):
    x = z(0.13); t = t_(0.015)
    put(x, bp(nz(len(t)), 600, 3000) * 0.3, 0.0)          # squelch opens
    put(x, beep(E6, 0.07, 0.1), 0.012)
    return radio(x + bp(nz(len(x)), 600, 3000) * 0.03)

def poll_nogo(take=0):
    x = z(0.3)
    for i, fr in enumerate((659.26, 523.25)):
        t = t_(0.1); put(x, fade(f(saw(fr, t, 2500), "lp", 1500), 0.005, 0.01), 0.12 * i)
    return radio(x + bp(nz(len(x)), 600, 3000) * 0.05)

def _thock(g=1.0):
    t = t_(0.08)
    return (tick(t, 420, 0.012) + clack(t, 700, 2500, 0.006) * 0.5) * g
def station_go(take=0):
    x = z(0.26); put(x, beep(A5, 0.06, 0.1), 0.03); put(x, beep(D6, 0.1, 0.1), 0.10)
    x = radio(x); put(x, _thock(1.2), 0.0)
    return reverb(x, 0.2, 0.1)
def station_nogo(take=0):
    x = z(0.26); t = t_(0.16)
    put(x, fade(f(saw(220.0, t, 2500) + saw(233.08, t, 2500), "lp", 1200), 0.005, 0.02), 0.03)
    x = radio(x); put(x, _thock(0.5), 0.0)
    return reverb(x, 0.2, 0.1)

def all_go(take=0):
    x = z(1.3)
    for i, fr in enumerate((D5, F5, A5, D6)):
        put(x, bell(fr, 0.5, 0.10), 0.08 * i, 0.8)
    for fr in (D5, A5, D6, A6):
        put(x, bell(fr, 0.9, 0.28), 0.34, 0.5)
    t = t_(0.36); put(x, fade(bp(nz(len(t)), 800, 5000) * (t / 0.36) ** 2, 0.01, 0.02), 0.0, 0.25)
    put(x, thud(t_(0.3), 150, 70, 0.04, 0.08), 0.34, 0.6)
    return reverb(x, 0.6, 0.22)

def countdown_beep(take=0):
    x = z(0.15); put(x, beep(A5, 0.13, 0.15), 0.0)
    return reverb(radio(x), 0.25, 0.15)

def warn_alt(take=0):
    x = z(0.08); put(x, beep(C6, 0.045, 0.2), 0.0)
    return radio(x)

def battery_low(take=0):
    x = z(0.4)
    for i, fr in enumerate((A5, 659.26)):
        t = t_(0.11); put(x, fade(sine(fr, t) + 0.25 * sine(3 * fr, t) + 0.1 * sine(5 * fr, t), 0.005, 0.02), 0.16 * i)
    return radio(x)

def alarm(take=0):
    """Klaxon: three two-tone whoops (D5 then A4), low-passed saw with tremolo, a slap off the far wall."""
    def whoop():
        t = t_(0.22); fr = np.where(t < 0.11, D5, 440.0)
        s = f(saw(fr, t, 4000), "lp", 2500) * (0.7 + 0.3 * sine(8, t)) + bp(nz(len(t)), 1000, 3000) * 0.1
        return fade(s, 0.006, 0.02)
    x = z(1.0)
    for i in range(3):
        put(x, whoop(), 0.28 * i)
    y = x.copy(); put(y, x, 0.09, 0.3)
    return y

# ------------------------------------------------------------------ builder: weighty hardware
def part_pick(take=0):
    k = (1.0, 1.06)[take]; x = z(0.2); t = t_(0.2); ts = t_(0.09)
    x += modal(t, [(1800 * k, 0.5, 0.02), (3100 * k, 0.3, 0.012)]) + snip(t) + sweep(t, 220, 130, 0.03) * dec(t, 0.03) * 0.5
    put(x, f(saw(np.linspace(300, 520, len(ts)) * k, ts, 3000), "lp", 1400) * np.hanning(len(ts)), 0.015, 0.35)
    return x

def part_snap(take=0):
    """Mechanical clunk: contact click + body thud + two latch teeth + a short metal ring + a servo chirp."""
    k = (1.0, 0.95, 1.05)[take]; lat = (0.045, 0.052, 0.04)[take]; t = t_(0.45)
    x = snip(t, 0.9, 2000, 0.004) + thud(t, 180 * k, 85, 0.05, 0.06) * 0.45 + knock(t) * 1.2 + clack(t, 800, 3000, 0.018) * 1.2
    put(x, clack(t_(0.1), 1000, 3500, 0.012), lat, 0.6)
    x += modal(t, [(740 * k, .30, .12), (1180 * k, .22, .10), (1930 * k, .16, .08), (2890 * k, .10, .06), (4100 * k, .06, .04)]) * 1.3
    ts = t_(0.07)
    put(x, f(saw(np.linspace(900, 1500, len(ts)) * k, ts, 6000), "lp", 3000) * np.hanning(len(ts)), 0.09, 0.12)
    return reverb(sat(x * 0.6, 1.5), 0.18, 0.12)

def part_remove(take=0):
    k = (1.0, 0.93)[take]; x = z(0.3); t = t_(0.3); ts = t_(0.09)
    x += snip(t, 0.6) + clack(t, 900, 3200, 0.008) * 0.8 + modal(t, [(900 * k, 0.2, 0.05), (1500 * k, 0.12, 0.04)])
    put(x, f(saw(np.linspace(600, 300, len(ts)) * k, ts, 3000), "lp", 1500) * np.hanning(len(ts)), 0.01, 0.3)
    put(x, sweep(t_(0.15), 420 * k, 230, 0.03) * dec(t_(0.15), 0.03), 0.03, 0.5)
    return reverb(x, 0.15, 0.1)

def part_deny(take=0):
    x = z(0.26); t = t_(0.12)
    kn = modal(t, [(310, 0.6, 0.05), (480, 0.4, 0.04), (1250, 0.15, 0.02)]) + f(nz(len(t)), "lp", 1200) * dec(t, 0.01) * 0.8 + thud(t, 150, 90, 0.03, 0.04) * 0.25
    put(x, kn, 0.0); put(x, kn, 0.09, 0.8)
    return reverb(x, 0.15, 0.08)

# ------------------------------------------------------------------ engines
def _roar(sec, bright=1.0):
    """Rocket plume layers: (rumble, everything above it). Body carries it on small speakers; crackle = the tearing."""
    n = n_(sec)
    rumble = u(bp(brown(n), 60, 180)) * (0.75 + 0.25 * lfo(n, 0.5, 4))
    body = u(bp(nz(n), 180, 1400)) * (0.6 + 0.4 * lfo(n, 2, 9))
    grit = u(bp(nz(n), 700, 2600)) * (0.5 + 0.5 * lfo(n, 6, 20))
    return rumble, body + 0.5 * grit + 0.6 * bright * u(crackle(n, 28))

def thrust(take=0):
    L = 3.5; n = n_(L); t = t_(L)
    rumble, rest = _roar(L + 0.5)
    tone = u(sat(0.5 * sine(70, t) + 0.4 * sine(104, t, 1.0), 4))
    return drive(seam(rumble, n) * 0.8 + seam(rest, n) + tone * 0.4, 0.25, 1.6)

def ignition(take=0):
    sec = 1.3; n = n_(sec); t = t_(sec)
    crack = f(nz(n), "hp", 1800) * dec(t, 0.03) * 1.2; crack[:n_(0.001)] += 2.0
    rumble, rest = _roar(sec, 1.4)
    burst = u(rumble * 0.4 + rest) * (0.3 + 0.7 * env(t, 0.04, 0.45))
    return fade(sat((crack + thud(t, 160, 70, 0.12, 0.3) * 0.6 + burst * 0.5) * 0.6, 1.8), 0.0005, 0.4)

def launch(take=0):
    """Deep crackling roar: ignition crack, builds for 1.4 s, holds to 4.5 s, then recedes and darkens."""
    sec = 8.0; n = n_(sec); t = t_(sec)
    up = np.minimum(t / 1.4, 1.0) ** 2
    gone = np.where(t < 4.5, 1.0, np.exp(-(t - 4.5) / 1.4))
    rumble, rest = _roar(sec, 1.3)
    tone = u(sat(0.5 * sine(70, t) + 0.4 * sine(104, t, 1.0), 4))
    full = rumble * 0.85 + rest + u(bp(nz(n), 300, 6000) * spiky(n, 40, 3)) * 0.5 + tone * 0.4
    k = np.clip(gone * 1.3 - 0.3, 0, 1)
    mix = (full * k + f(full, "lp", 700) * (1 - k) * 1.5) * (0.06 + 0.94 * up) * gone
    mix = mix / np.sqrt(np.mean(mix[n_(2.0):n_(4.0)] ** 2)) * 0.3
    crack = f(nz(n), "hp", 1800) * dec(t, 0.03); crack[:n_(0.001)] += 1.5
    return fade(sat(mix + crack * 0.3 + thud(t, 160, 70, 0.12, 0.3) * 0.25, 1.8), 0.0005, 0.6)

def rcs(take=0):
    sec = (0.15, 0.13, 0.17)[take]; n = n_(sec); t = t_(sec); hold = sec - 0.09
    e = np.minimum(t / 0.004, 1.0) * np.where(t < hold, 1.0, np.exp(-(t - hold) / 0.03))
    return bp(nz(n), 1000, 5000) * e + f(nz(n), "hp", 6000) * dec(t, 0.01) * 0.5 + bp(nz(n), 250, 600) * dec(t, 0.025) * 0.7

def stage_sep(take=0):
    t = t_(0.9); x = thud(t, 170, 80) * 0.45 + knock(t, 250, 1100, 0.04) * 1.2 + clack(t) * 1.2 + modal(t, [(610, .25, .18), (1490, .18, .14), (2380, .12, .10), (3620, .07, .08)])
    put(x, f(nz(n_(0.1)), "hp", 2500) * dec(t_(0.1), 0.008), 0.03, 1.2)          # pyro pop
    tg = t_(0.8); put(x, bp(nz(len(tg)), 900, 5000) * env(tg, 0.02, 0.22), 0.05, 0.7)  # gas puff
    return reverb(sat(x * 0.6, 1.5), 0.3, 0.15)

def explosion(take=0):
    """Sub boom + crackle + debris tail."""
    sec = 3.0; n = n_(sec); t = t_(sec)
    crack = f(nz(n), "hp", 2000) * dec(t, 0.014); crack[:n_(0.001)] += 2.0
    punch = thud(t, 200, 62, 0.10, 0.28, 4.0) * 0.4
    b = nz(n)
    body = (f(b, "lp", 4500) * dec(t, 0.10) + f(b, "lp", 1300) * dec(t, 0.35) * 1.3 + bp(b, 70, 420) * dec(t, 0.8) * 1.6) * 1.1
    roll = u(bp(nz(n), 90, 320)) * lfo(n, 3, 12) * dec(t, 0.9) * 0.25
    debris = crackle(n, 18) * np.minimum(t / 0.15, 1.0) * dec(t, 0.7) * 4.0
    x = (crack + punch + body + roll + debris) * np.clip((sec - t) / 1.0, 0, 1) ** 1.5  # tail dies out, never cut
    return reverb(sat(x / np.abs(x).max() * 1.0, 2.2), 0.9, 0.2, 150, 3500)

# ------------------------------------------------------------------ landing, surface, drone
def land(take=0):
    """Touchdown: gear clank + body thud (and the other leg) + dust hiss + a late settle creak."""
    t = t_(1.2); n = len(t)
    x = clack(t, 800, 3000, 0.025) + modal(t, [(430, .35, .12), (970, .25, .10), (1650, .15, .08)])
    x = x * 1.4 + thud(t, 170, 70, 0.06, 0.16, 4.0) * 0.6 + knock(t, 200, 1200, 0.08) * 1.6
    put(x, thud(t_(0.4), 140, 75, 0.05, 0.1) * 0.3 + knock(t_(0.4), 250, 1200, 0.04) * 0.8 + clack(t_(0.4), 700, 2500, 0.02) * 0.6, 0.12)
    x += bp(nz(n), 2000, 7000) * env(t, 0.08, 0.3) * 0.8
    tc = t_(0.13); put(x, sweep(tc, 310, 240, 0.05) * (0.5 + 0.5 * sine(35, tc)) * np.hanning(len(tc)), 0.5, 0.12)
    return reverb(sat(x * 0.6, 1.8), 0.4, 0.15, 200, 4000)

def success(take=0):
    """Rising F major plucks (the music's relative major) over a soft swell."""
    x = z(1.2)
    for i, fr in enumerate((F5, A5, C6, F6)):
        put(x, bell(fr, 0.9, 0.12 if i < 3 else 0.3), 0.09 * i, 0.8)
    t = t_(1.0)
    put(x, sum(sine(fr, t) for fr in (349.23, 440.0, 523.25)) * env(t, 0.25, 0.3), 0.0, 0.12)
    return reverb(x, 0.7, 0.25)

def rover_loop(take=0):
    """Electric rover: motor hum + gear whine + gear chatter + wheels crunching regolith. Exactly periodic."""
    L = 2.4; n = n_(L); t = t_(L)
    ph = TAU * (230 / L) * t + 0.35 * np.sin(TAU * (12 / L) * t)
    motor = cf(sawp(ph, 12), "lp", 1200)
    whine = np.sin(7.5 * ph)
    chatter = seam(bp(nz(n + n_(0.3)), 700, 2500), n) * (0.55 + 0.45 * np.tanh(3 * sine(60 / L, t)))
    crunch = seam(bp(nz(n + n_(0.3)), 400, 3500) * spiky(n + n_(0.3), 14), n)
    return drive(u(motor) * 0.8 + whine * 0.1 + u(chatter) * 0.45 + u(crunch) * 0.9, 0.25, 1.5)

def drill(take=0):
    """Rock drill: motor with wobble + bit chatter chopped at 38 Hz + casing rattle + grit. Exactly periodic."""
    L = 2.0; n = n_(L); t = t_(L)
    ph = TAU * 140 * t + (0.03 * 140 / 11) * np.sin(TAU * 11 * t)
    motor = cf(sawp(ph, 12) + 0.5 * sawp(2 * ph, 6), "lp", 1800)
    chatter = seam(bp(nz(n + n_(0.3)), 900, 4500), n) * (0.5 + 0.5 * sine(38, t)) ** 2
    rattle = sat(sine(80, t) * (1 + 0.5 * sine(19, t)), 3)
    grit = seam(crackle(n + n_(0.3), 60, 2000, 7000), n)
    return drive(u(motor) * 0.9 + u(chatter) * 0.8 + u(rattle) * 0.3 + u(grit) * 0.5, 0.25, 1.6)

def drill_hit(take=0):
    """The sample comes free: rock crack, crumble, two pebbles."""
    t = t_(0.5); n = len(t)
    x = snip(t, 1.2, 1500, 0.006) + thud(t, 150, 80, 0.05, 0.06) * 0.3 + knock(t, 300, 1500, 0.03)
    x += f(f(nz(n), "lp", 2500), "hp", 300) * spiky(n, 30) * dec(t, 0.14) * 6.0
    for at, fr in ((0.14, 1300), (0.23, 1700)):
        tp = t_(0.05); put(x, tick(tp, fr, 0.006) + snip(tp, 0.5), at, 0.4)
    return reverb(sat(x * 0.6, 1.5), 0.2, 0.12)

def pickup(take=0):
    """Glass pluck E6 sliding to A6."""
    t = t_(0.4); ph = TAU * np.cumsum(A6 + (E6 - A6) * np.exp(-t / 0.015)) / SR
    x = (np.sin(ph) + 0.3 * np.sin(2 * ph) * dec(t, 0.08) + 0.12 * np.sin(3 * ph) * dec(t, 0.05)) * dec(t, 0.11) + snip(t, 0.3)
    return reverb(x, 0.25, 0.18)

def jump(take=0):
    """Rover hop: suspension thunk + motor whirr-up."""
    t = t_(0.25); n = len(t)
    whirr = f(saw(90 + 130 * np.minimum(t / 0.15, 1.0), t, 2500), "lp", 900) * env(t, 0.02, 0.09)
    return whirr * 1.2 + knock(t, 200, 900, 0.03) * 1.2 + thud(t, 150, 85, 0.03, 0.05) * 0.3 + clack(t, 900, 2500, 0.008) * 0.4

def hit(take=0):
    """Drone strikes ice or rock: metal clang + crunch + thump."""
    k = (1.0, 0.92, 1.09)[take]; t = t_(0.5)
    x = modal(t, [(520 * k, .5, .16), (1340 * k, .35, .12), (2210 * k, .22, .09), (3470 * k, .12, .06)]) * 1.3
    x += clack(t, 600, 4000, 0.025) * 1.5 + knock(t) + thud(t, 200, 80, 0.05, 0.07) * 0.45 + snip(t, 0.8)
    return reverb(sat(x * 0.6, 1.8), 0.25, 0.12)

def dock(take=0):
    """Docking clamp: heavy double latch + long ring + pressure hiss + two-note bell (D5, A5)."""
    t = t_(1.0); x = thud(t, 160, 75, 0.06, 0.12, 4.0) * 0.5 + knock(t, 220, 1100, 0.05) * 1.3 + clack(t, 600, 2800, 0.02) * 1.3
    put(x, clack(t_(0.2), 800, 3200, 0.015) * 1.3 + knock(t_(0.2)) + thud(t_(0.2), 130, 80, 0.04, 0.06) * 0.25, 0.09, 0.8)
    x += modal(t, [(330, .25, .30), (790, .2, .25), (1260, .14, .20), (2100, .08, .12)]) * 1.3
    th = t_(0.6); put(x, bp(nz(len(th)), 2000, 6000) * env(th, 0.03, 0.12), 0.12, 0.25)
    put(x, bell(D5, 0.5, 0.14), 0.30, 0.5); put(x, bell(A5, 0.55, 0.2), 0.42, 0.5)
    return reverb(sat(x * 0.6, 1.5), 0.5, 0.18)

def ice_ping(take=0):
    """Crystal ping: beating high partials (E7, A7 ...) + a 6-9 kHz shimmer."""
    t = t_(0.6); n = len(t)
    x = modal(t, [(2637.0, .5, .22), (2649.0, .3, .22), (3520.0, .35, .16), (4228.0, .2, .12), (5290.0, .12, .08)])
    x += bp(nz(n), 6000, 9000) * dec(t, 0.05) * 0.5 + snip(t, 0.3, 5000)
    for at in (0.13, 0.21, 0.34):
        tp = t_(0.03); put(x, tick(tp, uni(5000, 7500), 0.004), at, 0.12)
    return reverb(x, 0.4, 0.2, 800, 8000)

def arrive(take=0):
    """Arrival: an open fifth swells up (D, A), two bells answer, a soft boom under them."""
    sec = 1.5; t = t_(sec)
    pad = f(sum(saw(fr * d, t, 4000) for fr in (146.83, 220.0, 293.66) for d in (0.996, 1.004)), "lp", 1800)
    x = pad * np.minimum(t / 0.35, 1.0) ** 2 * np.exp(-np.maximum(t - 0.35, 0) / 0.45) * 0.25
    put(x, bell(A5, 0.7, 0.2), 0.35, 0.6); put(x, bell(D6, 0.9, 0.3), 0.50, 0.6)
    put(x, thud(t_(0.6), 110, 65, 0.06, 0.2, 2.5), 0.35, 0.5)
    return reverb(x, 0.7, 0.25)

# ------------------------------------------------------------------ ambience beds (8 s loops, quiet)
AL = 8.0
def _ln(lo, hi, order=2):
    """Loop of band-passed noise."""
    n = n_(AL)
    return u(seam(bp(nz(n + SR), lo, hi, order), n))
def _events(evs, rt, wet):
    x = z(AL)
    for at, sig, g in evs:
        put(x, sig, at, g)
    return creverb(x, rt, wet)

def amb_hangar(take=0):
    """Big room: air handling, mains hum, far-off tools (a ratchet, a clank, a servo) in a long reverb."""
    t = t_(AL)
    x = _ln(70, 400) * (0.8 + 0.2 * slow(t, AL)) + _ln(400, 2500) * 0.12 * (0.6 + 0.4 * slow(t, AL))
    x += (sine(120, t) * 0.10 + sine(180, t) * 0.05 + sine(240, t) * 0.03) * (0.8 + 0.2 * slow(t, AL, (1, 2)))
    tr = t_(0.03); ratchet = z(0.5)
    for i in range(5):
        put(ratchet, tick(tr, 2100, 0.004) + snip(tr, 0.6), 0.075 * i)
    tc = t_(0.5); ts = t_(0.6)
    servo = f(saw(np.linspace(210, 330, len(ts)), ts, 2000), "lp", 800) * np.hanning(len(ts))
    ev = _events([(1.2, ratchet, 0.5), (3.7, modal(tc, [(640, .5, .2), (1570, .3, .12), (2300, .2, .08)]) + clack(tc), 0.5),
                  (5.6, servo, 0.35), (6.3, ratchet[::-1].copy(), 0.25)], 1.4, 1.2)
    return x + ev * 0.35

def amb_space(take=0):
    """Cabin: a slow-beating drone (D, A), air circulation, faint radio static, two far telemetry beeps."""
    t = t_(AL)
    drone = sum(sine(fr, t, uni(0, TAU)) * a for fr, a in ((73.5, .4), (73.625, .4), (110.0, .35), (110.25, .35), (146.875, .3), (220.5, .2), (293.75, .12)))
    x = u(drone) * 0.7 + _ln(250, 1600) * 0.6 * (0.6 + 0.4 * slow(t, AL)) + _ln(1500, 4000) * 0.06
    n = n_(AL); x += seam(crackle(n + SR, 6, 1500, 4000), n) * 0.5
    ev = _events([(2.3, beep(A6, 0.04, 0.0), 1.0), (2.42, beep(A6, 0.04, 0.0), 1.0), (6.1, beep(E6, 0.05, 0.0), 0.8)], 1.6, 1.5)
    return x + ev * 0.06

def amb_moon(take=0):
    """Almost silent: suit fan, slow breathing, an electronics tick now and then."""
    t = t_(AL)
    x = (sine(90, t) * 0.5 + sine(180, t) * 0.25 + sine(270, t) * 0.1) * 0.5 + _ln(200, 900) * 0.4
    ph = (t % 4.0) / 4.0
    breath = np.where(ph < 0.4, np.sin(np.pi * ph / 0.4) ** 2, 0.7 * np.sin(np.pi * (ph - 0.4) / 0.6) ** 2)
    x += _ln(300, 1100) * breath * 0.6 + _ln(900, 2600) * breath * 0.12
    tk = t_(0.02)
    ev = _events([(at, tick(tk, 3200, 0.003) + snip(tk, 0.5), g) for at, g in ((0.9, 1), (1.05, .6), (3.4, .8), (5.2, 1), (5.9, .5), (7.1, .7))], 0.6, 0.8)
    return x + ev * 0.12

def amb_mars_wind(take=0):
    """Thin wind: gusts in two bands, two faint whistles, sand hiss on the gusts."""
    t = t_(AL); g1 = slow(t, AL, (1, 2, 3)); g2 = slow(t, AL, (1, 3, 4, 6))
    return (_ln(150, 600) * (0.35 + 0.65 * g1) + _ln(500, 1800) * 0.6 * (0.2 + 0.8 * g2 ** 1.5)
            + _ln(880, 1040) * 0.25 * g2 ** 2 + _ln(1250, 1450) * 0.18 * (g1 * g2) + _ln(3500, 7500) * 0.12 * g1 ** 3)

def amb_saturn(take=0):
    """Ring plane: deep wind, a beating D-A cluster, a thin resonance, ice grains ticking past."""
    t = t_(AL); g = slow(t, AL, (1, 2, 3))
    x = _ln(90, 350) * (0.4 + 0.6 * g) + _ln(600, 800) * 0.2 * slow(t, AL, (2, 3, 5)) ** 2
    x += u(sum(sine(fr, t, uni(0, TAU)) for fr in (146.875, 147.25, 220.0, 220.5, 293.625))) * 0.35 * (0.5 + 0.5 * slow(t, AL, (1, 2)))
    tk = t_(0.05)
    ev = _events([(uni(0.3, 7.6), tick(tk, uni(3000, 6500), 0.006), uni(0.3, 1.0)) for _ in range(9)], 1.2, 1.0, )
    return x + ev * 0.1

# name: (takes, sample rate, loudness mode, target)   mom = loudest 400 ms (LUFS), int = integrated (LUFS), peak = dBFS
BIG, MID, SOFT, LOOP, AMB = -12.0, -15.0, -17.0, -14.0, -24.0
SOUNDS = {
    "click": (3, 44100, "mom", -20.0), "ui_hover": (2, 44100, "peak", -9.0), "ui_tab": (1, 44100, "mom", -22.0),
    "ui_open": (1, 44100, "mom", -20.0), "ui_close": (1, 44100, "mom", -20.0), "ui_deny": (1, 44100, "mom", -19.0),
    "confirm": (1, 32000, "mom", -16.0), "error": (1, 32000, "mom", -16.0), "coin": (1, 32000, "mom", -16.0),
    "blip": (2, 44100, "mom", -19.0), "radio_blip": (2, 44100, "mom", -18.0), "poll_blip": (2, 44100, "mom", -19.0),
    "poll_nogo": (1, 32000, "mom", SOFT), "station_go": (1, 32000, "mom", SOFT), "station_nogo": (1, 32000, "mom", SOFT),
    "all_go": (1, 32000, "mom", MID), "countdown_beep": (1, 32000, "mom", -16.0), "warn_alt": (1, 44100, "mom", -19.0),
    "battery_low": (1, 32000, "mom", -16.0), "alarm": (1, 32000, "mom", -14.0),
    "part_pick": (2, 44100, "mom", -18.0), "part_snap": (3, 44100, "mom", MID), "part_remove": (2, 44100, "mom", SOFT),
    "part_deny": (1, 44100, "mom", SOFT),
    "thrust": (1, 32000, "int", LOOP), "ignition": (1, 32000, "mom", -13.0), "launch": (1, 32000, "mom", BIG),
    "rcs": (3, 44100, "mom", -18.0), "stage_sep": (1, 32000, "mom", MID), "explosion": (1, 32000, "mom", BIG),
    "land": (1, 32000, "mom", -13.0), "success": (1, 32000, "mom", MID), "rover_loop": (1, 32000, "int", -16.0),
    "drill": (1, 32000, "int", -15.0), "drill_hit": (1, 32000, "mom", MID), "pickup": (1, 32000, "mom", -16.0),
    "jump": (1, 32000, "mom", SOFT), "hit": (3, 32000, "mom", -14.0), "dock": (1, 32000, "mom", -14.0),
    "ice_ping": (1, 44100, "mom", -16.0), "arrive": (1, 32000, "mom", MID),
    "amb_hangar": (1, 16000, "int", AMB), "amb_space": (1, 16000, "int", AMB), "amb_moon": (1, 16000, "int", AMB),
    "amb_mars_wind": (1, 16000, "int", AMB), "amb_saturn": (1, 16000, "int", AMB),
}
LOOPS = ("thrust", "rover_loop", "drill", "amb_hangar", "amb_space", "amb_moon", "amb_mars_wind", "amb_saturn")

def render(name):
    takes, sr, mode, target = SOUNDS[name]
    loop = name in LOOPS
    for take in range(takes):
        seed(name, take)
        x = globals()[name](take)
        x = cf(x, "hp", 60, 2) if loop else fade(f(x, "hp", 45, 2), 0.0003, 0.02)
        x = to_rate(x, sr, circ=loop)
        if mode == "peak":
            x = x / np.abs(x).max() * 10 ** (target / 20)
        else:
            x = level(x, target, mode, -1.2, sr, loop)
        if not loop:  # drop the inaudible end of long reverb tails (under -66 dBFS)
            x = fade(x[:np.nonzero(np.abs(x) > 5e-4)[0][-1] + n_(0.02, sr)], 0.0, 0.02, sr)
        save(name if take == 0 else "%s_%d" % (name, take), x, sr)

if __name__ == "__main__":
    for nm in (sys.argv[1:] or list(SOUNDS)):
        render(nm)
        print("made", nm)
