"""Rehearse/capture four promotion pickups using the real combat and finance UI."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from open_recording_studio import find_godot

PROJECT = Path(__file__).resolve().parents[2]
SPECS = {
    "before": ("res://scenes/debug/enchantment_combat_pickups.tscn", ["--take=before"], "01_unenchanted_pressure.mp4"),
    "enchant": ("res://scenes/debug/enchantment_promo.tscn", ["--spear"], "02_spear_enchantment.mp4"),
    "hammer": ("res://scenes/debug/enchantment_combat_pickups.tscn", ["--take=hammer"], "03_six_hammers_lightning.mp4"),
    "spear": ("res://scenes/debug/enchantment_combat_pickups.tscn", ["--take=spear"], "04_spear_split_chains.mp4"),
}


def validate(output, mode):
    report = json.loads((output / "report.json").read_text(encoding="utf-8"))
    log = (output / ("headless.log" if mode == "headless" else "capture.log")).read_text(encoding="utf-8")
    assert not any(word in log for word in ["SCRIPT ERROR", "Parse Error", "Compile Error", "\nERROR:"]), log[-4500:]
    assert report["failures"] == [], report["failures"]
    audio = report["audio"]
    assert audio["bgm_muted"] and audio["bgm_db"] == -80.0 and abs(audio["sfx_db"] - 2.0) < 0.001
    if mode != "headless":
        desktop = json.loads((output / "capture.json").read_text(encoding="utf-8"))
        assert desktop["exit_code"] == 0 and desktop["foreground_samples"] == 0
        assert desktop["private_desktop"] == desktop["verified_desktop"]
    if "final_attachments" in report:
        assert report["final_attachments"] == ["scroll_multishot", "scroll_split", "scroll_lightning"]
        assert report["projectiles"] == 3 and report["weapon_level"] == 5
    else:
        assert report["frames"] == (600 if report["take"] == "before" else 180)
        assert report["casts"] == (5 if report["take"] == "before" else 1)
        if report["take"] != "before":
            assert abs(report["range_after"] - report["range_before"] - 100) < 0.001
        clicks = [e["button"] for e in report["events"] if e["action"] == "click"]
        assert 1 in clicks and 2 in clicks
    return report


def encode(output, destination, report, ffmpeg):
    start, count, fps = report["start_frame"], report["frames"], report["fps"]
    graph = (f"[0:v]trim=start_frame={start}:end_frame={start+count},setpts=N/({fps}*TB)[v];"
             f"[0:a]atrim=start={start/fps}:end={(start+count)/fps},asetpts=PTS-STARTPTS[a]")
    subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y", "-i", str(output / "gameplay.avi"),
                    "-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-r", str(fps), "-fps_mode", "cfr",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", str(destination)], check=True)
    ffprobe = ffmpeg.with_name("ffprobe.exe" if sys.platform == "win32" else "ffprobe")
    probe = json.loads(subprocess.check_output([str(ffprobe), "-v", "error", "-show_streams", "-show_format", "-of", "json", str(destination)], encoding="utf-8"))
    video = next(s for s in probe["streams"] if s["codec_type"] == "video")
    audio = next(s for s in probe["streams"] if s["codec_type"] == "audio")
    assert (video["width"], video["height"], int(video["nb_frames"])) == (1920, 1080, count)
    assert abs(float(video["duration"]) - count / fps) < 0.02 and audio["codec_name"] == "aac"
    (output / "export.json").write_text(json.dumps(probe, indent=2), encoding="utf-8")
    print("EXPORTED", destination, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/enchantment_pickups_20261024_v2")
    parser.add_argument("--take", choices=["all", *SPECS], default="all")
    parser.add_argument("--mode", choices=["headless", "preview", "record", "encode"], default="headless")
    parser.add_argument("--ffmpeg", type=Path)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--calibrate-hammer", action="store_true")
    args = parser.parse_args()
    if args.calibrate_hammer and (args.mode != "headless" or args.take != "hammer"):
        parser.error("Hammer calibration is a headless rehearsal, not a recording/export")
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    engine = find_godot(args.godot)
    ffmpeg = args.ffmpeg or (Path(shutil.which("ffmpeg")) if shutil.which("ffmpeg") else None)
    if args.mode in ["record", "encode"] and not ffmpeg:
        parser.error("Set --ffmpeg to the encoder executable")
    failed = False
    for name in SPECS if args.take == "all" else [args.take]:
        scene, extra, filename = SPECS[name]
        output = root / name
        output.mkdir(parents=True, exist_ok=True)
        try:
            if args.mode != "encode":
                command = [str(engine), "--headless", "--path", str(PROJECT), "--scene", scene, "--fixed-fps", "60", "--quit-after", "10000"]
                if args.mode != "headless":
                    command = [sys.executable, str(PROJECT / "scripts/tools/run_godot_background.py"),
                               "--godot", str(engine), "--log", str(output / "capture.log"), "--timeout", "240", "--",
                               "--path", str(PROJECT), "--scene", scene, "--resolution", "1920x1080", "--fixed-fps", "60"]
                    if args.mode == "record": command += ["--write-movie", str(output / "gameplay.avi")]
                if args.verbose: command += ["--verbose"]
                if args.calibrate_hammer and name == "hammer": extra = [*extra, "--calibrate-hammer"]
                command += ["--", "--transient-session", f"--capture-dir={output.as_posix()}", *extra]
                if args.mode == "headless":
                    with (output / "headless.log").open("w", encoding="utf-8") as log:
                        result = subprocess.run(command, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, timeout=150)
                else:
                    result = subprocess.run(command, cwd=PROJECT, timeout=260)
                if result.returncode:
                    log = output / ("headless.log" if args.mode == "headless" else "capture.log")
                    raise RuntimeError(log.read_text(encoding="utf-8")[-5500:])
            report = validate(output, args.mode)
            print("VALID", name, {key: report.get(key) for key in ["frames", "kills", "shards", "chains", "ground_strikes", "hp_start", "hp_end"]}, flush=True)
            if args.mode in ["record", "encode"]:
                encode(output, root / filename, report, ffmpeg)
        except (AssertionError, RuntimeError, subprocess.SubprocessError) as error:
            failed = True
            print("FAILED", name, str(error), flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
