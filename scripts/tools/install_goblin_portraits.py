"""Install the approved 128px portraits over both runtime goblin atlases."""
from pathlib import Path
import hashlib
import json

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PREVIEWS = ROOT / "artifacts/previews/goblin_reprint"
FRAME = 128
# Existing bank reaction indices: idle, small/large withdrawal, small/large deposit.
STATES = ("neutral", "downcast", "displeased", "smile", "delighted")
# Settlement rows follow data_config/run_settlement.json.
REACTIONS = (4, 2, 3, 1)


def settlement_sheet(bank: Image.Image) -> Image.Image:
    assert bank.size == (FRAME * 5, FRAME)
    sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4))
    for row, state in enumerate(REACTIONS):
        source = bank.crop((state * FRAME, 0, (state + 1) * FRAME, FRAME))
        for frame, bob in enumerate((0, -1, 0, 1)):
            pose = Image.new("RGBA", (FRAME, FRAME))
            pose.alpha_composite(source, (0, bob))
            # Transparent margins must accommodate the existing idle movement.
            assert sum(pose.getchannel("A").tobytes()) == sum(source.getchannel("A").tobytes())
            sheet.paste(pose, (frame * FRAME, row * FRAME))
    return sheet


def main():
    bank = Image.new("RGBA", (FRAME * len(STATES), FRAME))
    records = []
    for index, state in enumerate(STATES):
        source = (PREVIEWS / "picxel_128_review/work/goblin-128.png" if state == "neutral" else
                  PREVIEWS / f"picxel_expressions_128/work/goblin_{state}-128.png")
        sprite = Image.open(source).convert("RGBA")
        assert sprite.size == (FRAME, FRAME)
        assert set(sprite.getchannel("A").tobytes()) == {0, 255}
        bank.paste(sprite, (index * FRAME, 0))
        assert bank.crop((index * FRAME, 0, (index + 1) * FRAME, FRAME)).tobytes() == sprite.tobytes()
        records.append({"index": index, "expression": state,
                        "source": source.relative_to(ROOT).as_posix(),
                        "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
    target = ROOT / "assets/ui/finance/goblin_banker_states.png"
    bank.save(target)
    reactions = settlement_sheet(bank)
    reactions.save(ROOT / "assets/ui/settlement/goblin_reactions.png")
    manifest = {"frame_size": [FRAME, FRAME], "states": records,
                "settlement_rows": list(REACTIONS), "settlement_bob_pixels": [0, -1, 0, 1]}
    (ROOT / "assets/ui/finance/goblin_portraits.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Overwrote bank 640x128 and settlement 512x512 atlases; approved pixels and alpha preserved.")


if __name__ == "__main__":
    main()
