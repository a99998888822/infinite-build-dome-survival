"""Capture the two native goblin death taunts in a disposable game session."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from record_enchantment_pickups import encode

PROJECT = Path(__file__).resolve().parents[2]
SCENE = "res://scenes/debug/goblin_death_promo.tscn"
NAMES = {"followed": "01_goblin_death_followed.mp4", "refused": "02_goblin_death_refused.mp4"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--take", choices=["all", *NAMES], default="all")
    parser.add_argument("--mode", choices=["headless", "record", "encode"], default="headless")
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/goblin_death_promo_20261024")
    parser.add_argument("--godot", default="D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--ffmpeg", type=Path, default=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"))
    args = parser.parse_args()
    for take in NAMES if args.take == "all" else [args.take]:
        output = args.output.resolve() / take
        output.mkdir(parents=True, exist_ok=True)
        if args.mode != "encode":
            logpath = output / ("headless.log" if args.mode == "headless" else "capture.log")
            if args.mode == "headless":
                command = [args.godot, "--headless", "--path", str(PROJECT), "--scene", SCENE, "--fixed-fps", "60", "--quit-after", "3000"]
            else:
                command = [sys.executable, str(PROJECT / "scripts/tools/run_godot_background.py"), "--godot", args.godot,
                           "--log", str(logpath), "--timeout", "180", "--", "--path", str(PROJECT), "--scene", SCENE,
                           "--resolution", "1920x1080", "--fixed-fps", "60", "--write-movie", str(output / "gameplay.avi")]
            command += ["--", "--transient-session", f"--take={take}", f"--capture-dir={output.as_posix()}"]
            if args.mode == "headless":
                with logpath.open("w", encoding="utf-8") as log:
                    result = subprocess.run(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, timeout=150)
            else:
                result = subprocess.run(command, cwd=PROJECT, timeout=200)
            log = logpath.read_text(encoding="utf-8")
            dummy = (args.mode == "headless" and log.count("\nERROR:") == 1
                     and 'ERROR: Parameter "t" is null.' in log
                     and "rendering/dummy/storage/texture_storage.h:85" in log
                     and "scripts/ui/character_select_view.gd:605" in log)
            if dummy: print("HEADLESS_RENDERER_DIAGNOSTIC", logpath, flush=True)
            if result.returncode or any(s in log for s in ["SCRIPT ERROR", "Parse Error", "Compile Error"]) or ("\nERROR:" in log and not dummy):
                print(log[-6500:])
                return 1
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        assert not report["failures"], report["failures"]
        assert report["receipt"]["reaction"] == "death_" + take
        assert report["audio"]["bgm_muted"] and report["audio"]["bgm_db"] == -80 and report["audio"]["sfx_db"] == 2
        if args.mode != "headless":
            capture = json.loads((output / "capture.json").read_text(encoding="utf-8"))
            assert capture["foreground_samples"] == 0 and capture["exit_code"] == 0
            assert capture["private_desktop"] == capture["verified_desktop"]
        print("VALID", take, "frames", report["frames"], "reaction_row", report["reaction_row"], flush=True)
        if args.mode in ["record", "encode"]:
            encode(output, args.output.resolve() / NAMES[take], report, args.ffmpeg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
