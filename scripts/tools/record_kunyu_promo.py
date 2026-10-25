"""Record the Kunyu tome attachment and large-domain combat pickups."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from record_enchantment_pickups import encode

PROJECT = Path(__file__).resolve().parents[2]
SPECS = {
    "enchant": ("kunyu_enchantment_promo", "01_kunyu_enchantments.mp4"),
    "combat": ("kunyu_combat_promo", "02_kunyu_multishot_split_lightning.mp4"),
    "advance": ("kunyu_combat_promo", "03_kunyu_double_split_advance.mp4"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["headless", "preview", "record", "encode"], default="headless")
    parser.add_argument("--take", choices=["all", *SPECS], default="all")
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/kunyu_promo_20261024")
    parser.add_argument("--godot", default="D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--ffmpeg", type=Path, default=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"))
    args = parser.parse_args()
    for take in SPECS if args.take == "all" else [args.take]:
        scene, filename = SPECS[take]
        output = args.output.resolve() / take
        output.mkdir(parents=True, exist_ok=True)
        if args.mode != "encode":
            logpath = output / ("headless.log" if args.mode == "headless" else "capture.log")
            if args.mode == "headless":
                command = [args.godot, "--headless", "--path", str(PROJECT), "--scene", f"res://scenes/debug/{scene}.tscn", "--fixed-fps", "60", "--quit-after", "3000"]
            else:
                command = [sys.executable, str(PROJECT / "scripts/tools/run_godot_background.py"), "--godot", args.godot,
                           "--log", str(logpath), "--timeout", "240", "--", "--path", str(PROJECT),
                           "--scene", f"res://scenes/debug/{scene}.tscn", "--resolution", "1920x1080", "--fixed-fps", "60"]
                if args.mode == "record": command += ["--write-movie", str(output / "gameplay.avi")]
            command += ["--", "--transient-session", f"--capture-dir={output.as_posix()}"]
            if take == "advance": command += ["--advance"]
            if args.mode == "headless":
                with logpath.open("w", encoding="utf-8") as log:
                    result = subprocess.run(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, timeout=150)
            else:
                result = subprocess.run(command, cwd=PROJECT, timeout=260)
            log = logpath.read_text(encoding="utf-8")
            dummy = (args.mode == "headless" and log.count("\nERROR:") == 1 and 'ERROR: Parameter "t" is null.' in log
                     and "rendering/dummy/storage/texture_storage.h:85" in log and "scripts/ui/talent_node_button.gd:19" in log)
            if result.returncode or any(word in log for word in ["SCRIPT ERROR", "Parse Error", "Compile Error"]) or ("\nERROR:" in log and not dummy):
                print(log[-6500:])
                return 1
        report = json.loads((output / "report.json").read_text(encoding="utf-8"))
        assert not report["failures"], report["failures"]
        assert report["audio"]["bgm_db"] == -80 and report["audio"]["bgm_muted"] and report["audio"]["sfx_db"] == 2
        if take == "enchant":
            assert report["weapon"] == "weapon_kunyu_ritual_tome" and report["projectiles"] == 5
            assert report["final_attachments"] == ["scroll_multishot", "scroll_domain", "scroll_electric_spark"]
        elif take == "combat":
            assert report["player_projectiles"] == 3 and report["projectiles"] == 6
            assert report["attachments"] == ["scroll_multishot", "scroll_split", "scroll_electric_spark"]
            assert len(report["volleys"]) == 8 and all(len(v) == 3 and len(set(v)) == 3 for v in report["volleys"].values())
            assert len([c for c in report["contacts"] if c["child"]]) == 16 and report["ground_strikes"] == 16
        else:
            assert report["projectile_bonus"] == 5 and report["projectiles"] == 8
            assert report["attachments"] == ["scroll_split", "scroll_split", "scroll_electric_spark"]
            assert 8 <= len(report["volleys"]) <= 10 and all(len(v) <= 5 and len(set(v)) == len(v) for v in report["volleys"].values())
            assert report["ground_strikes"] == len([c for c in report["contacts"] if c["child"]]) and report["ground_strikes"] >= 28
            assert report["kills"] >= 36
            assert report["forward_distance"] > 300 and report["hp_end"] == report["hp_start"]
        if args.mode != "headless":
            capture = json.loads((output / "capture.json").read_text(encoding="utf-8"))
            assert capture["foreground_samples"] == 0 and capture["exit_code"] == 0
            assert capture["verified_desktop"] == capture["private_desktop"]
        print("VALID", take, {k: report.get(k) for k in ["frames", "projectiles", "kills", "volley_count", "ground_strikes"]}, flush=True)
        if args.mode in ["record", "encode"]:
            encode(output, args.output.resolve() / filename, report, args.ffmpeg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
