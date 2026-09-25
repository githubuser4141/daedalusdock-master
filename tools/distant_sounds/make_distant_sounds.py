"""
Bakes how loud sounds sound from far off, for playsound() and playsound_distant() (mojave/code/game/distant_sound.dm).

Every loud sound in CATEGORIES gets two versions: "far" (a few dozen tiles off: dulled, the crack softened, a reverb
tail and a couple of echoes off the land) and "distant" (the edge of hearing: a low thump, mostly echo, rolling on for
seconds). Then it writes the list the game picks them from, with how far each kind of sound carries. Any playsound() of
a listed sound carries that far on its own.

Run it from the repository root after adding a gun, shooter, engine or monster with a new sound:
    pip install -r tools/distant_sounds/requirements.txt
    python tools/distant_sounds/make_distant_sounds.py
It only bakes what isn't baked yet (the encoder never writes the same bytes twice). After changing TIERS, rebake all of
them with --rebake, or just the sounds whose path contains some text with --rebake explosion.
"""

import glob
import os
import re
import sys
import zlib

import numpy as np
import soundfile as sf
from scipy import signal

OUT_DIR = "mojave/sound/ms13distant"
DM_FILE = "mojave/code/game/distant_sound_versions.dm"
CODE = glob.glob("mojave/**/*.dm", recursive=True) + glob.glob("code/modules/projectiles/**/*.dm", recursive=True)

# How each kind of loud sound is found, how far it carries (in SOUND_RANGEs) and how it's baked. First match wins.
# "code" is a pattern for where the code gives a sound to something; "files" are globs of sound files.
CATEGORIES = [
    dict(name="artillery", reach=16, bake="explosion", files=["mojave/sound/ms13vehicles/artillery_outgoing.ogg"]),
    dict(name="explosion", reach=16, bake="explosion", files=[
        "sound/effects/explosion[123].ogg", "mojave/sound/ms13effects/explosion_fire_grenade.ogg",
        "mojave/sound/wip/necromorphs/exploder_blast_1.ogg", "mojave/modules/lavalandmob/sounds/boom.ogg"]),
    dict(name="heavy gunfire", reach=10, bake="gunfire", files=["mojave/sound/ms13vehicles/*.ogg"],
         code=r"fire_sound\s*=\s*'(mojave/sound/ms13vehicles/[^']+)'"),
    dict(name="gunfire", reach=8, bake="gunfire", files=["mojave/sound/ms13npc/sentrybot/*_fire.ogg", "mojave/sound/ms13npc/sentrybot/laser_gatling.ogg"],
         code=r"(?:fire_sound|projectilesound|fallback_fire_sound)\s*=\s*'([^']+\.(?:ogg|wav))'"),
    dict(name="hivemind", reach=6, bake="gunfire", files=[
        "mojave/sound/wip/necromorphs/*.ogg", "mojave/sound/by_nc/tgmc_xenomorphs/*.ogg"]),
    dict(name="monster", reach=5, bake="gunfire", files=[
        f"mojave/sound/ms13npc/{kind}_*.ogg" for kind in ("genericclaw", "yaoguai", "mirelurk", "radscorp", "hellpig", "radstag", "ghoul")]),
    dict(name="engine", reach=5, bake="gunfire", files=[
        "mojave/sound/ms13machines/engine_*.ogg", "sound/effects/tank_treads.ogg", "sound/mecha/mechstep.ogg"]),
    dict(name="structure", reach=3, bake="gunfire", files=[
        # meteorimpact.ogg is DD's sound for a creature smashing anything, not only meteors.
        "sound/weapons/smash.ogg", "sound/effects/meteorimpact.ogg", "sound/effects/glassbr[123].ogg", "sound/effects/break_stone.ogg",
        "mojave/sound/ms13effects/*_door_hit.ogg", "mojave/sound/ms13effects/*_door_break.ogg",
        "mojave/sound/ms13effects/glass_*.ogg", "mojave/sound/ms13effects/impact/**/*.wav"],
         code=r"hitted_sound\s*=\s*'([^']+\.(?:ogg|wav))'"),
]

