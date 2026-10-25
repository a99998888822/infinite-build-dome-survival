"""Import, capture and package the furnace/saber visual candidates."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import shutil

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/previews/new_weapon_art_20261025"
GODOT = Path("D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe")
SCENE = "res://scenes/debug/new_weapon_art_review.tscn"
ASSETS = ROOT / "assets/sprites/weapons/candidates/furnace_saber_v1"


def run(mode, only):
    target = OUT / ("bake" if mode == "bake" else "headless" if mode == "headless" else "capture")
    target.mkdir(parents=True, exist_ok=True)
    common = ["--path", str(ROOT), "--scene", SCENE, "--resolution", "1280x720", "--fixed-fps", "60"]
    if mode == "headless":
        command = [str(GODOT), "--headless", *common, "--quit-after", "3000"]
    else:
        command = [sys.executable, str(ROOT / "scripts/tools/run_godot_background.py"),
                   "--godot", str(GODOT), "--log", str(target / "capture.log"), "--timeout", "240", "--", *common]
        if mode == "record":
            command += ["--write-movie", str(target / "review.avi")]
    command += ["--", "--transient-session", f"--capture-dir={target.as_posix()}"]
    if only:
        command += [f"--only={only}"]
    if mode == "bake":
        command += ["--bake-only"]
    if mode == "headless":
        with (target / "headless.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        logpath = target / "headless.log"
    else:
        result = subprocess.run(command, cwd=ROOT, timeout=260)
        logpath = target / "capture.log"
    log = logpath.read_text(encoding="utf-8")
    bad = [line for line in log.splitlines() if any(word in line for word in ("SCRIPT ERROR", "Parse Error", "Compile Error", "SHADER ERROR"))]
    errors = [line for line in log.splitlines() if line.startswith("ERROR:")]
    # Existing main-menu preview calls a dummy texture in headless rendering.
    known_dummy = mode == "headless" and errors == ['ERROR: Parameter "t" is null.'] and "dummy/storage/texture_storage.h" in log
    if result.returncode or bad or (errors and not known_dummy):
        print(log[-10000:])
        raise SystemExit(result.returncode or 1)
    if known_dummy:
        print("EXISTING_HEADLESS_DUMMY_TEXTURE_WARNING")
    report = json.loads((target / "report.json").read_text(encoding="utf-8"))
    if mode != "headless":
        evidence = json.loads((target / "capture.json").read_text(encoding="utf-8"))
        assert evidence["foreground_samples"] == 0
        assert evidence["private_desktop"] == evidence["verified_desktop"]
        assert evidence["exit_code"] == 0
    print("ART_REVIEW_OK", mode, "clips", len(report["clips"]), "baked", len(report["baked"]))


def package():
    capture = OUT / "capture"
    report = json.loads((capture / "report.json").read_text(encoding="utf-8"))
    labels = {
        "furnace_single": "FURNACE / SINGLE",
        "furnace_multi": "FURNACE / THREE RINGS",
        "furnace_split": "FURNACE / SPLIT FLARES",
        "saber_single": "SABER / SINGLE",
        "saber_multi": "SABER / FIVE CUTS",
        "saber_diagonal": "SABER / DIAGONAL",
    }
    board = Image.new("RGB", (1280, 1176), "#111918")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 20)
    for index, clip in enumerate(report["clips"]):
        name = clip["id"]
        start = clip["start_frame"]
        end = start + clip["frames"]
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(capture / "review.avi"),
                        "-vf", f"trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS",
                        "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "17", "-pix_fmt", "yuv420p",
                        "-movflags", "+faststart", str(OUT / f"{name}.mp4")], check=True)
        chosen = 78 if name == "furnace_split" else 61 if "saber" in name else 59 if name == "furnace_multi" else 47
        source = capture / f"{name}_{chosen:03d}.png"
        im = Image.open(source).convert("RGB")
        im.save(OUT / f"{name}.png")
        x, y = index % 2 * 640, index // 2 * 392
        board.paste(im.resize((640, 360), Image.Resampling.NEAREST), (x, y + 32))
        draw.text((x + 16, y + 7), labels[name], font=font, fill="#cddcd5")
    board.save(OUT / "overview.png")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", str(capture / "review.avi"), "-vf",
                    f"trim=start_frame={report['clips'][0]['start_frame']}:end_frame={report['clips'][-1]['start_frame'] + 180},setpts=PTS-STARTPTS",
                    "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "17", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", str(OUT / "new_weapon_art_review.mp4")], check=True)
    validate_atlases()
    (OUT / "assets").mkdir(exist_ok=True)
    for path in ASSETS.glob("*.png"):
        shutil.copy2(path, OUT / "assets" / path.name)
    shutil.copy2(ROOT / "scripts/tools/new_weapon_art_gallery.html", OUT / "index.html")
    print("ART_REVIEW_PACKAGED", OUT)


def validate_atlases():
    bake = json.loads((OUT / "bake/report.json").read_text(encoding="utf-8"))
    for row in bake["baked"]:
        path = ROOT / row["path"].removeprefix("res://")
        im = Image.open(path)
        w, h = row["frame_size"]
        assert im.mode == "RGBA" and im.size == (w * 4, h * 3)
        hashes = set()
        bounds = []
        for i in range(12):
            frame = im.crop((i % 4 * w, i // 4 * h, (i % 4 + 1) * w, (i // 4 + 1) * h))
            box = frame.getbbox()
            if box:
                assert box[0] > 0 and box[1] > 0 and box[2] < w and box[3] < h, (path.name, i, box)
            bounds.append(box)
            hashes.add(frame.tobytes())
            if path.stem == "saber_cut":
                assert frame.tobytes() == frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes(), (i, "horizontal symmetry")
                assert frame.tobytes() == frame.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes(), (i, "vertical symmetry")
        assert len(hashes) >= 8, (path.name, "animation must change")
        assert im.getchannel("A").getextrema() == (0, 255)
        row.update({"mode": im.mode, "unique_frames": len(hashes), "frame_bounds": bounds,
                    "palette_colors": len(im.getcolors(100000) or []), "alpha_verified": True})
        if path.stem == "saber_cut":
            row.update({"pivot": [192, 48], "axis_symmetry_verified": True})
    (ASSETS / "manifest.json").write_text(json.dumps(bake["baked"], indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print("ATLAS_VALIDATION_OK", len(bake["baked"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["headless", "preview", "record", "bake", "package"])
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    package() if args.mode == "package" else run(args.mode, args.only)
