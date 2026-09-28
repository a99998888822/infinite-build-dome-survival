"""Restore observed brass and eye details in the fresh 128px Picxel import."""
from pathlib import Path
import json
import sys


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "artifacts/previews/goblin_reprint/picxel_128_review/work"
sys.path.insert(0, str(Path.home() / ".codex/skills/picxel/scripts"))
from px import Grid
from picxel import load, render, check


def main():
    grid, meta, colors = Grid.load(WORK / "goblin-128.pxg")
    symbol = {value: key for key, value in colors.items()}
    brass_shadow = symbol["#695033"]
    brass = symbol["#af8a4b"]
    glint = symbol["#e2c180"]
    # Lift the existing ring's brass pixels, keeping its source-derived shape.
    grid.replace(brass_shadow, brass, (46, 44, 61, 56))
    # Restore the source chain as a single-pixel curve: its thin links lost the
    # grid majority vote. Coordinates were checked against the source crop/pad.
    points = [(55, 85), (55, 89), (56, 94), (58, 98), (61, 101),
              (65, 103), (68, 103), (72, 101), (75, 98), (77, 94), (78, 89)]
    for start, end in zip(points, points[1:]):
        grid.line(*start, *end, brass)
    grid.put(glint, (58, 98), (59, 99), (65, 103), (66, 103), (76, 96))
    path = WORK / "goblin-128-detail.pxg"
    grid.write(path, "goblin-128-detail", "sprite", colors, palette=meta["palette"])
    sheet = load(path)
    errors, _ = check(sheet)
    assert not errors, errors
    render(sheet, WORK)

    light, dark = symbol["#f2eedb"], symbol["#141b20"]
    plan = {
        "source": "goblin-128-detail", "size": 128,
        "patches": [
            {"face": 0, "feature": "eye", "box": [53, 51, 56, 51],
             "rows": [light + brass + brass_shadow + light],
             "eyes": [{"box": [53, 51, 56, 51], "light": light, "dark": brass_shadow}]},
            {"face": 0, "feature": "eye", "box": [70, 49, 73, 49],
             "rows": [dark + dark + brass + light],
             "eyes": [{"box": [70, 49, 73, 49], "light": light, "dark": dark}]}
        ]
    }
    (WORK / "goblin.face.json").write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
    print("Restored monocle/chain pixels; prepared two narrow eye patches.")


if __name__ == "__main__":
    main()