TIERS = {
    # rate, low-pass (cutoff, steepness), crack smear (length, share), reverb (time to fade 60 dB, pre-delay, level),
    # echoes (delay, level, low-pass), dry level
    "gunfire": {
        "far": dict(rate=32000, lowpass=3500, order=2, smear=0.004, smear_mix=0.3, rt60=1.6, predelay=0.03, wet=0.5,
                    echoes=[(0.22, 0.4, 2200), (0.55, 0.25, 1500)], dry=0.9),
        "distant": dict(rate=22050, lowpass=1100, order=4, smear=0.02, smear_mix=0.6, rt60=2.8, predelay=0.07, wet=0.85,
                        echoes=[(0.33, 0.45, 900), (0.78, 0.32, 700), (1.3, 0.2, 550), (2.0, 0.12, 450)], dry=0.5),
    },
    # A blast rolls round the land for longer, and deeper.
    "explosion": {
        "far": dict(rate=32000, lowpass=2200, order=2, smear=0.01, smear_mix=0.4, rt60=3.0, predelay=0.05, wet=0.7,
                    echoes=[(0.4, 0.45, 1400), (1.0, 0.3, 1000), (1.8, 0.2, 800)], dry=0.8),
        "distant": dict(rate=22050, lowpass=600, order=4, smear=0.04, smear_mix=0.7, rt60=4.5, predelay=0.1, wet=0.95,
                        echoes=[(0.6, 0.5, 500), (1.4, 0.38, 420), (2.3, 0.26, 350), (3.4, 0.16, 300)], dry=0.45),
    },
}


def find_sources():
    """Sound file -> the category it belongs to."""
    texts = {path: open(path, encoding="utf-8", errors="replace").read() for path in CODE if path.replace("\\", "/") != DM_FILE}
    found = {}
    for category in CATEGORIES:
        sounds = set()
        for pattern in category.get("files", []):
            sounds.update(path.replace("\\", "/") for path in glob.glob(pattern, recursive=True))
        if "code" in category:
            for text in texts.values():
                sounds.update(re.findall(category["code"], text))
        for sound in sounds:
            # Suppressed shots don't carry, and distant recordings are already a far version of something.
            if os.path.exists(sound) and "suppressed" not in sound and "/distant_shots/" not in sound and not sound.startswith(OUT_DIR):
                found.setdefault(sound, category)
    return dict(sorted(found.items()))


def lowpass(x, cutoff, rate, order=4):
    sos = signal.butter(order, min(cutoff, rate * 0.45), "low", fs=rate, output="sos")
    return signal.sosfilt(sos, x)


def bake(x, rate, t, seed):
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
    last = int(max(d for d, _, _ in t["echoes"]) * rate * 1.1)
    out = np.zeros(max(len(direct) + last, len(reverb)))
    out[: len(direct)] += t["dry"] * direct
    out[: len(reverb)] += t["wet"] * reverb / max(np.abs(reverb).max(), 1e-9) * np.abs(direct).max()
    for delay, level, cutoff in t["echoes"]:
        echo = lowpass(direct, cutoff, rate, order=2)
        start = int(delay * rate * rng.uniform(0.9, 1.1))
        out[start : start + len(echo)] += level * echo[: len(out) - start]
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
    rebake = sys.argv[2] if len(sys.argv) > 2 else "" if "--rebake" in sys.argv else None
    entries = []
    for source, category in find_sources().items():
        versions = [f"{OUT_DIR}/{tier}/{slug(source)}.ogg" for tier in TIERS[category["bake"]]]
        entries.append((source, category, versions))
        if all(os.path.exists(v) for v in versions) and (rebake is None or rebake not in source):
            continue
        x, rate = sf.read(source, always_2d=True)
        x = x.mean(axis=1)
        for (tier, settings), target in zip(TIERS[category["bake"]].items(), versions):
            out, out_rate = bake(x, rate, settings, zlib.crc32(f"{source}{tier}".encode()))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            sf.write(target, out.astype(np.float32), out_rate, format="OGG", subtype="VORBIS")
        print(f"baked {category['name']}: {source}")
    with open(DM_FILE, "w", encoding="utf-8", newline="\n") as dm:
        dm.write("// Generated by tools/distant_sounds/make_distant_sounds.py. Rerun it after adding a loud sound.\n")
        dm.write("/// Sound played nearby -> list(how it sounds far off, how it sounds at the edge of hearing, how far off it's heard).\n")
        dm.write("/// See playsound_distant().\n")
        dm.write("GLOBAL_LIST_INIT(distant_sound_versions, list(\n")
        for source, category, (far, distant) in entries:
            dm.write(f"\t\"{source}\" = list('{far}', '{distant}', SOUND_RANGE * {category['reach']}), // {category['name']}\n")
        dm.write("))\n")
    print(f"{len(entries)} sounds baked.")
    baked = {v for _, _, versions in entries for v in versions}
    for stale in sorted(p.replace("\\", "/") for p in glob.glob(f"{OUT_DIR}/**/*.ogg", recursive=True)):
        if stale not in baked:
            print(f"No longer baked, safe to delete: {stale}")


if __name__ == "__main__":
    main()
