"""Batch the four remaining supplied goblins using the accepted 128px style.

Stages are deliberately separate so the source and pixel faces can be visually
reviewed before local repair. Picxel itself performs palette/grid conversion.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import math
import re
import shutil
import sys
import subprocess

from PIL import Image, ImageDraw, ImageFont

from pixelize_goblin_review import extract


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/previews/goblin_reprint"
BASE = SOURCE / "picxel_expressions_128"
APPROVED = SOURCE / "picxel_128_review"
SKILL = Path.home() / ".codex/skills/picxel"
sys.path.insert(0, str(SKILL / "scripts"))

STATES = [
    (1, "goblin_smile", "微笑", "2a8f934ed281300e751bc057f673eff3468b92348e1cbb970ece64ebffa8dcc0",
     "Sly closed-mouth smile with an asymmetric raised corner; low upper eyelids and angled brows.",
     "Forward and slightly downward under half-closed upper lids; irises near the centre of each opening, with narrow sclera at both sides."),
    (2, "goblin_displeased", "不悦", "7116bdcaf3eef4a85ea617135e702d212497500f0425b78515f00ab449385bd7",
     "Displeased, brows lowered inward, narrowly open eyes and a tense downturned closed mouth.",
     "Forward under lowered lids; pupils near the centre, narrow white crescents below and at the sides. Preserve the squint."),
    (3, "goblin_delighted", "欣喜", "2dda9c966d209824d0082e89eb5d3b46959e05bb0c8fb1926eb45ebe56560395",
     "Delighted, eyes wider with bright golden irises, raised brows and a broad open grin showing teeth and small fangs.",
     "Open eyes looking forward, dark pupils toward the upper-middle of the golden irises. Preserve the larger sclera areas and the brow asymmetry."),
    (4, "goblin_downcast", "失落", "e4be135b5d3e259a1b75273bc1ccd2baad223a90cb33db260c3e45b94a320ff2",
     "Downcast and worried, inward-raised brows, uneven drooping lids and a downturned closed mouth.",
     "Forward with pupils slightly inward and toward the upper part of the open eyes; visible sclera beneath and beside the irises. Retain the worried eyelid asymmetry.")
]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def prepare():
    for directory in ("refs", "concepts", "work"):
        (BASE / directory).mkdir(parents=True, exist_ok=True)
    template = read_json(APPROVED / "refs/goblin.anchor.json")
    originals = {int(re.search(r"\((\d+)\)", p.stem).group(1)): p
                 for p in SOURCE.glob("*.png") if "(" in p.stem}
    records = []
    for index, stem, label, expected, expression, gaze in STATES:
        path = originals[index]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == expected, "Source changed; recheck masking coordinates"
        shutil.copy2(path, BASE / "refs" / f"{stem}.png")
        anchor = copy.deepcopy(template)
        anchor["subject"] = template["subject"] + " Expression: " + expression
        anchor["keep"][3] = expression
        anchor["faces"][0].update(expression=expression, gaze=gaze,
                                  reason="Inspect this expression separately; the monocle, lids and iris may merge during grid voting.")
        write_json(BASE / "refs" / f"{stem}.anchor.json", anchor)
        records.append({"name": stem, "label": label, "source": str(path.relative_to(ROOT)), "sha256": digest})
    write_json(BASE / "sources.json", {"states": records,
               "approved_default_sha256": hashlib.sha256((APPROVED / "work/goblin-128.png").read_bytes()).hexdigest(),
               "palette": template["palette"], "method": "Same original-derived local Picxel workflow as the approved default; no image model."})
    print("Prepared four original references and expression-specific anchors.")


def extract_sources():
    records = []
    for _, stem, _, expected, _, _ in STATES:
        path = BASE / "refs" / f"{stem}.png"
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
        image = Image.open(path).convert("RGB")
        assert image.size == (1536, 1536)
        # The source inspection confirmed both seeds lie in pink paper for
        # each image. Recheck numerically before reusing the extraction helper.
        for point in ((500, 1190), (1090, 1220)):
            rgb = image.getpixel(point)
            assert min(rgb) > 168 and max(rgb) - min(rgb) < 65
        result = extract(image)
        box = result.getbbox()
        block = math.ceil(max(box[2] - box[0], box[3] - box[1]) / 126)
        assert block == 12, "Keep the same 12 source-pixels/output-pixel scale as the approved default"
        result.save(BASE / "concepts" / f"{stem}.png")
        records.append({"name": stem, "bbox": box, "source_pixels_per_output_pixel": block,
                        "offset": [(128 * block - (box[2] - box[0])) // 2,
                                   (128 * block - (box[3] - box[1])) // 2]})
    write_json(BASE / "concepts/extraction.json", {"image_model_used": False, "states": records})
    print(json.dumps(records))


def refine():
    from px import Grid
    from picxel import check, load, render

    work = BASE / "work"
    framing = {r["name"]: r for r in read_json(BASE / "concepts/extraction.json")["states"]}
    # Main chain paths traced from each original, in source-image coordinates.
    chains = {
        "goblin_smile": [(641, 1010), (650, 1080), (678, 1160), (718, 1216), (767, 1250), (810, 1264), (846, 1259), (892, 1225), (932, 1178), (963, 1124), (978, 1082)],
        "goblin_displeased": [(641, 1005), (651, 1080), (679, 1161), (720, 1217), (765, 1250), (809, 1264), (846, 1256), (894, 1223), (933, 1177), (963, 1123), (978, 1080)],
        "goblin_delighted": [(642, 1020), (653, 1096), (681, 1171), (722, 1225), (766, 1262), (810, 1278), (850, 1270), (895, 1233), (934, 1187), (965, 1133), (978, 1094)],
        "goblin_downcast": [(641, 1013), (653, 1085), (680, 1163), (720, 1218), (765, 1254), (810, 1270), (848, 1262), (892, 1228), (934, 1182), (965, 1130), (978, 1088)],
    }
    # Only details lost in grid voting: small warm irises and dark pupils.
    # Each expression retains its own eyelid opening, gaze and readable mouth.
    eyes = {
        "goblin_smile": [([53, 51, 57, 51], ["LBSLL"]), ([71, 49, 74, 49], ["SBLL"])],
        "goblin_displeased": [([54, 51, 56, 51], ["LSL"]), ([71, 49, 74, 49], ["BSLW"])],
        "goblin_delighted": [([52, 51, 57, 52], ["LLSBBC", "LLBGLL"]), ([70, 50, 74, 50], ["LSBLL"])],
        "goblin_downcast": [([55, 50, 56, 51], ["LS", "BG"]), ([72, 49, 74, 50], ["LSL", "BGL"])],
    }
    for _, stem, _, _, _, _ in STATES:
        grid, meta, colors = Grid.load(work / f"{stem}-128.pxg")
        symbol = {value: key for key, value in colors.items()}
        before = copy.deepcopy(grid.g)
        brass, shadow = symbol["#af8a4b"], symbol["#695033"]
        for y in range(44, 58):
            for x in range(46, 62):
                if not (52 <= x <= 58 and 49 <= y <= 53) and grid.g[y][x] == shadow:
                    grid.put(brass, (x, y))
        info = framing[stem]
        points = [((x - info["bbox"][0] + info["offset"][0]) // 12,
                   (y - info["bbox"][1] + info["offset"][1]) // 12)
                  for x, y in chains[stem]]
        for start, end in zip(points, points[1:]):
            grid.line(*start, *end, brass)
        grid.put(symbol["#e2c180"], points[3], points[5], points[8])
        assert all((before[y][x] == ".") == (grid.g[y][x] == ".")
                   for y in range(128) for x in range(128)), "Repair changed alpha silhouette"
        detail = work / f"{stem}-128-detail.pxg"
        grid.write(detail, detail.stem, "sprite", colors, palette=meta["palette"])
        assert not check(load(detail))[0]
        render(load(detail), work)
        aliases = {"L": "#f2eedb", "W": "#dedec6", "S": "#695033", "B": "#af8a4b",
                   "G": "#e2c180", "C": "#969f97"}
        patches = [{"face": 0, "feature": "eye", "box": box,
                    "rows": ["".join(symbol[aliases[c]] for c in row) for row in rows]}
                   for box, rows in eyes[stem]]
        patch = work / f"{stem}.face.json"
        write_json(patch, {"source": detail.stem, "size": 128, "patches": patches})
        subprocess.run([sys.executable, "-B", str(SKILL / "scripts/picxel.py"), "face", str(detail),
                        "--anchor", str(BASE / "refs" / f"{stem}.anchor.json"), "--patch", str(patch)], check=True)


def deliver():
    from picxel import check, load

    work = BASE / "work"
    report = read_json(work / "batch-report.json")
    provenance = read_json(BASE / "sources.json")
    approved = APPROVED / "work/goblin-128.png"
    assert hashlib.sha256(approved.read_bytes()).hexdigest() == provenance["approved_default_sha256"]
    palette = {tuple(bytes.fromhex(c[1:])) for c in provenance["palette"]}
    (work / "base").mkdir(exist_ok=True)
    checks = []
    for _, stem, _, expected, _, _ in STATES:
        assert hashlib.sha256((BASE / "refs" / f"{stem}.png").read_bytes()).hexdigest() == expected
        original = ROOT / next(r["source"] for r in provenance["states"] if r["name"] == stem)
        assert hashlib.sha256(original.read_bytes()).hexdigest() == expected
        final_stem = f"{stem}-128-detail-face"
        final = work / f"{final_stem}.pxg"
        errors, warnings = check(load(final))
        assert not errors, errors
        image = Image.open(work / f"{final_stem}.png").convert("RGBA")
        assert image.size == (128, 128)
        pixels = list(image.getdata())
        assert {p[3] for p in pixels} == {0, 255}
        assert {p[:3] for p in pixels if p[3]} <= palette
        assert image.getbbox()[0] > 0 and image.getbbox()[1] > 0
        assert image.getbbox()[2] < 128 and image.getbbox()[3] < 128
        detail = Image.open(work / f"{stem}-128-detail.png").convert("RGBA")
        plan = read_json(work / f"{stem}.face.json")
        boxes = [p["box"] for p in plan["patches"]]
        for y in range(128):
            for x in range(128):
                assert image.getpixel((x, y))[3] == detail.getpixel((x, y))[3]
                if image.getpixel((x, y)) != detail.getpixel((x, y)):
                    assert any(a <= x <= c and b <= y <= d for a, b, c, d in boxes)
        for suffix in (".pxg", ".png", "@4x.png"):
            base = work / f"{stem}-128{suffix}"
            if not (work / "base" / base.name).exists():
                shutil.copy2(base, work / "base" / base.name)
            if suffix != ".pxg":
                shutil.copyfile(work / f"{final_stem}{suffix}", base)
        entry = next(j for j in report["jobs"] if j["name"] == stem)
        entry.update(sheets=[final.name], base_sheets=[f"base/{stem}-128.pxg"],
                     problems=[f"128: (warn) {w}" for w in warnings],
                     assistant_review="reviewed: silhouette, original gaze, mouth and accessories; user review pending")
        entry["face_review"] = [{"sheet": final.name, "status": "reviewed",
                                  "patch": f"{stem}.face.json", "mouth": "preserved"}]
        checks.append({"name": stem, "size": [128, 128], "colors": len({p[:3] for p in pixels if p[3]}),
                       "alpha": [0, 255], "errors": errors, "warnings": warnings,
                       "warning_review": "Isolated colors are small face, hair, finger, metal and fabric details; preserved to match the approved style.",
                       "final_sheet": final.name, "sha256": hashlib.sha256((work / f"{stem}-128.png").read_bytes()).hexdigest()})
    report["provenance"] = "Original-derived local Picxel conversion with targeted accessory/eye pixel repairs; no image model calls."
    write_json(work / "batch-report.json", report)
    write_json(BASE / "validation.json", {"approved_default_unchanged": True, "sources_unchanged": True, "assets": checks})

    cards = [("默认 · 已确认", approved)] + [(label, work / f"{stem}-128.png") for _, stem, label, _, _, _ in STATES]
    canvas = Image.new("RGB", (1400, 526), "#1d242b")
    draw = ImageDraw.Draw(canvas)
    font_path = "C:/Windows/Fonts/msyh.ttc"
    font = ImageFont.truetype(font_path, 22)
    small = ImageFont.truetype(font_path, 16)
    draw.text((24, 15), "哥布林表情 · 128×128 · 共用 16 色 · 透明 PNG", font=font, fill="#ece8cf")
    for index, (label, path) in enumerate(cards):
        x = index * 280 + 12
        draw.text((x + 128, 57), label, font=font, fill="#eeeacf", anchor="mt")
        for y in range(96, 352, 16):
            for cx in range(x, x + 256, 16):
                draw.rectangle((cx, y, cx + 15, y + 15), fill=("#28313a" if ((cx - x) // 16 + (y - 96) // 16) % 2 else "#252d35"))
        im = Image.open(path).convert("RGBA")
        enlarged = im.resize((256, 256), Image.Resampling.NEAREST)
        canvas.paste(enlarged, (x, 96), enlarged)
        canvas.paste(im, (x + 64, 370), im)
        draw.text((x + 128, 502), "上：2 倍预览　下：原尺寸", font=small, fill="#aeb9bb", anchor="mt")
    canvas.save(BASE / "goblin-expressions-review.png")
    (BASE / "README.md").write_text(
        "# 哥布林表情素材（128×128）\n\n"
        "沿用已确认默认表情的原图提取、Picxel 像素化和局部修整流程，共用 16 色，透明度仅 0/255。"
        "四张均从各自高清原图处理；保留原图表情、姿势与视线，补回金链、镜框和少量瞳孔细节。\n\n"
        "- 微笑：`work/成品图/goblin_smile-128.png`\n"
        "- 不悦：`work/成品图/goblin_displeased-128.png`\n"
        "- 欣喜：`work/成品图/goblin_delighted-128.png`\n"
        "- 失落：`work/成品图/goblin_downcast-128.png`\n\n"
        "五表情对照：`goblin-expressions-review.png`。上排 2 倍最近邻放大，下排原尺寸；"
        "默认表情沿用之前已确认文件，内容未修改。可编辑版本为 `work/*-128-detail-face.pxg`。\n\n"
        "这是本地原图像素后处理，没有调用图片生成模型；本次未替换游戏内资源。"
        "`sources.json` 记录来源，`validation.json` 记录尺寸、色板、透明度及完整性检查。\n",
        encoding="utf-8")
    print("Validated four final assets; wrote five-expression comparison. Run Picxel job done to export clean PNGs.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("prepare", "extract", "refine", "deliver"))
    args = parser.parse_args()
    {"prepare": prepare, "extract": extract_sources, "refine": refine, "deliver": deliver}[args.stage]()


if __name__ == "__main__":
    main()
