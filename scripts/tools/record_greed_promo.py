"""Record two greed-themed pickups and the authentic post-buyout consequence."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from open_recording_studio import find_godot
from record_enchantment_pickups import encode

PROJECT = Path(__file__).resolve().parents[2]
SCENE = "res://scenes/debug/greed_promo.tscn"
NAMES = {"night": "01_one_more_coin.mp4", "sale": "02_sell_the_best_weapon.mp4", "cost": "03_price_of_the_deal.mp4"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["headless", "preview", "record", "encode"], default="headless")
    parser.add_argument("--take", choices=["all", *NAMES], default="all")
    parser.add_argument("--godot", default="D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--ffmpeg", type=Path, default=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"))
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/greed_promo_20261024")
    args = parser.parse_args()
    engine = find_godot(args.godot)
    for take in NAMES if args.take == "all" else [args.take]:
        output = args.output.resolve() / take
        output.mkdir(parents=True, exist_ok=True)
        if args.mode != "encode":
            command = [str(engine), "--headless", "--path", str(PROJECT), "--scene", SCENE, "--fixed-fps", "60", "--quit-after", "3000"]
            logpath = output / "headless.log"
            if args.mode != "headless":
                logpath = output / "capture.log"
                command = [sys.executable, str(PROJECT / "scripts/tools/run_godot_background.py"),
                           "--godot", str(engine), "--log", str(logpath), "--timeout", "240", "--",
                           "--path", str(PROJECT), "--scene", SCENE, "--resolution", "1920x1080", "--fixed-fps", "60"]
                if args.mode == "record": command += ["--write-movie", str(output / "gameplay.avi")]
            command += ["--", "--transient-session", f"--take={take}", f"--capture-dir={output.as_posix()}"]
            if args.mode == "headless":
                with logpath.open("w", encoding="utf-8") as log:
                    result = subprocess.run(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, timeout=150)
            else:
                result = subprocess.run(command, cwd=PROJECT, timeout=260)
            log = logpath.read_text(encoding="utf-8")
            # Known Godot dummy-renderer startup issue in the unrelated camp UI.
            # Keep its evidence; GPU captures must always be completely clean.
            diagnostic = (args.mode == "headless" and log.count("\nERROR:") == 1
                          and 'ERROR: Parameter "t" is null.' in log
                          and "rendering/dummy/storage/texture_storage.h:85" in log
                          and "scripts/ui/talent_node_button.gd:19" in log)
            if diagnostic: print("HEADLESS_RENDERER_DIAGNOSTIC", logpath, flush=True)
            if result.returncode or any(error in log for error in ["SCRIPT ERROR", "Parse Error", "Compile Error"]) or ("\nERROR:" in log and not diagnostic):
                print(log[-6500:])
                return 1
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        assert not report["failures"], report["failures"]
        assert report["audio"]["bgm_muted"] and report["audio"]["bgm_db"] == -80.0
        assert abs(report["audio"]["sfx_db"] - 2.0) < 0.001
        if args.mode != "headless":
            desktop = json.loads((output / "capture.json").read_text(encoding="utf-8"))
            assert desktop["exit_code"] == 0 and desktop["foreground_samples"] == 0
            assert desktop["verified_desktop"] == desktop["private_desktop"]
        print("VALID", take, {key: report.get(key) for key in ["frames", "gold_start", "gold_end", "hp_end", "kills", "sold_bundle"]}, flush=True)
        if args.mode in ["record", "encode"]:
            encode(output, args.output.resolve() / NAMES[take], report, args.ffmpeg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
