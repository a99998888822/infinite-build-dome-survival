"""Install the exact files selected by audio_list.txt; preserve sources and backups."""
from pathlib import Path
from array import array
import argparse
import hashlib
import json
import shutil
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/sources/audio_user_20261018/audio"
MANIFEST = ROOT / "scripts/tools/audio_sources/user_audio_manifest.json"
MAPPING = {
    "player_walk.mp3": "player/player_walk.wav",
    "A_heavy_cast-iron_ca_#4-1792331487179.mp3": "combat/grenade_launch_01.wav",
    "A_massive_heavy_weap_#3-1792331588194.mp3": "combat/mutant_tentacle_hit.wav",
    "A_massive_heavy_weap_#1-1792331700630.mp3": "combat/meteor_flail_hit.wav",
    "a-jet-of-flame-burst-4-1792332089511_AvOv45Yx.mp3": "combat/copper_lamp_loop.wav",
    "a-mystical-arcane-ma-2-1792332332366_JJ1ksidH.mp3": "combat/ritual_mark_r02_01.wav",
    "An_artillery_shell_d_#2-1792332486020.mp3": "combat/explosion_01.wav",
    "a-glowing-blade-of-l-3-1792332939896_jfOalrme.mp3": "combat/light_sword_01.wav",
    "Wind_spreads_water_i_#4-1792333557716.mp3": "combat/water_01.wav",
    "Light_strikes_a_froz_#4-1792333231104.mp3": "combat/reaction_reflection_01.wav",
    "A_burst_of_freezing__#1-1792333264169.mp3": "combat/reaction_ice_expand_01.wav",
    "the_sound_of_Water_h_#1-1792333478631.mp3": "combat/reaction_steam_01.wav",
    "A_frozen_body_shatte_#3-1792333519093.mp3": "combat/reaction_thaw_01.wav",
    "Wind_spreads_water_i_#2-1792333582542.mp3": "combat/reaction_wet_spread_01.wav",
    "a-low-burning-fire-p-1-1792334585674_EJsGkaT6.mp3": "combat/fire_01.wav",
    "a-heavy-cloth-or-rop-4-1792334766253_qIVB8fdm.mp3": "combat/wind_01.wav",
    "a-tiny-high-voltage-3-1792334962145_xCgDDwFD.mp3": "combat/plasma_hit_01.wav",
}
# Always trim the decoded original, so reimporting never halves an edited file again.
KEEP_START_FRACTIONS = {"combat/fire_01.wav": 0.5}


def apply_source_edit(target, relative):
    if relative not in KEEP_START_FRACTIONS:
        return {}
    with wave.open(str(target), "rb") as audio:
        params = audio.getparams()
        assert params.nchannels == 1 and params.sampwidth == 2
        kept_frames = int(params.nframes * KEEP_START_FRACTIONS[relative])
        samples = array("h", audio.readframes(kept_frames))
    # Tiny edge fades prevent the new loop splice from adding a sharp click.
    fade_frames = min(round(params.framerate * 0.003), kept_frames // 2)
    for i in range(fade_frames):
        gain = i / max(fade_frames - 1, 1)
        samples[i] = round(samples[i] * gain)
        samples[-1-i] = round(samples[-1-i] * gain)
    with wave.open(str(target), "wb") as audio:
        audio.setparams(params)
        audio.writeframes(samples.tobytes())
    return {"keep_start_fraction": KEEP_START_FRACTIONS[relative], "decoded_source_seconds": params.nframes / params.framerate, "retained_frames": kept_frames, "edge_fade_ms": 3}


def source_owned(path):
    if not MANIFEST.exists():
        return False
    relative = Path(path).resolve().relative_to(ROOT).as_posix()
    return any(row["asset"] == relative for row in json.loads(MANIFEST.read_text(encoding="utf-8"))["sounds"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--only", choices=sorted(MAPPING.values()), help="Reimport one selected asset, preserving other installed files")
    args = parser.parse_args()
    if not args.ffmpeg:
        parser.error("Provide --ffmpeg")
    if args.only and not MANIFEST.exists():
        parser.error("--only requires an existing import manifest")
    descriptions = dict(line.split(maxsplit=1) for line in (SOURCE / "audio_list.txt").read_text(encoding="utf-8").splitlines() if line.strip())
    assert all(name in descriptions and (SOURCE / name).is_file() for name in MAPPING)
    previous = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    rows = {row["asset"]: row for row in previous.get("sounds", [])}
    installed = 0
    for filename, relative in MAPPING.items():
        if args.only and relative != args.only:
            continue
        original = SOURCE / filename
        target = ROOT / "assets/audio/sfx" / relative
        backup = SOURCE.parent / "previous_wav" / relative
        if target.exists() and not backup.exists() and not source_owned(target):
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([args.ffmpeg, "-v", "error", "-y", "-i", str(original), "-ar", "48000", "-ac", "1", "-c:a", "pcm_s16le", "-map_metadata", "-1", str(target)], check=True)
        processing = apply_source_edit(target, relative)
        with wave.open(str(target), "rb") as audio:
            seconds = audio.getnframes() / audio.getframerate()
        row = {"source": original.relative_to(ROOT).as_posix(), "description": descriptions[filename], "asset": target.relative_to(ROOT).as_posix(), "source_sha256": hashlib.sha256(original.read_bytes()).hexdigest(), "asset_sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "seconds": seconds}
        if processing:
            row["processing"] = processing
        rows[row["asset"]] = row
        installed += 1
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    rows["assets/audio/sfx/combat/fire_01.wav"]["status"] = "disabled"
    MANIFEST.write_text(json.dumps({"mapping_source": (SOURCE / "audio_list.txt").relative_to(ROOT).as_posix(), "conversion": "48 kHz mono PCM16; no normalization; per-asset edits recorded in processing", "disabled_cues": ["reaction_cancel", "fire", "reaction_holy", "reaction_dark_flame"], "sounds": [rows["assets/audio/sfx/" + relative] for relative in MAPPING.values()]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"installed": installed, "manifest": str(MANIFEST)}))


if __name__ == "__main__":
    main()
