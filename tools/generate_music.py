#!/usr/bin/env python3
"""Symmetry Rush 배경음악 생성기 (오리지널, 외부 샘플 없음).

테마마다 같은 템포·길이의 층(layer)을 만들어 게임 중 재생 위치를 맞춰 바꿀 수 있게 한다.
  - menu                     : 메뉴
  - rush_pop / rush_wave / rush_chip : 러시 (play · tense · fever)
  - stage_five / stage_seven / stage_nine : 스테이지·오늘의 퍼즐, 판 크기별 (calm · tense)

모두 16마디(A 8마디 + B 8마디)로, 끝과 처음이 이어지는 루프다.
OGG(Vorbis)로 저장해서 앱 크기를 줄인다.

    python3 tools/generate_music.py          # 전부
    python3 tools/generate_music.py rush_chip menu   # 일부만

필요: numpy, scipy, ffmpeg(libvorbis)
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_audio as ga  # noqa: E402
from generate_audio import (  # noqa: E402
    SR, Track, bell, clap, delay, env_adsr, exp_env, fade, hat, highpass, kalimba, kick, lead,
    lowpass, midi_hz, noise, normalize, osc, periodic, pluck_bass, reverb, shaker, snare,
    soft_clip, square_pluck, supersaw, sweep_filter, write_wav,
)

MUSIC_DIR = os.path.join(ga.ROOT, "music")
OGG_QUALITY = "1"  # libvorbis -q:a (모노 32kHz 에서 약 48kbps)


# ─────────────────────────────────────────────────────────────
# 추가 악기
# ─────────────────────────────────────────────────────────────
def rhodes(note: float, dur: float, vel=1.0) -> np.ndarray:
    """전자 피아노: FM 사인 + 금속성 타인 + 약한 트레몰로."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = midi_hz(note)
    mod = np.sin(2 * np.pi * f * t) * (1.6 * vel) * exp_env(n, 0.25)
    x = np.sin(2 * np.pi * f * t + mod)
    x += 0.18 * np.sin(2 * np.pi * f * 7.0 * t) * exp_env(n, 0.02)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.2 * t)
    return x * trem * env_adsr(n, 0.004, 0.6, 0.35, 0.25) * vel


def soft_pad(notes: list[float], dur: float, cutoff=1600, attack=0.6) -> np.ndarray:
    n = int(dur * SR)
    x = np.zeros(n)
    for note in notes:
        f = midi_hz(note)
        x += osc("tri", f, n, ga.RNG.random()) * 0.6 + osc("sine", f * 1.003, n, ga.RNG.random()) * 0.4
    x /= max(1, len(notes))
    return lowpass(x, cutoff) * env_adsr(n, attack, 0.3, 0.85, min(attack, dur * 0.3))


