"""Prepare a fresh, reference-derived source for Picxel's 128px conversion.

This is local source-image processing, not image-model generation or a new
semantic redraw. It does not read any earlier 64px sprite or drawn concept.
Only the source-specific background extraction helper is reused.
"""
from pathlib import Path
import hashlib
import json
import shutil

from PIL import Image

from pixelize_goblin_review import extract


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "artifacts/previews/goblin_reprint/picxel_128_review"
EXPECTED_SHA256 = "e0f439d91d5f5777f54fbcdbf86d5a748fc95bd0ba547d448df4177144471636"


def main():
    source = BASE / "refs/goblin.png"
    if not source.exists():
        originals = [p for p in BASE.parent.glob("*.png")
                     if hashlib.sha256(p.read_bytes()).hexdigest() == EXPECTED_SHA256]
        if len(originals) != 1:
            raise ValueError("Need the retained approved default reference")
        source.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(originals[0], source)
    (BASE / "concepts").mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert digest == EXPECTED_SHA256, "Recheck the original-specific hand and background mask"
    image = Image.open(source).convert("RGB")
    assert image.size == (1536, 1536)
    result = extract(image)
    result.save(BASE / "concepts/goblin.png")
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    report = {
        "method": "Fresh high-resolution reference extraction followed by Picxel local pixel conversion",
        "image_model_used": False,
        "semantic_redraw": False,
        "earlier_64px_sprite_used": False,
        "earlier_drawn_concept_used": False,
        "source_size": list(image.size),
        "source_sha256": digest,
        "requested_size": [128, 128],
        "mask": "Source-specific background, enclosed arm gaps and lower hand/table boundary",
        "note": "The concept handoff contains the cleaned original; it is not claimed to be AI-redrawn art."
    }
    (BASE / "concepts/method.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
