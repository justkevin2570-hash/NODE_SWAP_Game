#!/usr/bin/env python3
"""Node Swap 오리지널 사운드 생성기.

배경음악 루프와 효과음을 numpy 로 직접 합성해서 assets/audio 에 WAV 로 저장한다.
외부 샘플을 전혀 쓰지 않으므로 저작권 걱정이 없다.

    python3 tools/generate_audio.py

필요: numpy, scipy
"""

from __future__ import annotations

import os
import wave

import numpy as np
from scipy import signal

SR = 32000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
RNG = np.random.default_rng(2570)


# ─────────────────────────────────────────────────────────────
# 기본 도구
# ─────────────────────────────────────────────────────────────
def midi_hz(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def env_adsr(n: int, a=0.005, d=0.1, s=0.6, r=0.1, hold: float | None = None) -> np.ndarray:
    """n 샘플짜리 ADSR. hold 는 release 시작 시점(초)."""
    a_n = max(1, int(a * SR))
    d_n = max(1, int(d * SR))
    r_n = max(1, int(r * SR))
    hold_n = n - r_n if hold is None else int(hold * SR)
    e = np.zeros(n)
    idx = np.arange(n)
    e = np.where(idx < a_n, idx / a_n, e)
    dec = (idx >= a_n) & (idx < a_n + d_n)
    e = np.where(dec, 1 - (1 - s) * (idx - a_n) / d_n, e)
    e = np.where((idx >= a_n + d_n), s, e)
    rel = idx >= hold_n
    level_at_hold = e[min(max(hold_n, 0), n - 1)] if n else 0
    e = np.where(rel, level_at_hold * np.clip(1 - (idx - hold_n) / r_n, 0, 1), e)
    return e


def exp_env(n: int, decay: float) -> np.ndarray:
    return np.exp(-np.arange(n) / (decay * SR))


def osc(kind: str, freq, n: int, phase0: float = 0.0) -> np.ndarray:
    """freq 는 상수 또는 길이 n 배열 (글라이드)."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    ph = phase0 + np.cumsum(f) / SR
    frac = ph % 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "tri":
        return 4 * np.abs(frac - 0.5) - 1
    if kind == "saw":
        return 2 * frac - 1
    if kind == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if kind == "pulse25":
        return np.where(frac < 0.25, 1.0, -1.0)
    raise ValueError(kind)


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep_filter(x: np.ndarray, f0: float, f1: float, q_bw: float = 0.6, blocks: int = 48) -> np.ndarray:
    """블록 단위로 밴드패스 중심 주파수를 움직인다."""
    out = np.zeros_like(x)
    edges = np.linspace(0, len(x), blocks + 1).astype(int)
    zi = None
    for i in range(blocks):
        fc = f0 * (f1 / f0) ** (i / max(1, blocks - 1))
        lo, hi = fc * (1 - q_bw / 2), fc * (1 + q_bw / 2)
        b, a = signal.butter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
        if zi is None or len(zi) != max(len(a), len(b)) - 1:
            zi = signal.lfilter_zi(b, a) * 0
        seg = x[edges[i]:edges[i + 1]]
        out[edges[i]:edges[i + 1]], zi = signal.lfilter(b, a, seg, zi=zi)
    return out


def noise(n: int) -> np.ndarray:
    return RNG.uniform(-1, 1, n)


def reverb(x: np.ndarray, seconds: float = 1.2, mix: float = 0.25, bright: float = 6000) -> np.ndarray:
    n = int(seconds * SR)
    ir = noise(n) * np.exp(-np.arange(n) / (seconds * SR / 6.5))
    ir = lowpass(ir, bright)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    dry = np.concatenate([x, np.zeros(n)])
    wet = pad_to(signal.fftconvolve(x, ir), len(dry))
    return dry * (1 - mix) + wet * mix * 0.9


def delay(x: np.ndarray, t: float, fb: float = 0.35, mix: float = 0.3, taps: int = 4) -> np.ndarray:
    d = int(t * SR)
    out = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k: d * k + len(x)] += x * mix * fb ** (k - 1)
    return out


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros(n - len(x))])


def mix(*xs: np.ndarray) -> np.ndarray:
    """길이가 다른 신호들을 0으로 채워 더한다."""
    n = max(len(x) for x in xs)
    return sum(pad_to(x, n) for x in xs)


def put(out: np.ndarray, offset: int, x: np.ndarray) -> None:
    """out[offset:] 에 x 를 더하되 범위를 넘어가는 부분은 버린다."""
    j = min(len(out), offset + len(x))
    if j > offset:
        out[offset:j] += x[: j - offset]


def periodic(fn, x: np.ndarray) -> np.ndarray:
    """루프 음원에 필터를 걸 때: 앞뒤로 한 바퀴씩 이어 붙여 거른 뒤 가운데만 쓴다.
    그냥 거르면 파일 맨 앞에서 필터가 '처음 시작하는' 상태라, 반복 재생할 때 이음새 소리가 달라진다."""
    n = len(x)
    return fn(np.concatenate([x, x, x]))[n:2 * n]


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def soft_clip(x: np.ndarray, drive: float = 1.2) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def fade(x: np.ndarray, fin: float = 0.002, fout: float = 0.01) -> np.ndarray:
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {os.path.relpath(path, ROOT):28s} {len(x) / SR:5.2f}s")


# ─────────────────────────────────────────────────────────────
# 악기
# ─────────────────────────────────────────────────────────────
def kick(dur=0.32, punch=1.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 48 + 120 * np.exp(-t * 32)
    body = osc("sine", f, n) * exp_env(n, 0.11)
    click = lowpass(noise(n), 4000) * exp_env(n, 0.004) * 0.35
    return soft_clip((body + click) * punch, 1.6)


def clap(dur=0.22) -> np.ndarray:
    n = int(dur * SR)
    nz = bandpass(noise(n), 900, 5200)
    e = np.zeros(n)
    for off in (0, 0.009, 0.018):
        o = int(off * SR)
        e[o:] += exp_env(n - o, 0.012 if off < 0.018 else 0.07)
    return nz * e * 0.6


def snare(dur=0.2) -> np.ndarray:
    n = int(dur * SR)
    tone = osc("sine", 190, n) * exp_env(n, 0.04) * 0.5
    nz = highpass(noise(n), 1200) * exp_env(n, 0.06) * 0.7
    return tone + nz


def hat(dur=0.05, open_=False) -> np.ndarray:
    n = int((0.18 if open_ else dur) * SR)
    return highpass(noise(n), 7000, 4) * exp_env(n, 0.07 if open_ else 0.014) * 0.45


def shaker(dur=0.08) -> np.ndarray:
    n = int(dur * SR)
    e = np.minimum(np.arange(n) / (0.01 * SR), 1) * exp_env(n, 0.025)
    return bandpass(noise(n), 5000, 12000) * e * 0.3


def pluck_bass(note: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    f = midi_hz(note)
    x = osc("saw", f, n) * 0.6 + osc("square", f / 2, n) * 0.25
    # 필터 엔벨로프: 밝은 소리 → 어두운 소리로 크로스페이드
    k = np.exp(-np.arange(n) / (0.06 * SR))
    out = lowpass(x, 2600) * k + lowpass(x, 320) * (1 - k)
    return out * env_adsr(n, 0.003, 0.08, 0.7, 0.03)


def supersaw(notes: list[float], dur: float, cutoff=2200, detune=0.12, voices=5) -> np.ndarray:
    n = int(dur * SR)
    x = np.zeros(n)
    for note in notes:
        for v in range(voices):
            cents = (v - (voices - 1) / 2) * detune / (voices - 1) * 2
            x += osc("saw", midi_hz(note + cents), n, RNG.random())
    x /= len(notes) * voices
    return lowpass(x, cutoff, 2) * env_adsr(n, 0.04, 0.2, 0.8, 0.12)


def bell(note: float, dur: float, bright=1.0) -> np.ndarray:
    n = int(dur * SR)
    f = midi_hz(note)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 1.2 * bright * exp_env(n, 0.15)
    x = np.sin(2 * np.pi * f * t + mod)
    x += 0.35 * np.sin(2 * np.pi * f * 2 * t) * exp_env(n, 0.2)
    return x * exp_env(n, 0.35) * np.minimum(np.arange(n) / (0.002 * SR), 1)


def kalimba(note: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    f = midi_hz(note)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * exp_env(n, 0.03)
    return x * exp_env(n, 0.45) * np.minimum(np.arange(n) / (0.003 * SR), 1)


def square_pluck(note: float, dur: float, cut=3500) -> np.ndarray:
    n = int(dur * SR)
    x = osc("pulse25", midi_hz(note), n) * 0.5 + osc("square", midi_hz(note) * 1.003, n) * 0.3
    return lowpass(x, cut) * env_adsr(n, 0.002, 0.07, 0.25, 0.04)


def lead(note: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) * 5, 0, 1)
    f = midi_hz(note) * vib
    x = osc("square", f, n) * 0.4 + osc("saw", f * 1.005, n) * 0.4 + osc("sine", f * 2, n) * 0.2
    return lowpass(x, 5200) * env_adsr(n, 0.008, 0.1, 0.75, 0.06)


# ─────────────────────────────────────────────────────────────
# 시퀀서
# ─────────────────────────────────────────────────────────────
class Track:
    def __init__(self, bpm: float, bars: int):
        self.beat = 60 / bpm
        self.length = int(bars * 4 * self.beat * SR)
        self.tail = int(2.5 * SR)
        self.buses: dict[str, np.ndarray] = {}

    def bus(self, name: str) -> np.ndarray:
        if name not in self.buses:
            self.buses[name] = np.zeros(self.length + self.tail)
        return self.buses[name]

    def add(self, name: str, beat_pos: float, x: np.ndarray, gain=1.0) -> None:
        b = self.bus(name)
        i = int(beat_pos * self.beat * SR)
        j = min(len(b), i + len(x))
        b[i:j] += x[: j - i] * gain

    def sidechain(self, beats: list[float], depth=0.55, rel=0.18) -> np.ndarray:
        env = np.ones(self.length + self.tail)
        for p in beats:
            i = int(p * self.beat * SR)
            n = int(rel * SR)
            seg = 1 - depth * (1 - np.clip(np.arange(n) / n, 0, 1)) ** 2
            j = min(len(env), i + n)
            env[i:j] = np.minimum(env[i:j], seg[: j - i])
        return env

    def render(self, mix: dict[str, float], sc: np.ndarray | None = None,
               sc_buses=(), verb: dict[str, float] | None = None) -> np.ndarray:
        out = np.zeros(self.length + self.tail)
        verb = verb or {}
        for name, g in mix.items():
            if name not in self.buses:
                continue
            x = self.buses[name] * g
            if sc is not None and name in sc_buses:
                x = x * sc
            if name in verb:
                x = reverb(x, 1.6, verb[name])[: len(out)]
            out += x
        # 꼬리를 루프 앞부분에 겹쳐서 이음새 없는 루프로 만든다
        loop = out[: self.length].copy()
        loop[: self.tail] += out[self.length:]
        return loop


# 진행: F – G – Em – Am  (IV–V–iii–vi), 경쾌하지만 긴장감 있는 진행
PROG = [
    {"pad": [65, 69, 72, 76], "bass": 41, "arp": [77, 81, 84, 88]},
    {"pad": [67, 71, 74, 77], "bass": 43, "arp": [79, 83, 86, 89]},
    {"pad": [64, 67, 71, 74], "bass": 40, "arp": [76, 79, 83, 86]},
    {"pad": [64, 69, 72, 76], "bass": 45, "arp": [76, 81, 84, 88]},
]

MELODY = [  # (bar, beat, dur, midi)
    (0, 0, .5, 76), (0, .5, .5, 77), (0, 1, 1, 81), (0, 2, .5, 84), (0, 2.5, .5, 81), (0, 3, 1, 79),
    (1, 0, .5, 79), (1, .5, .5, 81), (1, 1, 1, 83), (1, 2, 1, 86), (1, 3, 1, 83),
    (2, 0, .5, 83), (2, .5, .5, 79), (2, 1, 1, 76), (2, 2, .5, 79), (2, 2.5, .5, 83), (2, 3, 1, 88),
    (3, 0, 1.5, 84), (3, 1.5, .5, 83), (3, 2, 1, 81), (3, 3, 1, 76),
    (4, 0, .5, 77), (4, .5, .5, 81), (4, 1, 1, 84), (4, 2, .5, 89), (4, 2.5, .5, 88), (4, 3, 1, 84),
    (5, 0, .5, 86), (5, .5, .5, 83), (5, 1, 1, 79), (5, 2, .5, 83), (5, 2.5, .5, 86), (5, 3, 1, 91),
    (6, 0, .5, 88), (6, .5, .5, 86), (6, 1, .5, 83), (6, 1.5, .5, 79), (6, 2, 1, 88), (6, 3, 1, 86),
    (7, 0, 1, 84), (7, 1, .5, 83), (7, 1.5, .5, 84), (7, 2, 2, 81),
]


def build_game_track(level: str) -> np.ndarray:
    """level: play | tense | fever — 같은 템포·길이·화성이라 위치를 맞춰 크로스페이드할 수 있다."""
    bpm, bars = 140, 8
    tr = Track(bpm, bars)
    k, cl, hc, ho = kick(), clap(), hat(), hat(open_=True)
    kicks = []
    for bar in range(bars):
        chord = PROG[bar % 4]
        b0 = bar * 4
        # 드럼
        for q in range(4):
            tr.add("kick", b0 + q, k)
            kicks.append(b0 + q)
            tr.add("hat", b0 + q + 0.5, ho, 0.8)
        if level != "play" or bar % 2 == 1:
            tr.add("clap", b0 + 1, cl)
            tr.add("clap", b0 + 3, cl)
        else:
            tr.add("clap", b0 + 3, cl)
        if level in ("tense", "fever"):
            for s in range(16):
                if s % 2 == 1:
                    tr.add("hat", b0 + s * 0.25, hc, 0.55 + 0.25 * (s % 4 == 3))
        if level == "fever" and bar % 2 == 1:
            for s in (3.25, 3.5, 3.75):
                tr.add("clap", b0 + s, snare(), 0.45)
        # 베이스: 8분 옥타브 바운스 (긴장 단계는 16분)
        step = 0.5 if level == "play" else 0.25
        for s in range(int(4 / step)):
            note = chord["bass"] + (12 if s % 2 else 0)
            tr.add("bass", b0 + s * step, pluck_bass(note, step * tr.beat * 0.9), 0.75)
        # 패드
        cut = {"play": 1800, "tense": 2400, "fever": 3800}[level]
        tr.add("pad", b0, supersaw(chord["pad"], 4 * tr.beat, cutoff=cut), 0.55)
        # 아르페지오
        arp_step = 0.5 if level == "play" else 0.25
        pattern = [0, 1, 2, 3, 2, 1, 2, 3] if level != "play" else [0, 2, 1, 3]
        for s in range(int(4 / arp_step)):
            note = chord["arp"][pattern[s % len(pattern)]]
            tr.add("arp", b0 + s * arp_step, square_pluck(note, arp_step * tr.beat * 0.95,
                                                        cut=2600 if level == "play" else 4200), 0.32)
        # 긴장 단계: 마지막 두 마디에 라이저
        if level == "tense" and bar in (3, 7):
            n = int(4 * tr.beat * SR)
            rise = sweep_filter(noise(n), 400, 7000) * np.linspace(0, 1, n) ** 2 * 0.5
            tr.add("fx", b0, rise)
        if level == "tense":
            for s in (0, 1.5, 3):
                tr.add("alarm", b0 + s, bell(chord["arp"][3] + 12, 0.25, 0.4), 0.12)
    if level == "fever":
        for bar, beat, dur, note in MELODY:
            tr.add("lead", bar * 4 + beat, lead(note, dur * tr.beat * 0.95), 0.36)
            tr.add("lead", bar * 4 + beat, bell(note + 12, dur * tr.beat, 0.6), 0.12)
        n = int(1 * tr.beat * SR)
        tr.add("fx", 0, highpass(noise(n), 3000) * exp_env(n, 0.25) * 0.4)

    sc = tr.sidechain(kicks, depth=0.6)
    for name in ("lead",):
        if name in tr.buses:
            tr.buses[name] = delay(tr.buses[name], tr.beat * 0.75, 0.3, 0.25)[: tr.length + tr.tail]
    mix = {"kick": 0.95, "clap": 0.5, "hat": 0.5, "bass": 0.7, "pad": 0.55,
           "arp": 0.55, "lead": 0.7, "fx": 0.6, "alarm": 1.0}
    out = tr.render(mix, sc, sc_buses=("bass", "pad", "arp"),
                    verb={"pad": 0.3, "arp": 0.25, "lead": 0.2, "clap": 0.15, "alarm": 0.4})
    out = periodic(lambda v: highpass(v, 30), out)
    return fade(normalize(soft_clip(normalize(out, 1.0), 1.4), 0.82), 0.0, 0.0)


def build_menu_track() -> np.ndarray:
    bpm, bars = 100, 8
    tr = Track(bpm, bars)
    prog = [
        {"pad": [60, 64, 67, 71], "bass": 36, "arp": [72, 76, 79, 83]},
        {"pad": [57, 60, 64, 67], "bass": 33, "arp": [69, 72, 76, 79]},
        {"pad": [57, 60, 65, 69], "bass": 41, "arp": [69, 72, 77, 81]},
        {"pad": [59, 62, 67, 71], "bass": 43, "arp": [71, 74, 79, 83]},
    ]
    k = kick(0.3, 0.7)
    kicks = []
    melody = [  # 귀여운 칼림바 멜로디 (bar, beat, midi)
        (0, 0, 79), (0, 1, 76), (0, 1.5, 79), (0, 2, 84), (0, 3, 83),
        (1, 0, 81), (1, 1, 76), (1, 2, 72), (1, 2.5, 74), (1, 3, 76),
        (2, 0, 77), (2, 1, 81), (2, 1.5, 84), (2, 2, 81), (2, 3, 77),
        (3, 0, 79), (3, 1, 74), (3, 2, 71), (3, 3, 74),
        (4, 0, 79), (4, 1, 76), (4, 1.5, 79), (4, 2, 84), (4, 3, 88),
        (5, 0, 86), (5, 1, 84), (5, 2, 81), (5, 2.5, 79), (5, 3, 76),
        (6, 0, 77), (6, 0.5, 79), (6, 1, 81), (6, 2, 84), (6, 3, 86),
        (7, 0, 83), (7, 1, 79), (7, 2, 74), (7, 3, 79),
    ]
    for bar in range(bars):
        ch = prog[bar % 4]
        b0 = bar * 4
        for q in (0, 2):
            tr.add("kick", b0 + q, k, 0.8)
            kicks.append(b0 + q)
        for q in range(8):
            tr.add("shaker", b0 + q * 0.5, shaker(), 0.7 if q % 2 else 0.4)
        tr.add("clap", b0 + 1, snare(), 0.25)
        tr.add("clap", b0 + 3, snare(), 0.25)
        tr.add("pad", b0, supersaw(ch["pad"], 4 * tr.beat, cutoff=1400, detune=0.08), 0.5)
        for s in range(4):
            tr.add("bass", b0 + s, pluck_bass(ch["bass"] + (12 if s % 2 else 0), tr.beat * 0.8), 0.6)
        for s in range(8):
            tr.add("arp", b0 + s * 0.5, bell(ch["arp"][[0, 2, 1, 3][s % 4]], 0.5, 0.5), 0.12)
    for bar, beat, note in melody:
        tr.add("lead", bar * 4 + beat, kalimba(note, 1.0), 0.45)
    sc = tr.sidechain(kicks, depth=0.35, rel=0.25)
    tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 0.75, 0.3, 0.3)[: tr.length + tr.tail]
    mix = {"kick": 0.8, "shaker": 0.5, "clap": 0.6, "pad": 0.5, "bass": 0.55, "arp": 0.6, "lead": 0.8}
    out = tr.render(mix, sc, sc_buses=("pad", "bass"),
                    verb={"pad": 0.35, "lead": 0.35, "arp": 0.4})
    out = periodic(lambda v: highpass(v, 30), out)
    return normalize(soft_clip(normalize(out, 1.0), 1.2), 0.75)


# ─────────────────────────────────────────────────────────────
# 효과음
# ─────────────────────────────────────────────────────────────
def sfx_tap():
    n = int(0.07 * SR)
    f = 1100 * np.exp(-np.arange(n) / SR * 25)
    return osc("sine", f, n) * exp_env(n, 0.02) * 0.8


def sfx_select():
    n = int(0.11 * SR)
    t = np.arange(n) / SR
    f = 520 + 900 * (1 - np.exp(-t * 40))
    x = osc("sine", f, n) * env_adsr(n, 0.004, 0.05, 0.5, 0.05)
    return reverb(x, 0.4, 0.15)


def sfx_swap():
    a = square_pluck(88, 0.08, 5000)
    b = square_pluck(93, 0.12, 5000)
    n = int(0.16 * SR)
    wh = sweep_filter(noise(n), 2500, 600, 0.8, 16) * np.sin(np.linspace(0, np.pi, n)) * 0.5
    out = np.zeros(int(0.35 * SR))
    out[: len(wh)] += wh
    out[: len(a)] += a * 0.7
    o = int(0.055 * SR)
    put(out, o, b * 0.7)
    return reverb(out, 0.5, 0.15)


def sfx_rotate():
    n = int(0.32 * SR)
    wh = sweep_filter(noise(n), 300, 4500, 0.7, 24) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
    t = np.arange(n) / SR
    tone = osc("tri", 300 + 900 * t / t[-1], n) * np.sin(np.linspace(0, np.pi, n)) * 0.25
    return reverb(wh * 0.9 + tone, 0.6, 0.2)


def sfx_match(step: int):
    notes = [84, 86, 88, 91, 93, 96, 98]
    x = mix(bell(notes[step], 0.6, 0.8) * 0.6, bell(notes[step] + 12, 0.4, 0.3) * 0.2)
    return reverb(x, 0.9, 0.3)


def sfx_clear():
    out = np.zeros(int(1.4 * SR))
    for i, note in enumerate([84, 88, 91, 96, 100]):
        x = bell(note, 0.7, 0.9) * 0.5
        o = int(i * 0.055 * SR)
        put(out, o, x[: len(out) - o])
    n = int(0.9 * SR)
    sparkle = highpass(noise(n), 8000, 4) * exp_env(n, 0.25) * 0.25
    o = int(0.2 * SR)
    out[o: o + n] += sparkle
    chord = supersaw([72, 76, 79, 84], 0.8, cutoff=5000) * 0.35
    put(out, int(0.22 * SR), chord)
    return reverb(out, 1.2, 0.3)


def sfx_combo(big=False):
    notes = [91, 96, 100] if big else [91, 96]
    out = np.zeros(int(0.7 * SR))
    for i, note in enumerate(notes):
        x = mix(square_pluck(note, 0.14, 6000) * 0.6, bell(note, 0.3, 0.5) * 0.3)
        o = int(i * 0.07 * SR)
        put(out, o, x)
    return reverb(out, 0.7, 0.25)


def sfx_fever():
    out = np.zeros(int(2.0 * SR))
    n = int(0.7 * SR)
    rise = sweep_filter(noise(n), 500, 9000, 0.6, 32) * np.linspace(0, 1, n) ** 2
    out[:n] += rise * 0.6
    t = np.arange(n) / SR
    out[:n] += osc("saw", 200 * 2 ** (t / t[-1] * 2), n) * np.linspace(0, 1, n) ** 2 * 0.15
    stab = supersaw([72, 76, 79, 84, 88], 0.9, cutoff=6000, detune=0.2, voices=7) * 0.8
    put(out, n, stab)
    k = kick(0.4, 1.3)
    put(out, n, k * 0.8)
    for i, note in enumerate([96, 100, 103, 108]):
        b = bell(note, 0.5, 0.8) * 0.3
        o = n + int(i * 0.06 * SR)
        put(out, o, b)
    return reverb(out, 1.4, 0.3)


def sfx_tick(urgent=False):
    n = int(0.05 * SR)
    f = 2100 if urgent else 1500
    x = osc("sine", f, n) * exp_env(n, 0.012) + bandpass(noise(n), 2000, 6000) * exp_env(n, 0.004) * 0.3
    if urgent:
        out = np.zeros(int(0.16 * SR))
        out[:n] += x
        out[int(0.08 * SR): int(0.08 * SR) + n] += x * 0.7
        return out * 0.8
    return x * 0.7


def sfx_fail():
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    f = 520 * np.exp(-t * 3.2) * (1 + 0.04 * np.sin(2 * np.pi * 14 * t))
    x = osc("tri", f, n) * 0.6 + osc("square", f / 2, n) * 0.12
    return reverb(lowpass(x, 2500) * env_adsr(n, 0.005, 0.1, 0.8, 0.2), 0.6, 0.2)


def sfx_error():
    out = np.zeros(int(0.2 * SR))
    n = int(0.07 * SR)
    for o in (0, 0.09):
        x = lowpass(osc("square", 180, n), 900) * env_adsr(n, 0.003, 0.02, 0.8, 0.02) * 0.45
        i = int(o * SR)
        out[i: i + n] += x
    return out


def sfx_countdown():
    n = int(0.18 * SR)
    x = osc("sine", 880, n) * 0.6 + osc("sine", 1760, n) * 0.15
    return reverb(x * env_adsr(n, 0.003, 0.05, 0.6, 0.08), 0.5, 0.2)


def sfx_go():
    n = int(0.5 * SR)
    x = sum(osc("sine", midi_hz(m), n) for m in (84, 88, 91, 96)) / 4
    x += supersaw([72, 79, 84], 0.5, cutoff=6000) * 0.5
    return reverb(x * env_adsr(n, 0.003, 0.1, 0.7, 0.25), 0.9, 0.25)


def sfx_gameover():
    out = np.zeros(int(2.2 * SR))
    for i, (note, d) in enumerate([(79, .25), (76, .25), (72, .25), (67, .9)]):
        n = int(d * SR)
        x = lowpass(osc("tri", midi_hz(note), n) * 0.6 + osc("square", midi_hz(note), n) * 0.15, 3000)
        x *= env_adsr(n, 0.005, 0.08, 0.7, 0.1)
        o = int(i * 0.27 * SR)
        out[o: o + n] += x
    pad = supersaw([55, 60, 63, 67], 1.2, cutoff=1500) * 0.4
    o = int(0.81 * SR)
    put(out, o, pad)
    return reverb(out, 1.4, 0.3)


def sfx_fanfare():
    out = np.zeros(int(2.6 * SR))
    seq = [(72, 0, .12), (76, .12, .12), (79, .24, .12), (84, .36, .5), (79, .9, .12), (84, 1.02, 1.0)]
    for note, st, d in seq:
        x = mix(lead(note, d) * 0.5, bell(note + 12, d + 0.3, 0.6) * 0.2)
        o = int(st * SR)
        put(out, o, x)
    chord = supersaw([60, 64, 67, 72, 76], 1.3, cutoff=5000) * 0.45
    o = int(1.02 * SR)
    put(out, o, chord)
    n = int(1.3 * SR)
    out[o: o + n] += highpass(noise(n), 8000, 4) * exp_env(n, 0.4) * 0.2
    return reverb(out, 1.5, 0.3)


def sfx_button():
    n = int(0.06 * SR)
    f = 700 * np.exp(-np.arange(n) / SR * 18)
    return osc("sine", f, n) * exp_env(n, 0.018) * 0.7 + lowpass(noise(n), 3000) * exp_env(n, 0.003) * 0.2


def sfx_hint():
    out = np.zeros(int(1.0 * SR))
    for i, note in enumerate([96, 100, 103, 107, 108, 103]):
        b = bell(note, 0.35, 0.5) * 0.3
        o = int(i * 0.05 * SR)
        put(out, o, b)
    return reverb(out, 1.0, 0.4)


def sfx_bonus():
    out = np.zeros(int(0.35 * SR))
    a = square_pluck(95, 0.07, 7000)
    b = square_pluck(100, 0.2, 7000)
    out[: len(a)] += a
    o = int(0.07 * SR)
    put(out, o, b)
    return reverb(out * 0.7, 0.4, 0.15)


def sfx_star(i: int):
    note = [88, 91, 96][i]
    x = mix(bell(note, 0.7, 1.0) * 0.5, bell(note + 7, 0.5, 0.5) * 0.15)
    n = int(0.4 * SR)
    x[:n] += highpass(noise(n), 9000, 4) * exp_env(n, 0.1) * 0.15
    return reverb(x, 1.0, 0.3)


def sfx_whoosh():
    n = int(0.35 * SR)
    return sweep_filter(noise(n), 5000, 500, 0.8, 24) * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.6


SFX = {
    "tap": sfx_tap,
    "select": sfx_select,
    "swap": sfx_swap,
    "rotate": sfx_rotate,
    **{f"match_{i}": (lambda i=i: sfx_match(i)) for i in range(7)},
    "clear": sfx_clear,
    "combo": sfx_combo,
    "combo_big": lambda: sfx_combo(True),
    "fever": sfx_fever,
    "tick": sfx_tick,
    "tick_urgent": lambda: sfx_tick(True),
    "fail": sfx_fail,
    "error": sfx_error,
    "countdown": sfx_countdown,
    "go": sfx_go,
    "gameover": sfx_gameover,
    "fanfare": sfx_fanfare,
    "button": sfx_button,
    "hint": sfx_hint,
    "bonus": sfx_bonus,
    **{f"star_{i}": (lambda i=i: sfx_star(i)) for i in range(3)},
    "whoosh": sfx_whoosh,
}


def trim_silence(x: np.ndarray, thresh=0.002) -> np.ndarray:
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    return x[: idx[-1] + int(0.01 * SR)]


def main() -> None:
    print("효과음")
    for name, fn in SFX.items():
        x = trim_silence(normalize(fn(), 0.85))
        write_wav(os.path.join(ROOT, "sfx", f"{name}.wav"), fade(x, 0.001, 0.01))
    print("배경음악")
    write_wav(os.path.join(ROOT, "music", "menu.wav"), build_menu_track())
    for level in ("play", "tense", "fever"):
        write_wav(os.path.join(ROOT, "music", f"{level}.wav"), build_game_track(level))


if __name__ == "__main__":
    main()