def sub_bass(note: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    return osc("sine", midi_hz(note), n) * env_adsr(n, 0.01, 0.2, 0.8, 0.08)


def saw_bass(note: float, dur: float, cut=900) -> np.ndarray:
    n = int(dur * SR)
    f = midi_hz(note)
    x = osc("saw", f, n) * 0.7 + osc("saw", f * 1.006, n) * 0.5
    k = np.exp(-np.arange(n) / (0.05 * SR))
    return (lowpass(x, cut * 2.5) * k + lowpass(x, cut) * (1 - k)) * env_adsr(n, 0.002, 0.05, 0.75, 0.02)


def tri_bass(note: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    return osc("tri", midi_hz(note), n) * env_adsr(n, 0.002, 0.05, 0.85, 0.01)


def chip_lead(note: float, dur: float, duty="pulse25") -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * 6 * t) * np.clip((t - 0.1) * 6, 0, 1)
    x = osc(duty, midi_hz(note) * vib, n)
    return lowpass(x, 7000) * env_adsr(n, 0.002, 0.08, 0.6, 0.02)


def chip_noise(dur: float, decay: float, bright=True) -> np.ndarray:
    """8비트 노이즈 드럼: 샘플을 계단처럼 붙잡아 거친 소리를 낸다."""
    n = int(dur * SR)
    hold = 2 if bright else 7
    nz = np.repeat(noise(n // hold + 1), hold)[:n]
    nz = np.sign(nz) * 0.8
    return nz * exp_env(n, decay)


def chip_kick() -> np.ndarray:
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    f = 50 + 220 * np.exp(-t * 45)
    return osc("square", f, n) * exp_env(n, 0.05) * 0.7


def crackle(n: int, density=6.0) -> np.ndarray:
    """레코드판 잡음 (로파이)."""
    x = lowpass(noise(n), 3000) * 0.015
    hits = ga.RNG.random(n) < density / SR
    pops = np.zeros(n)
    pops[hits] = ga.RNG.uniform(-1, 1, hits.sum())
    return x + highpass(pops, 1500) * 0.25


def gated_snare() -> np.ndarray:
    x = ga.mix(snare(0.35) * 0.9, clap(0.3) * 0.6)
    return reverb(x, 0.5, 0.45)[: int(0.4 * SR)]


# ─────────────────────────────────────────────────────────────
# 도우미
# ─────────────────────────────────────────────────────────────
def chord_line(chords: list[dict], rhythm: list[tuple[float, float]], seed: int, lo=72, hi=91,
               start=None) -> list[tuple[int, float, float, int]]:
    """마디마다 rhythm[(박, 길이)] 위치에 화음 구성음을 골라 부드럽게 이어지는 선율을 만든다.
    반환: (마디, 박, 길이, 음높이)"""
    rng = np.random.default_rng(seed)
    prev = start if start is not None else (lo + hi) // 2
    out = []
    for bar, ch in enumerate(chords):
        tones = sorted({p + 12 * k for p in ch["arp"] for k in (-2, -1, 0, 1) if lo <= p + 12 * k <= hi})
        for i, (beat, dur) in enumerate(rhythm):
            cand = sorted(tones, key=lambda p: abs(p - prev))[:3]
            # 마디 첫 음은 가장 가까운 음, 나머지는 가까운 세 음 중에서 고른다 (같은 음 반복은 피한다)
            pick = cand[0] if i == 0 else cand[int(rng.integers(0, len(cand)))]
            if pick == prev and len(cand) > 1:
                pick = cand[1]
            out.append((bar, beat, dur, pick))
            prev = pick
    return out


def finish(tr: Track, mix: dict, sc, sc_buses=(), verb=None, drive=1.3, peak=0.8, hp=30) -> np.ndarray:
    out = tr.render(mix, sc, sc_buses=sc_buses, verb=verb or {})
    out = periodic(lambda v: highpass(v, hp), out)
    return normalize(soft_clip(normalize(out, 1.0), drive), peak)


def section(bar: int) -> str:
    return "A" if bar < 8 else "B"


# ─────────────────────────────────────────────────────────────
# 러시 1: 팝 (기존 곡을 16마디로) — F G Em Am / Dm G C Am
# ─────────────────────────────────────────────────────────────
POP_A = ga.PROG
POP_B = [
    {"pad": [62, 65, 69, 72], "bass": 38, "arp": [74, 77, 81, 84]},
    {"pad": [62, 67, 71, 74], "bass": 43, "arp": [74, 79, 83, 86]},
    {"pad": [64, 67, 72, 76], "bass": 36, "arp": [76, 79, 84, 88]},
    {"pad": [64, 69, 72, 76], "bass": 45, "arp": [76, 81, 84, 88]},
]


def rush_pop(level: str) -> np.ndarray:
    bpm, bars = 140, 16
    tr = Track(bpm, bars)
    k, cl, hc, ho = kick(), clap(), hat(), hat(open_=True)
    chords = [(POP_A if bar < 8 else POP_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        for q in range(4):
            tr.add("kick", b0 + q, k)
            kicks.append(b0 + q)
            tr.add("hat", b0 + q + 0.5, ho, 0.8)
        if level != "play" or bar % 2 == 1:
            tr.add("clap", b0 + 1, cl)
        tr.add("clap", b0 + 3, cl)
        if level in ("tense", "fever"):
            for s in range(1, 16, 2):
                tr.add("hat", b0 + s * 0.25, hc, 0.55 + 0.25 * (s % 4 == 3))
        if level == "fever" and bar % 2 == 1:
            for s in (3.25, 3.5, 3.75):
                tr.add("clap", b0 + s, snare(), 0.45)
        step = 0.5 if level == "play" else 0.25
        for s in range(int(4 / step)):
            tr.add("bass", b0 + s * step, pluck_bass(ch["bass"] + (12 if s % 2 else 0), step * tr.beat * 0.9), 0.75)
        cut = {"play": 1800, "tense": 2400, "fever": 3800}[level]
        tr.add("pad", b0, supersaw(ch["pad"], 4 * tr.beat, cutoff=cut), 0.55)
        arp_step = 0.5 if level == "play" else 0.25
        pattern = ([0, 2, 1, 3] if sec == "A" else [3, 1, 2, 0]) if level == "play" else \
            ([0, 1, 2, 3, 2, 1, 2, 3] if sec == "A" else [3, 2, 1, 2, 0, 2, 1, 3])
        for s in range(int(4 / arp_step)):
            tr.add("arp", b0 + s * arp_step, square_pluck(ch["arp"][pattern[s % len(pattern)]], arp_step * tr.beat * 0.95,
                                                          cut=2600 if level == "play" else 4200), 0.32)
        if level == "tense" and bar % 4 == 3:
            n = int(4 * tr.beat * SR)
            tr.add("fx", b0, sweep_filter(noise(n), 400, 7000) * np.linspace(0, 1, n) ** 2 * 0.5)
        if level == "tense":
            for s in (0, 1.5, 3):
                tr.add("alarm", b0 + s, bell(ch["arp"][3] + 12, 0.25, 0.4), 0.12)
    # B 구간: 기본 층에도 벨 대선율을 넣어 반복감을 줄인다
    for bar, beat, dur, note in chord_line(chords[8:], [(0, 1.5), (1.5, 1), (2.5, 1.5)], 11, 79, 91):
        tr.add("bell", (bar + 8) * 4 + beat, bell(note, dur * tr.beat * 1.2, 0.5), 0.16)
    if level == "fever":
        for bar, beat, dur, note in ga.MELODY:
            tr.add("lead", bar * 4 + beat, lead(note, dur * tr.beat * 0.95), 0.36)
            tr.add("lead", bar * 4 + beat, bell(note + 12, dur * tr.beat, 0.6), 0.12)
        rhythm = [(0, .5), (.5, .5), (1, 1), (2, .5), (2.5, .5), (3, 1)]
        for bar, beat, dur, note in chord_line(chords[8:], rhythm, 21, 76, 91, start=84):
            tr.add("lead", (bar + 8) * 4 + beat, lead(note, dur * tr.beat * 0.95), 0.36)
            tr.add("lead", (bar + 8) * 4 + beat, bell(note + 12, dur * tr.beat, 0.6), 0.12)
    sc = tr.sidechain(kicks, depth=0.6)
    if "lead" in tr.buses:
        tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 0.75, 0.3, 0.25)[: tr.length + tr.tail]
    mix = {"kick": 0.95, "clap": 0.5, "hat": 0.5, "bass": 0.7, "pad": 0.55, "arp": 0.55,
           "lead": 0.7, "fx": 0.6, "alarm": 1.0, "bell": 0.8}
    return finish(tr, mix, sc, ("bass", "pad", "arp"),
                  {"pad": 0.3, "arp": 0.25, "lead": 0.2, "clap": 0.15, "alarm": 0.4, "bell": 0.4}, 1.4, 0.82)


# ─────────────────────────────────────────────────────────────
# 러시 2: 신스웨이브 (A단조, 150BPM) — Am F C G / Dm Am F E
# ─────────────────────────────────────────────────────────────
WAVE_A = [
    {"pad": [57, 60, 64, 69], "bass": 33, "arp": [69, 72, 76, 81]},
    {"pad": [53, 57, 60, 65], "bass": 29, "arp": [65, 69, 72, 77]},
    {"pad": [55, 60, 64, 67], "bass": 36, "arp": [67, 72, 76, 79]},
    {"pad": [55, 59, 62, 67], "bass": 31, "arp": [67, 71, 74, 79]},
]
WAVE_B = [
    {"pad": [57, 62, 65, 69], "bass": 38, "arp": [69, 74, 77, 81]},
    {"pad": [57, 60, 64, 69], "bass": 33, "arp": [69, 72, 76, 81]},
    {"pad": [53, 57, 60, 65], "bass": 29, "arp": [65, 69, 72, 77]},
    {"pad": [56, 59, 64, 68], "bass": 28, "arp": [68, 71, 76, 80]},
]


def rush_wave(level: str) -> np.ndarray:
    bpm, bars = 150, 16
    tr = Track(bpm, bars)
    k, gs, hc, ho = kick(0.36, 1.1), gated_snare(), hat(), hat(open_=True)
    chords = [(WAVE_A if bar < 8 else WAVE_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        for q in range(4):
            tr.add("kick", b0 + q, k)
            kicks.append(b0 + q)
        tr.add("snare", b0 + 1, gs)
        tr.add("snare", b0 + 3, gs)
        for s in range(8):
            tr.add("hat", b0 + s * 0.5, ho if s % 2 else hc, 0.5 if s % 2 else 0.35)
        if level != "play":
            for s in range(16):
                tr.add("hat", b0 + s * 0.25, hc, 0.25 + 0.2 * (s % 4 == 2))
        # 16분 옥타브 베이스 (신스웨이브의 '달리는' 느낌)
        for s in range(16):
            note = ch["bass"] + (12 if s % 4 == 2 else 0)
            tr.add("bass", b0 + s * 0.25, saw_bass(note, 0.25 * tr.beat * 0.85, 700 if level == "play" else 1100), 0.6)
        tr.add("pad", b0, supersaw(ch["pad"], 4 * tr.beat, cutoff={"play": 1500, "tense": 2200, "fever": 3200}[level],
                                   detune=0.18), 0.5)
        # 아르페지오: 16분, A·B 구간 패턴이 다르다
        pat = [0, 1, 2, 3, 2, 1, 0, 1] if sec == "A" else [0, 2, 3, 2, 1, 3, 2, 1]
        if level != "play" or sec == "B":
            for s in range(16):
                tr.add("arp", b0 + s * 0.25, square_pluck(ch["arp"][pat[s % 8]] + 12 * (sec == "B"),
                                                          0.25 * tr.beat * 0.9, 3800), 0.26)
        if level == "tense":
            if bar % 4 == 3:
                n = int(4 * tr.beat * SR)
                tr.add("fx", b0, sweep_filter(noise(n), 300, 8000) * np.linspace(0, 1, n) ** 2 * 0.45)
            tr.add("alarm", b0 + 2, bell(ch["arp"][0] + 24, 0.4, 0.8), 0.1)
    # 기본 층 리드 (A: 길게, B: 짧게) — 신스 브라스 느낌
    rhythm_a = [(0, 1.5), (1.5, 1.5), (3, 1)]
    for bar, beat, dur, note in chord_line(chords[:8], rhythm_a, 31, 69, 84, start=76):
        tr.add("lead", bar * 4 + beat, lead(note, dur * tr.beat * 0.9), 0.3)
    if level == "fever":
        rhythm = [(0, .5), (.5, .25), (.75, .75), (1.5, .5), (2, 1), (3, .5), (3.5, .5)]
        for bar, beat, dur, note in chord_line(chords[8:], rhythm, 41, 76, 93, start=81):
            tr.add("lead", (bar + 8) * 4 + beat, lead(note, dur * tr.beat * 0.9), 0.34)
            tr.add("lead", (bar + 8) * 4 + beat, bell(note + 12, dur * tr.beat, 0.5), 0.1)
        n = int(tr.beat * SR)
        tr.add("fx", 0, highpass(noise(n), 3000) * exp_env(n, 0.25) * 0.4)
    sc = tr.sidechain(kicks, depth=0.65, rel=0.2)
    tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 0.75, 0.35, 0.3)[: tr.length + tr.tail]
    mix = {"kick": 1.0, "snare": 0.55, "hat": 0.45, "bass": 0.7, "pad": 0.5, "arp": 0.5,
           "lead": 0.65, "fx": 0.6, "alarm": 1.0}
    return finish(tr, mix, sc, ("bass", "pad", "arp"),
                  {"pad": 0.35, "arp": 0.3, "lead": 0.3, "alarm": 0.4}, 1.5, 0.82)


# ─────────────────────────────────────────────────────────────
# 러시 3: 칩튠 (C장조, 160BPM) — C Am F G / Am Em F G
# ─────────────────────────────────────────────────────────────
CHIP_A = [
    {"bass": 36, "arp": [72, 76, 79, 84]},
    {"bass": 33, "arp": [69, 72, 76, 81]},
    {"bass": 29, "arp": [65, 69, 72, 77]},
    {"bass": 31, "arp": [67, 71, 74, 79]},
]
CHIP_B = [
    {"bass": 33, "arp": [69, 72, 76, 81]},
    {"bass": 28, "arp": [67, 71, 76, 79]},
    {"bass": 29, "arp": [65, 69, 72, 77]},
    {"bass": 31, "arp": [67, 71, 74, 79]},
]


def rush_chip(level: str) -> np.ndarray:
    bpm, bars = 160, 16
    tr = Track(bpm, bars)
    ck = chip_kick()
    sn = chip_noise(0.14, 0.05, bright=False)
    hh = chip_noise(0.04, 0.01)
    chords = [(CHIP_A if bar < 8 else CHIP_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        for q in (0, 1.5, 2) if sec == "A" else (0, 2, 2.5):
            tr.add("kick", b0 + q, ck)
            kicks.append(b0 + q)
        tr.add("snare", b0 + 1, sn, 0.6)
        tr.add("snare", b0 + 3, sn, 0.6)
        hats = 8 if level == "play" else 16
        for s in range(hats):
            tr.add("hat", b0 + s * 4 / hats, hh, 0.35 if s % 2 else 0.2)
        # 트라이앵글 베이스: 8분 근음-5도
        for s in range(8):
            note = ch["bass"] + 12 + (7 if s % 4 == 2 else 0) + (12 if s % 4 == 3 else 0)
            tr.add("bass", b0 + s * 0.5, tri_bass(note, 0.5 * tr.beat * 0.9), 0.8)
        # 빠른 화음 아르페지오 (옛 게임기는 화음을 이렇게 냈다)
        arp_n = 12 if level == "play" else 16
        for s in range(arp_n):
            note = ch["arp"][s % 3] + (12 if level == "fever" else 0)
            tr.add("arp", b0 + s * 4 / arp_n, chip_lead(note, 4 / arp_n * tr.beat * 0.9, "pulse25") * 0.6, 0.2)
        if level == "tense":
            for s in (0, 2):
                tr.add("alarm", b0 + s, chip_lead(ch["arp"][3] + 12, 0.15, "square"), 0.12)
            if bar % 4 == 3:
                for i, s in enumerate(np.arange(0, 4, 0.25)):
                    tr.add("fx", b0 + s, chip_noise(0.05, 0.02) * (i / 16), 0.4)
    # 메인 멜로디 (기본 층부터): A는 통통 튀게, B는 길게
    rhythm_a = [(0, .5), (.5, .5), (1, .75), (1.75, .25), (2, 1), (3, .5), (3.5, .5)]
    rhythm_b = [(0, 1), (1, .5), (1.5, .5), (2, 1.5), (3.5, .5)]
    mel = chord_line(chords[:8], rhythm_a, 51, 72, 91, start=79) + \
        [(b + 8, bt, d, p) for b, bt, d, p in chord_line(chords[8:], rhythm_b, 52, 72, 88, start=76)]
    for bar, beat, dur, note in mel:
        tr.add("lead", bar * 4 + beat, chip_lead(note, dur * tr.beat * 0.85, "square"), 0.32)
        if level == "fever":
            tr.add("lead2", bar * 4 + beat + 0.25, chip_lead(note + 12, dur * tr.beat * 0.6, "pulse25"), 0.12)
    sc = tr.sidechain(kicks, depth=0.2, rel=0.1)
    mix = {"kick": 0.9, "snare": 0.6, "hat": 0.45, "bass": 0.75, "arp": 0.55, "lead": 0.7,
           "lead2": 0.6, "alarm": 1.0, "fx": 0.6}
    return finish(tr, mix, sc, ("arp",), {"lead": 0.12, "lead2": 0.2}, 1.2, 0.8)


# ─────────────────────────────────────────────────────────────
# 스테이지 5x5: 밝은 칼림바 (95BPM) — C G Am F / Dm G Em Am
# ─────────────────────────────────────────────────────────────
FIVE_A = [
    {"pad": [60, 64, 67], "bass": 36, "arp": [72, 76, 79, 84]},
    {"pad": [59, 62, 67], "bass": 31, "arp": [71, 74, 79, 83]},
    {"pad": [57, 60, 64], "bass": 33, "arp": [69, 72, 76, 81]},
    {"pad": [57, 60, 65], "bass": 29, "arp": [69, 72, 77, 81]},
]
FIVE_B = [
    {"pad": [57, 62, 65], "bass": 38, "arp": [69, 74, 77, 81]},
    {"pad": [59, 62, 67], "bass": 31, "arp": [71, 74, 79, 83]},
    {"pad": [59, 64, 67], "bass": 28, "arp": [71, 76, 79, 83]},
    {"pad": [57, 60, 64], "bass": 33, "arp": [69, 72, 76, 81]},
]


def stage_five(level: str) -> np.ndarray:
    bpm, bars = 95, 16
    tr = Track(bpm, bars)
    k = kick(0.28, 0.6)
    chords = [(FIVE_A if bar < 8 else FIVE_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        for q in (0, 2.5) if sec == "A" else (0, 2):
            tr.add("kick", b0 + q, k, 0.7)
            kicks.append(b0 + q)
        for q in range(8):
            tr.add("shaker", b0 + q * 0.5, shaker(), 0.6 if q % 2 else 0.3)
        tr.add("snare", b0 + 1, snare(0.15), 0.15)
        tr.add("snare", b0 + 3, snare(0.15), 0.15)
        tr.add("pad", b0, soft_pad(ch["pad"], 4 * tr.beat, 1400, 0.4), 0.45)
        for s in range(4):
            tr.add("bass", b0 + s, pluck_bass(ch["bass"] + (12 if s == 2 else 0), tr.beat * 0.7), 0.45)
        if level == "tense":
            # 시계 소리처럼 째깍이는 16분 하이햇 + 높은 벨 + 베이스 펄스
            for s in range(16):
                tr.add("tick", b0 + s * 0.25, hat(0.03), 0.5 + 0.3 * (s % 4 == 0))
            for s in range(8):
                tr.add("pulse", b0 + s * 0.5, pluck_bass(ch["bass"] + 12, 0.5 * tr.beat * 0.5), 0.35)
            tr.add("alarm", b0 + 3.5, bell(ch["arp"][3] + 12, 0.3, 0.5), 0.08)
    rhythm_a = [(0, 1), (1, .5), (1.5, .5), (2, 1), (3, 1)]
    rhythm_b = [(0, .5), (.5, .5), (1, 1.5), (2.5, .5), (3, 1)]
    mel = chord_line(chords[:8], rhythm_a, 61, 72, 88, start=79) + \
        [(b + 8, bt, d, p) for b, bt, d, p in chord_line(chords[8:], rhythm_b, 62, 72, 88, start=81)]
    for bar, beat, dur, note in mel:
        tr.add("lead", bar * 4 + beat, kalimba(note, 1.2), 0.42)
    for bar in range(bars):
        for s in range(4):
            tr.add("arp", bar * 4 + s + 0.5, bell(chords[bar]["arp"][[0, 2, 1, 3][s]], 0.5, 0.4), 0.08)
    sc = tr.sidechain(kicks, depth=0.25, rel=0.25)
    tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 0.75, 0.3, 0.28)[: tr.length + tr.tail]
    mix = {"kick": 0.75, "shaker": 0.5, "snare": 0.6, "pad": 0.5, "bass": 0.55, "lead": 0.8,
           "arp": 0.6, "tick": 0.35, "pulse": 0.5, "alarm": 1.0}
    return finish(tr, mix, sc, ("pad", "bass"), {"pad": 0.35, "lead": 0.35, "arp": 0.4, "alarm": 0.4}, 1.15, 0.72)


# ─────────────────────────────────────────────────────────────
# 스테이지 7x7: 로파이 (85BPM, 스윙) — Fmaj7 Em7 Dm7 Cmaj7 / Bbmaj7 Am7 Dm7 G7
# ─────────────────────────────────────────────────────────────
SEVEN_A = [
    {"keys": [53, 57, 60, 64], "bass": 29, "arp": [72, 76, 77, 81]},
    {"keys": [52, 55, 59, 62], "bass": 28, "arp": [71, 74, 76, 79]},
    {"keys": [50, 53, 57, 60], "bass": 26, "arp": [69, 72, 74, 77]},
    {"keys": [48, 52, 55, 59], "bass": 24, "arp": [67, 71, 72, 76]},
]
SEVEN_B = [
    {"keys": [50, 53, 57, 58], "bass": 34, "arp": [69, 70, 74, 77]},
    {"keys": [48, 52, 55, 57], "bass": 33, "arp": [69, 72, 76, 79]},
    {"keys": [50, 53, 57, 60], "bass": 26, "arp": [69, 72, 74, 77]},
    {"keys": [47, 50, 53, 55], "bass": 31, "arp": [67, 71, 74, 77]},
]


def stage_seven(level: str) -> np.ndarray:
    bpm, bars = 85, 16
    tr = Track(bpm, bars)
    swing = 0.08  # 8분 뒷박을 살짝 늦춘다
    k = lowpass(kick(0.3, 0.8), 2500)
    sn = lowpass(snare(0.2), 4000)
    chords = [(SEVEN_A if bar < 8 else SEVEN_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        for q in (0, 1.75, 2.5) if sec == "A" else (0, 2.25, 2.5):
            tr.add("kick", b0 + q, k, 0.8)
            kicks.append(b0 + q)
        tr.add("snare", b0 + 1, sn, 0.5)
        tr.add("snare", b0 + 3, sn, 0.5)
        for s in range(8):
            tr.add("hat", b0 + s * 0.5 + (swing if s % 2 else 0), lowpass(hat(0.04), 9000), 0.45 if s % 2 else 0.3)
        # 전자 피아노: 화음을 살짝 흩어 친다
        for i, note in enumerate(ch["keys"]):
            tr.add("keys", b0 + i * 0.03, rhodes(note + 12, 3.6 * tr.beat, 0.7), 0.22)
            tr.add("keys", b0 + 2.5 + swing + i * 0.03, rhodes(note + 12, 1.3 * tr.beat, 0.5), 0.14)
        tr.add("bass", b0, sub_bass(ch["bass"] + 12, 2.4 * tr.beat), 0.6)
        tr.add("bass", b0 + 2.5 + swing, sub_bass(ch["bass"] + 12 + (7 if sec == "B" else 0), 1.3 * tr.beat), 0.5)
        if level == "tense":
            for s in range(16):
                tr.add("tick", b0 + s * 0.25 + (swing / 2 if s % 2 else 0), hat(0.025), 0.4 + 0.3 * (s % 4 == 0))
            for s in range(8):
                tr.add("pulse", b0 + s * 0.5, pluck_bass(ch["bass"] + 24, 0.5 * tr.beat * 0.45), 0.25)
            if bar % 4 == 3:
                n = int(4 * tr.beat * SR)
                tr.add("fx", b0, sweep_filter(noise(n), 300, 4000) * np.linspace(0, 1, n) ** 2 * 0.25)
    rhythm_a = [(0.5, 1), (1.5 + swing, .5), (2, 1.5)]
    rhythm_b = [(0, .5), (.5 + swing, 1), (2, .5), (2.5 + swing, 1.5)]
    mel = chord_line(chords[:8], rhythm_a, 71, 67, 84, start=76) + \
        [(b + 8, bt, d, p) for b, bt, d, p in chord_line(chords[8:], rhythm_b, 72, 67, 84, start=74)]
    for bar, beat, dur, note in mel:
        tr.add("lead", bar * 4 + beat, bell(note, dur * tr.beat * 1.4, 0.25), 0.2)
    tr.add("vinyl", 0, crackle(tr.length + tr.tail))
    sc = tr.sidechain(kicks, depth=0.3, rel=0.3)
    tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 0.75, 0.35, 0.3)[: tr.length + tr.tail]
    mix = {"kick": 0.8, "snare": 0.55, "hat": 0.4, "keys": 0.75, "bass": 0.7, "lead": 0.7,
           "tick": 0.3, "pulse": 0.5, "fx": 0.5, "vinyl": 0.6}
    out = finish(tr, mix, sc, ("keys", "bass"), {"keys": 0.3, "lead": 0.4, "snare": 0.2}, 1.1, 0.72)
    return periodic(lambda v: lowpass(v, 9000), out)  # 살짝 먹먹하게 (로파이)


# ─────────────────────────────────────────────────────────────
# 스테이지 9x9: 몽환적인 앰비언트 (75BPM) — Am9 Fmaj7 Cmaj7 G6 / Dm9 Am7 Fmaj7 Esus
# ─────────────────────────────────────────────────────────────
NINE_A = [
    {"pad": [57, 60, 64, 71], "bass": 33, "arp": [69, 71, 72, 76]},
    {"pad": [53, 57, 60, 64], "bass": 29, "arp": [65, 69, 72, 76]},
    {"pad": [48, 52, 55, 59], "bass": 36, "arp": [67, 71, 72, 76]},
    {"pad": [55, 59, 62, 64], "bass": 31, "arp": [67, 71, 74, 76]},
]
NINE_B = [
    {"pad": [50, 53, 57, 64], "bass": 38, "arp": [69, 72, 74, 76]},
    {"pad": [57, 60, 64, 67], "bass": 33, "arp": [69, 72, 76, 79]},
    {"pad": [53, 57, 60, 64], "bass": 29, "arp": [65, 69, 72, 76]},
    {"pad": [52, 57, 59, 64], "bass": 28, "arp": [64, 69, 71, 76]},
]


def stage_nine(level: str) -> np.ndarray:
    bpm, bars = 75, 16
    tr = Track(bpm, bars)
    chords = [(NINE_A if bar < 8 else NINE_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        tr.add("pad", b0, soft_pad(ch["pad"], 4.2 * tr.beat, 1200 if sec == "A" else 1700, 1.2), 0.5)
        tr.add("pad", b0, soft_pad([p + 12 for p in ch["pad"][1:3]], 4.2 * tr.beat, 2400, 1.8), 0.2)
        tr.add("bass", b0, sub_bass(ch["bass"] + 12, 3.8 * tr.beat), 0.5)
        # 반짝이는 벨: 느린 아르페지오
        pat = [0, 2, 3, 1] if sec == "A" else [3, 1, 2, 0]
        for s in range(4):
            tr.add("sparkle", b0 + s + 0.5 * (s % 2), bell(ch["arp"][pat[s]] + 12, 1.5, 0.3), 0.08)
        if sec == "B" or level == "tense":
            tr.add("kick", b0, lowpass(kick(0.4, 0.5), 1500), 0.6)
            kicks.append(b0)
            tr.add("kick", b0 + 2.5, lowpass(kick(0.4, 0.4), 1500), 0.4)
            kicks.append(b0 + 2.5)
        if level == "tense":
            for s in range(8):
                tr.add("pulse", b0 + s * 0.5, square_pluck(ch["arp"][s % 4], 0.5 * tr.beat * 0.6, 1800), 0.16)
            for s in range(16):
                tr.add("tick", b0 + s * 0.25, hat(0.025), 0.3 + 0.3 * (s % 4 == 0))
            if bar % 4 == 3:
                n = int(4 * tr.beat * SR)
                tr.add("fx", b0, sweep_filter(noise(n), 200, 3000) * np.linspace(0, 1, n) ** 2 * 0.3)
    rhythm = [(0, 2), (2, 1), (3, 1)]
    for bar, beat, dur, note in chord_line(chords, rhythm, 81, 72, 88, start=76):
        if (bar + int(beat)) % 3 == 1:
            continue  # 선율에 빈틈을 둬서 여유 있게
        tr.add("lead", bar * 4 + beat, kalimba(note, dur * tr.beat * 1.5) * 0.7, 0.3)
    sc = tr.sidechain(kicks, depth=0.2, rel=0.4)
    tr.buses["sparkle"] = delay(tr.buses["sparkle"], tr.beat, 0.45, 0.35, 5)[: tr.length + tr.tail]
    tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 1.5, 0.4, 0.3)[: tr.length + tr.tail]
    mix = {"pad": 0.7, "bass": 0.6, "sparkle": 0.8, "kick": 0.6, "pulse": 0.5, "tick": 0.3,
           "fx": 0.5, "lead": 0.7}
    return finish(tr, mix, sc, ("pad",), {"pad": 0.5, "sparkle": 0.55, "lead": 0.5, "pulse": 0.3}, 1.05, 0.7)


# ─────────────────────────────────────────────────────────────
# 메뉴 (100BPM, 16마디)
# ─────────────────────────────────────────────────────────────
MENU_A = [
    {"pad": [60, 64, 67, 71], "bass": 36, "arp": [72, 76, 79, 83]},
    {"pad": [57, 60, 64, 67], "bass": 33, "arp": [69, 72, 76, 79]},
    {"pad": [57, 60, 65, 69], "bass": 41, "arp": [69, 72, 77, 81]},
    {"pad": [59, 62, 67, 71], "bass": 43, "arp": [71, 74, 79, 83]},
]
MENU_B = [
    {"pad": [57, 60, 65, 69], "bass": 41, "arp": [69, 72, 77, 81]},
    {"pad": [59, 64, 67, 71], "bass": 40, "arp": [71, 76, 79, 83]},
    {"pad": [57, 62, 65, 69], "bass": 38, "arp": [69, 74, 77, 81]},
    {"pad": [59, 62, 65, 67], "bass": 43, "arp": [71, 74, 77, 79]},
]
MENU_MELODY = [  # 기존 메뉴 멜로디 (A 구간)
    (0, 0, 79), (0, 1, 76), (0, 1.5, 79), (0, 2, 84), (0, 3, 83),
    (1, 0, 81), (1, 1, 76), (1, 2, 72), (1, 2.5, 74), (1, 3, 76),
    (2, 0, 77), (2, 1, 81), (2, 1.5, 84), (2, 2, 81), (2, 3, 77),
    (3, 0, 79), (3, 1, 74), (3, 2, 71), (3, 3, 74),
    (4, 0, 79), (4, 1, 76), (4, 1.5, 79), (4, 2, 84), (4, 3, 88),
    (5, 0, 86), (5, 1, 84), (5, 2, 81), (5, 2.5, 79), (5, 3, 76),
    (6, 0, 77), (6, 0.5, 79), (6, 1, 81), (6, 2, 84), (6, 3, 86),
    (7, 0, 83), (7, 1, 79), (7, 2, 74), (7, 3, 79),
]


def menu() -> np.ndarray:
    bpm, bars = 100, 16
    tr = Track(bpm, bars)
    k = kick(0.3, 0.7)
    chords = [(MENU_A if bar < 8 else MENU_B)[bar % 4] for bar in range(bars)]
    kicks = []
    for bar in range(bars):
        ch, b0, sec = chords[bar], bar * 4, section(bar)
        for q in (0, 2) if sec == "A" else (0, 1.5, 2):
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
            tr.add("arp", b0 + s * 0.5, bell(ch["arp"][[0, 2, 1, 3][s % 4] if sec == "A" else [3, 1, 2, 0][s % 4]], 0.5, 0.5), 0.12)
    for bar, beat, note in MENU_MELODY:
        tr.add("lead", bar * 4 + beat, kalimba(note, 1.0), 0.45)
    rhythm_b = [(0, 1), (1, .5), (1.5, .5), (2, 1.5), (3.5, .5)]
    for bar, beat, dur, note in chord_line(chords[8:], rhythm_b, 91, 72, 88, start=79):
        tr.add("lead", (bar + 8) * 4 + beat, kalimba(note, 1.0), 0.45)
    sc = tr.sidechain(kicks, depth=0.35, rel=0.25)
    tr.buses["lead"] = delay(tr.buses["lead"], tr.beat * 0.75, 0.3, 0.3)[: tr.length + tr.tail]
    mix = {"kick": 0.8, "shaker": 0.5, "clap": 0.6, "pad": 0.5, "bass": 0.55, "arp": 0.6, "lead": 0.8}
    return finish(tr, mix, sc, ("pad", "bass"), {"pad": 0.35, "lead": 0.35, "arp": 0.4}, 1.2, 0.75)


# ─────────────────────────────────────────────────────────────
THEMES = {
    "menu": (menu, [None]),
    "rush_pop": (rush_pop, ["play", "tense", "fever"]),
    "rush_wave": (rush_wave, ["play", "tense", "fever"]),
    "rush_chip": (rush_chip, ["play", "tense", "fever"]),
    "stage_five": (stage_five, ["calm", "tense"]),
    "stage_seven": (stage_seven, ["calm", "tense"]),
    "stage_nine": (stage_nine, ["calm", "tense"]),
}


def write_ogg(path: str, x: np.ndarray) -> None:
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "x.wav")
        write_wav(wav, x)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", OGG_QUALITY, path], check=True)
    print(f"  → {os.path.basename(path):24s} {os.path.getsize(path) / 1024:6.0f}KB")


def main(names: list[str]) -> None:
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name in names or THEMES:
        fn, layers = THEMES[name]
        for layer in layers:
            ga.RNG = np.random.default_rng(zlib.crc32(f'{name}:{layer}'.encode()))  # 다시 만들어도 같은 소리
            x = fn() if layer is None else fn(layer)
            file = name if layer is None else f"{name}_{layer}"
            write_ogg(os.path.join(MUSIC_DIR, f"{file}.ogg"), x)


if __name__ == "__main__":
    main(sys.argv[1:])
