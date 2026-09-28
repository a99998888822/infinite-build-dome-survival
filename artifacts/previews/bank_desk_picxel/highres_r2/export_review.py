"""Crop transparent padding only and validate the review deliverable."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parent
source = Image.open(root / 'work/bank-desk-128.png').convert('RGBA')
assert source.size == (128, 128)
box = source.getbbox()
assert box[1] >= 32 and box[3] <= 96
crop = source.crop((0, 32, 128, 96))
crop.save(root / 'bank-desk-128x64.png')
palette = {rgb for _, rgb in crop.getcolors(128 * 64) if rgb[3]}
assert len(palette) <= 16
assert set(crop.getchannel('A').tobytes()) == {0, 255}
restored = Image.new('RGBA', (128, 128))
restored.paste(crop, (0, 32))
assert restored.tobytes() == source.tobytes()
background = Image.new('RGBA', crop.size, '#c2c6bf')
background.alpha_composite(crop)
background.convert('RGB').resize((768, 384), Image.Resampling.NEAREST).save(root / 'bank-desk-review@6x.png')
report = {
    'file': 'bank-desk-128x64.png', 'canvas': [128, 64],
    'opaque_bbox': crop.getbbox(), 'opaque_colors': len(palette),
    'alpha': [0, 255], 'source_grid': [128, 128],
    'crop': [0, 32, 128, 96], 'resampled': False,
    'crop_restores_exact_grid': True, 'review_scale': 6,
    'review_background_only': '#c2c6bf',
    'method': 'External-image pixelization plus AI-guided local pixel edits',
    'image_model_used': False, 'user_style_review': 'pending'
}
(root / 'delivery-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
