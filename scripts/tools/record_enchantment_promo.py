"""Capture the finance enchantment promo on a private desktop and export MP4."""

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
    parser.add_argument("--output", type=Path, default=Path(tempfile.gettempdir()) / "enchantment_promo_20261022_v2")
    parser.add_argument("--encode-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        parser.error("ffmpeg and ffprobe must be on PATH")
    if not args.encode_only:
        engine = find_godot(args.godot)
        run([sys.executable, PROJECT / "scripts/tools/run_godot_background.py",
             "--godot", engine, "--log", output / "capture.log", "--timeout", "240", "--",
             "--path", PROJECT, "--scene", "res://scenes/debug/enchantment_promo.tscn",
             "--resolution", "1920x1080", "--fixed-fps", "60",
             "--write-movie", output / "gameplay.avi", "--",
             "--transient-session", f"--capture-dir={output.as_posix()}"])
    report = json.loads((output / "report.json").read_text(encoding="utf-8"))
    desktop = json.loads((output / "capture.json").read_text(encoding="utf-8"))
    log = (output / "capture.log").read_text(encoding="utf-8")
    assert "SCRIPT ERROR" not in log and "\nERROR:" not in log, "Godot reported a capture error"
    assert report["failures"] == [], report["failures"]
    assert desktop["exit_code"] == 0 and desktop["foreground_samples"] == 0
    assert desktop["private_desktop"] == desktop["verified_desktop"]
    assert report["audio"]["bgm_muted"] and report["audio"]["bgm_db"] == -80.0
    assert abs(report["audio"]["sfx_db"] - 2.0) < 0.001  # Game's 100% bus gain.
    assert report["final_attachments"] == ["scroll_multishot", "scroll_electric_spark", "scroll_wisdom"]
    assert report["initial_backpack_left_to_right"] == list(reversed(report["final_attachments"]))
    flights = [event for event in report["events"] if event["action"] == "flight"]
    landings = [event for event in report["events"] if event["action"] == "land"]
    assert [event["source_column"] for event in flights] == [3, 2, 1]
    assert [event["target_slot"] for event in flights] == [1, 2, 3]
    assert all(flights[i + 1]["frame"] == landings[i]["frame"] - report["overlap_frames"] for i in range(2))
    start = report["start_frame"]
    end = start + report["frames"]
    fps = report["fps"]
    destination = output / "enchantment_promo.mp4"
    graph = (f"[0:v]trim=start_frame={start}:end_frame={end},setpts=N/({fps}*TB)[v];"
             f"[0:a]atrim=start={start / fps}:end={end / fps},asetpts=PTS-STARTPTS[a]")
    run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", output / "gameplay.avi",
         "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
         "-r", str(fps), "-fps_mode", "cfr",
         "-c:v", "libx264", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart", destination])
    probe = json.loads(subprocess.check_output(
        [ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", str(destination)],
        encoding="utf-8"))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in probe["streams"] if stream["codec_type"] == "audio")
    assert (video["width"], video["height"]) == (1920, 1080)
    assert int(video["nb_frames"]) == report["frames"]
    assert abs(float(video["duration"]) - report["frames"] / fps) < 0.02
    assert audio["codec_name"] == "aac"
    (output / "export.json").write_text(json.dumps(probe, indent=2), encoding="utf-8")
    print(destination)


if __name__ == "__main__":
    main()
