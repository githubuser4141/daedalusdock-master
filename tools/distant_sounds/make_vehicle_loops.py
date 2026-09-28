"""Rebuild short movement loops from recordings already shipped with the game.

Uses the existing distant-sound tool's numpy, scipy and soundfile dependencies.
Run from the repository root. Assertions check the encoded outputs too.
"""
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

RATE = 32000
FADE = int(0.08 * RATE)
LENGTH = 2 * RATE + FADE
OUT = Path("mojave/sound/ms13machines")


def recording(path):
    samples, rate = sf.read(path, always_2d=True)
    samples = samples.mean(axis=1)
    return signal.resample_poly(samples, RATE, rate)


def excerpt(path, start):
    samples = recording(path)
    result = samples[int(start * RATE):int(start * RATE) + LENGTH]
    assert len(result) == LENGTH, path
    return result


def write_loop(name, samples):
    samples = samples - samples.mean()
    samples *= 0.7 / max(np.max(np.abs(samples)), 0.001)
    blend = np.linspace(0, 1, FADE)
    samples[-FADE:] = samples[-FADE:] * (1 - blend) + samples[:FADE] * blend
    samples = samples[FADE:]
    assert np.isfinite(samples).all() and len(samples) == 2 * RATE
    path = OUT / name
    sf.write(path, samples, RATE, subtype="VORBIS")
    decoded, rate = sf.read(path)
    assert rate == RATE and len(decoded) == 2 * RATE
    assert np.isfinite(decoded).all() and 0.005 < np.sqrt(np.mean(decoded**2)) < 0.5
    assert np.max(np.abs(decoded)) < 0.95
    print(f"{path}: 2 seconds, mono, decoded without clipping")


if __name__ == "__main__":
    write_loop("vehicle_road_loop.ogg", excerpt(OUT / "buggy_loop.ogg", 2))
    # Slow metal clatter with a lower motor bed, rather than the light wheel rattle.
    tracks = signal.resample(recording("sound/effects/tank_treads.ogg"), LENGTH)
    motor = excerpt(OUT / "generator_on.ogg", 2)
    motor = signal.sosfilt(signal.butter(2, 450, fs=RATE, output="sos"), motor)
    write_loop("vehicle_rail_loop.ogg", tracks * 0.65 + motor * 0.35)
    write_loop("vehicle_blast_door_loop.ogg", excerpt(OUT / "doorgear_open.ogg", 5))
