"""Capture the combat opening on a private Windows desktop."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from open_recording_studio import find_godot

PROJECT = Path(__file__).resolve().parents[2]


def run(command):
    subprocess.run([str(value) for value in command], cwd=PROJECT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--output", type=Path, default=Path(tempfile.gettempdir()) / "combat_opening_20261024_v4")
    parser.add_argument("--encode-only", action="store_true")
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    ffmpeg, ffprobe = shutil.which("ffmpeg"), shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        parser.error("ffmpeg and ffprobe must be on PATH")
    if not args.encode_only:
        command = [sys.executable, PROJECT / "scripts/tools/run_godot_background.py",
                   "--godot", find_godot(args.godot), "--log", output / "capture.log", "--timeout", "240", "--",
                   "--path", PROJECT, "--scene", "res://scenes/debug/combat_opening_promo.tscn",
                   "--resolution", "1920x1080", "--fixed-fps", "60"]
        if not args.preview:
            command += ["--write-movie", output / "gameplay.avi"]
        command += ["--", "--transient-session", f"--capture-dir={output.as_posix()}"]
        run(command)
    report = json.loads((output / "report.json").read_text(encoding="utf-8"))
    desktop = json.loads((output / "capture.json").read_text(encoding="utf-8"))
    log = (output / "capture.log").read_text(encoding="utf-8")
    assert "SCRIPT ERROR" not in log and "\nERROR:" not in log, "Godot capture errors"
    assert report["failures"] == [], report["failures"]
    assert desktop["exit_code"] == 0 and desktop["foreground_samples"] == 0
    assert desktop["private_desktop"] == desktop["verified_desktop"]
    assert report["projectiles"] == 5 and report["shots"] >= 4
    assert report["spacing"]["contact_frames"] == []
    assert report["spacing"]["return_min_visual_gap"] >= 8.0
    assert report["audio"]["bgm_muted"] and report["audio"]["bgm_db"] == -80.0
    assert abs(report["audio"]["sfx_db"] - 2.0) < 0.001
    if args.preview:
        print(output / "report.json")
        return
    start, fps, count = report["start_frame"], report["fps"], report["frames"]
    destination = output / "combat_opening.mp4"
    graph = (f"[0:v]trim=start_frame={start}:end_frame={start+count},setpts=N/({fps}*TB)[v];"
             f"[0:a]atrim=start={start/fps}:end={(start+count)/fps},asetpts=PTS-STARTPTS[a]")
    run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", output / "gameplay.avi",
         "-filter_complex", graph, "-map", "[v]", "-map", "[a]", "-r", fps, "-fps_mode", "cfr",
         "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", destination])
    probe = json.loads(subprocess.check_output([ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", str(destination)], encoding="utf-8"))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in probe["streams"] if stream["codec_type"] == "audio")
    assert (video["width"], video["height"]) == (1920, 1080)
    assert int(video["nb_frames"]) == count
    assert abs(float(video["duration"]) - count / fps) < 0.02
    assert audio["codec_name"] == "aac"
    (output / "export.json").write_text(json.dumps(probe, indent=2), encoding="utf-8")
    print(destination)


if __name__ == "__main__":
    main()
