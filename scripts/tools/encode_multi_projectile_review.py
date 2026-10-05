"""Encode captured Godot frames without synthesizing or retiming animation."""
from pathlib import Path
import argparse
import json
import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = json.loads((args.capture / "review_report.json").read_text(encoding="utf-8"))
    desktop = json.loads((args.capture / "runtime.json").read_text(encoding="utf-8"))
    assert not report["failures"]
    assert desktop["exit_code"] == 0 and desktop["foreground_samples"] == 0
    assert desktop["verified_desktop"] == desktop["private_desktop"]
    additional_runs = []
    for runtime_path in report.get("additional_runtime_reports", []):
        run = json.loads((args.capture / runtime_path).read_text(encoding="utf-8"))
        assert run["exit_code"] == 0 and run["foreground_samples"] == 0
        assert run["verified_desktop"] == run["private_desktop"]
        additional_runs.append(run)
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {"source": str(args.capture.resolve()), "desktop": desktop, "weapons": []}
    if additional_runs:
        manifest["additional_capture_runs"] = additional_runs
    for weapon, samples in report["samples"].items():
        # One palette per clip keeps the stationary battlefield from flickering.
        atlas = Image.new("RGB", (320 * 8, 180 * 4))
        for tile in range(32):
            entry = samples[min(len(samples) - 1, tile * len(samples) // 32)]
            with Image.open(args.capture / entry["file"]) as source:
                atlas.paste(source.convert("RGB").resize((320, 180)), ((tile % 8) * 320, (tile // 8) * 180))
        background_palette = atlas.quantize(colors=128, method=Image.Quantize.MEDIANCUT)
        # Reserve half the palette for impacts and the native cool/bright colors
        # of actors and UI; unchanged blue sprites must not become gray-green.
        # This changes encoding only; all displayed pixels still come from Godot.
        with Image.open(args.capture / samples[0]["file"]) as source:
            baseline = np.array(source.convert("RGB"))[180:620:2, 430:1100:2].astype(np.int16)
        changes = []
        accents = []
        for entry in samples:
            with Image.open(args.capture / entry["file"]) as source:
                source_pixels = np.array(source.convert("RGB"))
                pixels = source_pixels[180:620:2, 430:1100:2]
            mask = np.max(np.abs(pixels.astype(np.int16) - baseline), axis=2) > 45
            changed = pixels[mask]
            if len(changed):
                changes.append(changed[::max(1, len(changed) // 1500)])
            focus = source_pixels[100:700:2, :1100:2].astype(np.int16)
            red, green, blue = focus[:, :, 0], focus[:, :, 1], focus[:, :, 2]
            accent_mask = ((blue - red > 8) & (blue >= green)) | ((red - green > 35) & (red > 130)) | (focus.min(axis=2) > 160)
            accent = focus[accent_mask].astype(np.uint8)
            if len(accent):
                accents.append(accent[::max(1, len(accent) // 2500)])
        colors = np.concatenate(changes + accents) if changes or accents else baseline.reshape(-1, 3).astype(np.uint8)
        foreground_palette = Image.fromarray(colors.reshape(1, -1, 3)).quantize(colors=128, method=Image.Quantize.MEDIANCUT)
        palette = Image.new("P", (1, 1))
        palette.putpalette(background_palette.getpalette()[:384] + foreground_palette.getpalette()[:384])
        frames = []
        durations = []
        encoded_ms = 0
        for index, sample in enumerate(samples):
            with Image.open(args.capture / sample["file"]) as source:
                frame = source.convert("RGB").resize((960, 540), Image.Resampling.NEAREST)
                frames.append(frame.quantize(palette=palette, dither=Image.Dither.NONE))
            stride = samples[-1]["tick"] - samples[-2]["tick"] if len(samples) > 1 else 3
            next_tick = samples[index + 1]["tick"] if index + 1 < len(samples) else sample["tick"] + stride
            # Carry GIF's 10ms rounding error forward instead of slowing 15fps clips.
            cumulative_ms = round((next_tick - samples[0]["tick"]) / report["physics_fps"] * 100) * 10
            duration = max(10, cumulative_ms - encoded_ms)
            durations.append(duration)
            encoded_ms += duration
        path = args.output / (weapon + ".gif")
        frames[0].save(path, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=True, disposal=1)
        with Image.open(args.capture / samples[8]["file"]) as source:
            source.save(args.output / (weapon + "_aim.png"))
        observed = [o for o in report["observations"] if o["id"] == weapon]
        ticks = [o["action_ticks"] for o in observed]
        if all("expected_seconds" in o for o in observed):
            for observation in observed:
                assert abs(observation["action_ticks"] - observation["expected_seconds"] * report["physics_fps"]) <= observation["tolerance_ticks"], observation
        else:
            assert max(ticks) - min(ticks) <= 3, (weapon, ticks)
        manifest["weapons"].append({"id": weapon, "gif": path.name, "frames": len(frames),
                                     "duration_ms": sum(durations), "observations": observed, "bytes": path.stat().st_size})
        print(weapon, len(frames), sum(durations), path.stat().st_size, flush=True)
    (args.output / "verification.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.output / "review_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
