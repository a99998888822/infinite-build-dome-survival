"""Validate current goblin atlases, or install five reviewed --source portraits.

Input names: goblin_neutral.png, goblin_downcast.png, goblin_displeased.png,
goblin_smile.png and goblin_delighted.png, each 256x256 RGBA with binary alpha.
"""
from pathlib import Path
import argparse
import hashlib
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
FRAME = 256
BOB = (0, -2, 0, 2)
# Existing bank reaction indices: idle, small/large withdrawal, small/large deposit.
STATES = ("neutral", "downcast", "displeased", "smile", "delighted")
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
        raise ValueError("Portrait must be a 256x256 RGBA image")
    if set(sprite.getchannel("A").tobytes()) != {0, 255}:
        raise ValueError("Portrait must have binary alpha")
    colors = {pixel[:3] for _, pixel in sprite.getcolors(FRAME * FRAME) if pixel[3]}
    if len(colors) > 16:
        raise ValueError("Portrait exceeds the 16-color palette")


def check_installed(asset_root=ASSETS):
    with Image.open(Path(asset_root) / "ui/finance/goblin_banker_states.png") as source:
        bank = source.convert("RGBA")
    if bank.size != (FRAME * len(STATES), FRAME):
        raise ValueError("Bank atlas must be 1280x256")
    for index in range(len(STATES)):
        validate_sprite(bank.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)))
    expected = settlement_sheet(bank)
    with Image.open(Path(asset_root) / "ui/settlement/goblin_reactions.png") as actual:
        if actual.size != expected.size or actual.convert("RGBA").tobytes() != expected.tobytes():
            raise ValueError("Settlement atlas does not match the bank expressions")
    print("PASS: goblin bank and settlement atlases have matching expressions and valid pixels")


def install_assets(source, asset_root=ASSETS):
    bank = Image.new("RGBA", (FRAME * len(STATES), FRAME))
    records = []
    for index, state in enumerate(STATES):
        path = Path(source).resolve() / f"goblin_{state}.png"
        with Image.open(path) as image:
            sprite = image.copy()
        validate_sprite(sprite)
        bank.paste(sprite, (index * FRAME, 0))
        assert bank.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)).tobytes() == sprite.tobytes()
        records.append({"index": index, "expression": state,
                        "source": str(path),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    # Assemble and validate both atlases before touching either runtime file.
    reactions = settlement_sheet(bank)
    target = Path(asset_root) / "ui/finance/goblin_banker_states.png"
    reaction_target = Path(asset_root) / "ui/settlement/goblin_reactions.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    reaction_target.parent.mkdir(parents=True, exist_ok=True)
    bank.save(target)
    reactions.save(reaction_target)
    manifest = {"frame_size": [FRAME, FRAME], "states": records,
                "settlement_rows": list(REACTIONS), "settlement_bob_pixels": list(BOB)}
    (Path(asset_root) / "ui/finance/goblin_portraits.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Overwrote bank 1280x256 and settlement 1024x1024 atlases; approved pixels and alpha preserved.")
    check_installed(asset_root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--source", type=Path)
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.source is None:
        check_installed()
    else:
        install_assets(args.source)


if __name__ == "__main__":
    main()
