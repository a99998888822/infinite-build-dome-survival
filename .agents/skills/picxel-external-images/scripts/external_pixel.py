"""External files -> Picxel grids -> reviewed PNGs. No model client or provider."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile

SKILL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SKILL / "vendor/picxel/scripts"))
from PIL import Image, ImageOps
import picxel as px
import panel


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def fingerprint(path):
    path = Path(path).resolve()
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def matching_job(out):
    job = panel.load_job()
    if not job or Path(job["export"]).resolve() != out.resolve():
        raise ValueError("This output is not the active external-image panel job")
    return job


def checked_sheet(path, size):
    sheet = px.load(path)
    if sheet.size != size:
        raise ValueError("Selected grid size differs from requested size")
    errors, warnings = px.check(sheet)
    if errors:
        raise ValueError("; ".join(errors))
    image = sheet.image().convert("RGBA")
    if not set(image.getchannel("A").tobytes()) <= {0, 255}:
        raise ValueError("Final alpha must be binary")
    return sheet, warnings


def build(args):
    refs, out = args.refs.resolve(), args.out.resolve()
    if refs == out or refs in out.parents:
        raise ValueError("Output must be separate from the references")
    anchors = sorted(refs.glob("*.anchor.json"))
    only = getattr(args, "only", None)
    if only is not None:
        available = {p.name[:-len(".anchor.json")] for p in anchors}
        if not only or set(only) - available:
            raise ValueError("--only must name existing assets: " + ", ".join(sorted(available)))
        anchors = [p for p in anchors if p.name[:-len(".anchor.json")] in only]
    if not 1 <= len(anchors) <= 20:
        raise ValueError("Need 1-20 annotated external images")
    if (out / "batch-report.json").exists() or list(out.glob("*.pxg")) or list(out.glob("*.png")):
        raise ValueError("Output already contains a run; use select/finish or a new revision directory")
    items = []
    fingerprints = []
    for anchor_path in anchors:
        name = anchor_path.name[:-len(".anchor.json")]
        candidates = [p for p in refs.iterdir() if p.stem == name and p.suffix.lower() in panel.IMAGE_SUFFIXES]
        if len(candidates) != 1:
            raise ValueError(f"Need one external reference for {name}")
        original = candidates[0]
        prepared = args.prepared_dir / f"{name}.png" if args.prepared_dir else original
        if not prepared.is_file():
            raise FileNotFoundError(prepared)
        if out == prepared.resolve().parent or out in prepared.resolve().parents:
            raise ValueError("Prepared inputs must be outside the output directory")
        anchor = px.load_anchor(anchor_path)
        items.append((name, original, prepared, anchor))
        fingerprints.extend(fingerprint(p) for p in {original, prepared, anchor_path})
    sizes = sorted(set(args.sizes), reverse=True)
    panel.save_job({"import": str(refs), "export": str(out),
                          "mode": "single" if len(items) == 1 else "batch",
                          "files": [p.name for _, p, _, _ in items], "sizes": sizes})
    panel.set_status(out, "running", "External images: local pixel processing")
    report = {"provider": "external-file", "image_model_used": False, "jobs": [], "inputs": fingerprints}
    if only is not None:
        report["selected"] = sorted(set(only))
    failed = False
    for name, original, prepared, anchor in items:
        entry = {"name": name, "status": "base-ready", "review": "pending", "sheets": [],
                 "problems": [], "face_review": [], "selected": {}, "source": str(original),
                 "prepared_source": str(prepared), "sizes": sizes}
        report["jobs"].append(entry)
        try:
            with Image.open(prepared) as source:
                image = px._strip_background(ImageOps.exif_transpose(source).convert("RGBA"), args.background)
            if image.getchannel("A").getbbox() is None:
                raise ValueError("Background processing removed the entire subject")
            # Legacy panel filename; this is the prepared external source, not a generated concept.
            image.save(out / f"{name}.concept.png")
            palette = px._palette_from_image(image, 16, anchor)
            (out / f"{name}.pal").write_text("\n".join(palette) + "\n", encoding="utf-8")
            for size in sizes:
                sheet = px._import_image(image, size, f"{name}-{size}", anchor["kind"], f"{name}.pal", palette)
                sheet.path = out / f"{name}-{size}.pxg"
                px.smooth_sheet(sheet, 1, "")
                used = {c for row in sheet.rows for c in row}
                sheet.colors = {c: v for c, v in sheet.colors.items() if c in used}
                sheet.path.write_text(sheet.dump(), encoding="utf-8")
                _, warnings = checked_sheet(sheet.path, size)
                px.render(sheet, out)
                entry["sheets"].append(sheet.path.name)
                entry["problems"].extend(f"{size}: (warn) {w}" for w in warnings)
                if anchor.get("faces"):
                    complex_face = any(f["complex"] for f in anchor["faces"])
                    face = {"sheet": sheet.path.name, "status": "needs-face-review" if complex_face else "preserve"}
                    if complex_face:
                        prompt = out / f"{name}-{size}.face-prompt.txt"
                        prompt.write_text(px.face_prompt(anchor, size), encoding="utf-8")
                        face["prompt"] = prompt.name
                    entry["face_review"].append(face)
        except (OSError, ValueError) as exc:
            entry.update(status="failed")
            entry["problems"].append(str(exc))
            failed = True
    report["previews"] = px.review_overview(report["jobs"], out)
    write(out / "batch-report.json", report)
    if failed:
        panel.set_status(out, "interrupted", "Some external images failed; inspect batch-report.json")
    print(json.dumps({"output": str(out), "assets": len(items), "failed": failed,
                      "previews": report["previews"], "next": "Inspect images, select every size, then finish"}))
    return 1 if failed else 0


def select(args):
    out = args.out.resolve()
    matching_job(out)
    report = read(out / "batch-report.json")
    entry = next((e for e in report["jobs"] if e["name"] == args.name), None)
    if not entry or args.size not in entry["sizes"] or entry["status"] != "base-ready":
        raise ValueError("Unknown or unsuccessful asset/size")
    path = args.sheet.resolve()
    if out not in path.parents or path.suffix != ".pxg":
        raise ValueError("Selected editable grid must be inside the task output")
    sheet, warnings = checked_sheet(path, args.size)
    palette = set((out / f"{args.name}.pal").read_text(encoding="utf-8").splitlines())
    if not set(sheet.colors.values()) <= palette:
        raise ValueError("Selected grid changed the asset palette")
    stem = f"{args.name}-{args.size}"
    backup = out / "base"
    backup.mkdir(exist_ok=True)
    for suffix in (".pxg", ".png", "@4x.png"):
        base = out / (stem + suffix)
        if base.exists() and not (backup / base.name).exists():
            shutil.copy2(base, backup / base.name)
    # Render under the expected panel filename without rewriting the selected grid.
    preview = px.Sheet(path.stem, sheet.size, sheet.kind, sheet.palette, sheet.colors, sheet.rows, path)
    px.render(preview, path.parent)
    selected = px.Sheet(stem, sheet.size, sheet.kind, sheet.palette, sheet.colors, sheet.rows, path)
    px.render(selected, out)
    entry["selected"][str(args.size)] = {"sheet": path.relative_to(out).as_posix(), "note": args.note,
                                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    entry["sheets"] = [entry["selected"].get(str(n), {}).get("sheet", f"{args.name}-{n}.pxg") for n in entry["sizes"]]
    for face in entry["face_review"]:
        if px.load(out / face["sheet"]).size == args.size:
            face.update(sheet=path.relative_to(out).as_posix(), status="reviewed")
    entry["review"] = "assistant-reviewed" if len(entry["selected"]) == len(entry["sizes"]) else "pending"
    entry["problems"] = [p for p in entry["problems"] if not p.startswith(f"{args.size}: (warn)")]
    entry["problems"].extend(f"{args.size}: (warn) {w}" for w in warnings)
    write(out / "batch-report.json", report)
    print(f"Selected {args.name}/{args.size}; user style review remains independent")
    return 0


def reviewed_sheets(out):
    """Verify the selected deliverables without changing panel state."""
    report = read(out / "batch-report.json")
    selected = []
    for record in report["inputs"]:
        if fingerprint(record["path"])["sha256"] != record["sha256"]:
            raise ValueError("Input changed after conversion: " + record["path"])
    for entry in report["jobs"]:
        if entry["status"] != "base-ready" or entry["review"] != "assistant-reviewed":
            raise ValueError("Asset still needs visual review: " + entry["name"])
        for size in entry["sizes"]:
            chosen = entry["selected"][str(size)]
            path = out / chosen["sheet"]
            sheet, _ = checked_sheet(path, size)
            if hashlib.sha256(path.read_bytes()).hexdigest() != chosen["sha256"]:
                raise ValueError("Grid changed after visual review; select it again")
            with Image.open(out / f"{entry['name']}-{size}.png") as png:
                if png.size != (size, size) or png.convert("RGBA").tobytes() != sheet.image().convert("RGBA").tobytes():
                    raise ValueError("Final PNG differs from selected grid")
            selected.append((f"{entry['name']}-{size}", sheet))
    return report, selected


def finish(args):
    out = args.out.resolve()
    job = matching_job(out)
    report, _ = reviewed_sheets(out)
    report["previews"] = px.review_overview(report["jobs"], out)
    write(out / "batch-report.json", report)
    panel.set_status(out, "done", "External image conversion and assistant visual review complete")
    scan = panel.scan_results(job)
    if scan["done"] != scan["total"]:
        raise ValueError("Panel output count does not match the requested batch")
    print(json.dumps({"done": scan["done"], "total": scan["total"], "delivery": str(out / panel.FINISHED_DIR)}))
    return 0


def review(args):
    out = args.out.resolve()
    report = read(out / "batch-report.json")
    report["previews"] = px.review_overview(report["jobs"], out)
    write(out / "batch-report.json", report)
    print(json.dumps({"previews": report["previews"]}))
    return 0


def sheet(args):
    out = args.out.resolve()
    _, selected = reviewed_sheets(out)
    destination = (args.destination or out / "dist").resolve()
    if destination == out or destination in out.parents:
        raise ValueError("Atlas output must be separate from the task files")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("Atlas output must be a new or empty directory")
    if not selected:
        raise ValueError("No reviewed assets to pack")
    # Upstream sheet scans every .pxg. Stage only selected versions, so base and
    # intermediate edits cannot leak into the atlas or replace the final frame.
    with tempfile.TemporaryDirectory(prefix="picxel-selected-") as folder:
        stage = Path(folder)
        for name, source in selected:
            path = stage / f"{name}.pxg"
            normalized = px.Sheet(name, source.size, source.kind, "custom", source.colors, source.rows, path)
            path.write_text(normalized.dump(), encoding="utf-8")
        px.build_sheet(stage, destination, args.columns)
    return 0


def adopt_job(args):
    """Copy panel choices into this skill, leaving the source job/status alone."""
    source = args.job.resolve()
    if source == panel.JOB_FILE.resolve():
        raise ValueError("Already using the project job; use picxel.py job show")
    job = read(source)
    destination = args.out.resolve()
    original_export = Path(job["export"]).resolve()
    original_import = Path(job["import"]).resolve()
    if (destination == original_export or destination in original_export.parents
            or original_export in destination.parents
            or destination == original_import or destination in original_import.parents
            or original_import in destination.parents):
        raise ValueError("Use a separate output directory for the project job")
    if destination.exists() and (not destination.is_dir() or any(destination.iterdir())):
        raise ValueError("Project output must be a new or empty directory")
    job["export"] = str(destination)
    result = panel.save_job(job)
    print(json.dumps(result, ensure_ascii=True))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("build")
    p.add_argument("refs", type=Path)
    p.add_argument("-o", "--out", type=Path, required=True)
    p.add_argument("--sizes", type=int, choices=(32, 64, 128), nargs="+", default=[128])
    p.add_argument("--prepared-dir", type=Path)
    p.add_argument("--background", default="none")
    p.add_argument("--only", nargs="+", help="process named assets in a new revision directory")
    p = commands.add_parser("select")
    p.add_argument("out", type=Path)
    p.add_argument("--name", required=True)
    p.add_argument("--size", type=int, choices=(32, 64, 128), required=True)
    p.add_argument("--sheet", type=Path, required=True)
    p.add_argument("--note", required=True)
    p = commands.add_parser("review", help="refresh previews without converting images")
    p.add_argument("out", type=Path)
    p = commands.add_parser("sheet", help="pack only verified, selected grids")
    p.add_argument("out", type=Path)
    p.add_argument("-o", "--destination", type=Path)
    p.add_argument("--columns", type=int, default=8)
    p = commands.add_parser("adopt-job", help="copy another panel's choices to a separate project output")
    p.add_argument("job", type=Path)
    p.add_argument("-o", "--out", type=Path, required=True)
    for command in ("finish", "stop"):
        p = commands.add_parser(command)
        p.add_argument("out", type=Path)
        if command == "stop":
            p.add_argument("--note", required=True)
    args = parser.parse_args()
    try:
        if args.command == "stop":
            matching_job(args.out)
            panel.set_status(args.out.resolve(), "interrupted", args.note)
            return 0
        return {"build": build, "select": select, "finish": finish,
                "review": review, "sheet": sheet, "adopt-job": adopt_job}[args.command](args)
    except (OSError, ValueError, KeyError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
