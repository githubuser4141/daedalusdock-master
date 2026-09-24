"""
Bakes how gunfire and other loud sounds sound from far off, for playsound_distant() (mojave/code/game/distant_sound.dm).

For every sound the game fires shots with, it writes two versions: "far" (a few dozen tiles off: dulled, the crack
softened, a reverb tail and a couple of echoes off the land) and "distant" (the edge of hearing: a low thump, mostly
echo, rolling on for seconds). Then it writes the list the game picks them from.

Run it from the repository root after adding a gun or shooter with a new sound:
    pip install -r tools/distant_sounds/requirements.txt
    python tools/distant_sounds/make_distant_sounds.py
"""

import glob
import os
import re
import zlib

import numpy as np
import soundfile as sf
from scipy import signal

OUT_DIR = "mojave/sound/ms13distant"
DM_FILE = "mojave/code/game/distant_sound_versions.dm"

# Where a sound is given to something that fires, or played distant directly.
SOURCE_PATTERNS = [
    r"(?:fire_sound|projectilesound|fallback_fire_sound)\s*=\s*'([^']+\.(?:ogg|wav))'",
    r"playsound_distant\([^,]+,\s*'([^']+\.(?:ogg|wav))'",
]

TIERS = {
    # rate, low-pass (cutoff, steepness), crack smear (length, share), reverb (time to fade 60 dB, pre-delay, level),
    # echoes (delay, level, low-pass), dry level
    "far": dict(rate=32000, lowpass=3500, order=2, smear=0.004, smear_mix=0.3, rt60=1.6, predelay=0.03, wet=0.5,
                echoes=[(0.22, 0.4, 2200), (0.55, 0.25, 1500)], dry=0.9),
    "distant": dict(rate=22050, lowpass=1100, order=4, smear=0.02, smear_mix=0.6, rt60=2.8, predelay=0.07, wet=0.85,
                    echoes=[(0.33, 0.45, 900), (0.78, 0.32, 700), (1.3, 0.2, 550), (2.0, 0.12, 450)], dry=0.5),
}


def find_sources():
    sources = set()
    # Mojave's shooters, and DD's guns and ammo, whose sounds anything that doesn't set its own falls back on.
    for path in glob.glob("mojave/**/*.dm", recursive=True) + glob.glob("code/modules/projectiles/**/*.dm", recursive=True):
        if path.replace("\\", "/") == DM_FILE:
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        for pattern in SOURCE_PATTERNS:
            sources.update(re.findall(pattern, text))
    # Distant recordings are already a far version of something.
    return sorted(s for s in sources if os.path.exists(s) and "/distant_shots/" not in s and not s.startswith(OUT_DIR))


def lowpass(x, cutoff, rate, order=4):
    sos = signal.butter(order, min(cutoff, rate * 0.45), "low", fs=rate, output="sos")
    return signal.sosfilt(sos, x)


def bake(x, rate, tier, seed):
    t = TIERS[tier]
    x = signal.resample_poly(x, t["rate"], rate)
    rate = t["rate"]
    rng = np.random.default_rng(seed)
    # Air takes the top off, and the ground takes out the rumble below hearing.
    direct = lowpass(x, t["lowpass"], rate, t["order"])
    direct = signal.sosfilt(signal.butter(2, 40, "high", fs=rate, output="sos"), direct)
    # The crack arrives smeared rather than sharp.
    smear = np.exp(-np.arange(int(t["smear"] * rate) + 1) / (t["smear"] * rate / 3))
    smeared = np.convolve(direct, smear / smear.sum())[: len(direct)]
    direct = (1 - t["smear_mix"]) * direct + t["smear_mix"] * smeared / max(np.abs(smeared).max(), 1e-9) * np.abs(direct).max()
    # Reverb: decaying noise, duller as it goes.
    length = int((t["predelay"] + t["rt60"]) * rate)
    tail = rng.standard_normal(length) * np.exp(-6.9 * np.arange(length) / (t["rt60"] * rate))
    tail[: int(t["predelay"] * rate)] = 0
    tail = lowpass(tail, t["lowpass"] * 0.7, rate, order=2)
    reverb = signal.fftconvolve(direct, tail / np.sqrt((tail ** 2).sum()))
    # Echoes off hills and buildings: later, fainter and duller each time.
    last = int(max(d for d, _, _ in t["echoes"]) * rate)
    out = np.zeros(max(len(direct) + last, len(reverb)))
    out[: len(direct)] += t["dry"] * direct
    out[: len(reverb)] += t["wet"] * reverb / max(np.abs(reverb).max(), 1e-9) * np.abs(direct).max()
    for delay, level, cutoff in t["echoes"]:
        echo = lowpass(direct, cutoff, rate, order=2)
        start = int(delay * rate * rng.uniform(0.9, 1.1))
        out[start : start + len(echo)] += level * echo
    # Trim what's too faint to hear, fade out the last of it, and level it.
    peak = np.abs(out).max()
    audible = np.where(np.abs(out) > peak * 10 ** (-55 / 20))[0]
    out = out[: audible[-1] + 1] if len(audible) else out
    fade = min(len(out), int(0.08 * rate))
    out[-fade:] *= np.linspace(1, 0, fade)
    return out / peak * 0.9, rate


def slug(path):
    return re.sub(r"[^A-Za-z0-9_]+", "_", os.path.splitext(path.replace("mojave/sound/", ""))[0]).strip("_")


def main():
    sources = find_sources()
    entries = []
    for source in sources:
        x, rate = sf.read(source, always_2d=True)
        x = x.mean(axis=1)
        versions = []
        for tier in TIERS:
            out, out_rate = bake(x, rate, tier, zlib.crc32(f"{source}{tier}".encode()))
            target = f"{OUT_DIR}/{tier}/{slug(source)}.ogg"
            os.makedirs(os.path.dirname(target), exist_ok=True)
            sf.write(target, out.astype(np.float32), out_rate, format="OGG", subtype="VORBIS")
            versions.append(target)
        entries.append((source, versions))
        print(f"{source} -> {', '.join(versions)}")
    with open(DM_FILE, "w", encoding="utf-8", newline="\n") as dm:
        dm.write("// Generated by tools/distant_sounds/make_distant_sounds.py. Rerun it after adding a gun or shooter with a new sound.\n")
        dm.write("/// Sound played nearby -> list(how it sounds far off, how it sounds at the edge of hearing). See playsound_distant().\n")
        dm.write("GLOBAL_LIST_INIT(distant_sound_versions, list(\n")
        for source, (far, distant) in entries:
            dm.write(f"\t\"{source}\" = list('{far}', '{distant}'),\n")
        dm.write("))\n")
    print(f"{len(entries)} sounds baked.")


if __name__ == "__main__":
    main()
