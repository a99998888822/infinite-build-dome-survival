"""Validate current goblin atlases, or install five reviewed --source portraits.

Input names: goblin_neutral.png, goblin_downcast.png, goblin_displeased.png,
goblin_smile.png and goblin_delighted.png, each 372x372 RGBA with binary alpha.
The reviewed A+++ names worried/angry/sly/excited are accepted as aliases.
The settlement atlas reuses these native pixels in four reaction rows.
"""
from pathlib import Path
import argparse
import hashlib
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
FRAME = 372
BOB = (0, -2, 0, 2)
# Existing bank reaction indices: idle, small/large withdrawal, small/large deposit.
STATES = ("neutral", "downcast", "displeased", "smile", "delighted")
SOURCE_NAMES = ("neutral", "worried", "angry", "sly", "excited")
# Settlement rows follow data_config/run_settlement.json.
REACTIONS = (4, 2, 3, 1)


def settlement_sheet(bank: Image.Image) -> Image.Image:
    assert bank.size == (FRAME * 5, FRAME)
    sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4))
    for row, state in enumerate(REACTIONS):
        source = bank.crop((state * FRAME, 0, (state + 1) * FRAME, FRAME))
        for frame, bob in enumerate(BOB):
            pose = Image.new("RGBA", (FRAME, FRAME))
            pose.alpha_composite(source, (0, bob))
            # Transparent margins must accommodate the existing idle movement.
            assert sum(pose.getchannel("A").tobytes()) == sum(source.getchannel("A").tobytes())
            sheet.paste(pose, (frame * FRAME, row * FRAME))
    return sheet


def validate_sprite(sprite):
    if sprite.mode != "RGBA" or sprite.size != (FRAME, FRAME):
        raise ValueError(f"Portrait must be a {FRAME}x{FRAME} RGBA image")
    if set(sprite.getchannel("A").tobytes()) != {0, 255}:
        raise ValueError("Portrait must have binary alpha")
    colors = {pixel[:3] for _, pixel in sprite.getcolors(FRAME * FRAME) if pixel[3]}
    if len(colors) > 16:
        raise ValueError("Portrait exceeds the 16-color palette")


def check_installed(asset_root=ASSETS):
    with Image.open(Path(asset_root) / "ui/finance/goblin_banker_states.png") as source:
        bank = source.convert("RGBA")
    if bank.size != (FRAME * len(STATES), FRAME):
        raise ValueError(f"Bank atlas must be {FRAME * len(STATES)}x{FRAME}")
    for index in range(len(STATES)):
        validate_sprite(bank.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)))
    manifest = json.loads((Path(asset_root) / "ui/finance/goblin_portraits.json").read_text(encoding="utf-8"))
    settlement = Path(asset_root) / "ui/settlement/goblin_reactions.png"
    metadata = manifest["settlement"]
    if hashlib.sha256(settlement.read_bytes()).hexdigest() != metadata["sha256"]:
        raise ValueError("Settlement atlas does not match its source manifest")
    with Image.open(settlement) as image:
        expected = settlement_sheet(bank)
        if image.size != expected.size or image.convert("RGBA").tobytes() != expected.tobytes():
            raise ValueError("Settlement must reuse the bank pixels with only the documented integer bob offsets")
    print("PASS: five native 372px portraits; all 16 settlement frames match reviewed bank pixels")


def sync_settlement(asset_root=ASSETS):
    """Repack already reviewed finance art; never resize or rewrite the bank."""
    root = Path(asset_root)
    with Image.open(root / "ui/finance/goblin_banker_states.png") as source:
        bank = source.convert("RGBA")
    target = root / "ui/settlement/goblin_reactions.png"
    settlement_sheet(bank).save(target)
    manifest_path = root / "ui/finance/goblin_portraits.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.pop("preserved_settlement", None)
    manifest["settlement"] = {
        "source": "res://assets/ui/finance/goblin_banker_states.png",
        "path": "res://assets/ui/settlement/goblin_reactions.png",
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "atlas_size": [FRAME * 4, FRAME * 4], "frame_size": [FRAME, FRAME],
        "source_state_indices": list(REACTIONS), "bob_pixels": list(BOB),
        "method": "Unscaled copies of reviewed bank frames; integer vertical offsets only"}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    check_installed(asset_root)


def install_assets(source, asset_root=ASSETS):
    bank = Image.new("RGBA", (FRAME * len(STATES), FRAME))
    records = []
    for index, state in enumerate(STATES):
        path = Path(source).resolve() / f"goblin_{state}.png"
        if not path.is_file():
            path = Path(source).resolve() / f"goblin_{SOURCE_NAMES[index]}.png"
        with Image.open(path) as image:
            sprite = image.copy()
        validate_sprite(sprite)
        bank.paste(sprite, (index * FRAME, 0))
        assert bank.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)).tobytes() == sprite.tobytes()
        records.append({"index": index, "expression": state,
                        "source": path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else path.as_posix(),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    # Finance and settlement now share the same reviewed portrait pixels.
    target = Path(asset_root) / "ui/finance/goblin_banker_states.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    bank.save(target)
    manifest = {"version": "native-372-original-picxel", "frame_size": [FRAME, FRAME], "states": records,
                "waist_anchor": [186, 326], "hand_anchor": [186, 365],
                "settlement_rows": list(REACTIONS), "settlement_bob_pixels": list(BOB)}
    (Path(asset_root) / "ui/finance/goblin_portraits.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Installed bank {FRAME * 5}x{FRAME}; selected pixels and alpha preserved.")
    sync_settlement(asset_root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--source", type=Path)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--sync-settlement", action="store_true")
    args = parser.parse_args()
    if args.sync_settlement:
        sync_settlement()
    elif args.source is None:
        check_installed()
    else:
        install_assets(args.source)


if __name__ == "__main__":
    main()
