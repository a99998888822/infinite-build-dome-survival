"""Prepare the supplied high-resolution desk with source-specific background masks."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
from PIL import Image, ImageDraw, ImageChops

ROOT = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(__file__).resolve().parent
source = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / 'refs/bank-desk.png'
for folder in ('refs', 'prepared', 'work'):
    (ROOT / folder).mkdir(parents=True, exist_ok=True)
im = Image.open(source).convert('RGB')
assert im.size == (2176, 1088), im.size
# Coordinates were inspected on the 2048x1024 chat preview, mapped to the file.
def point(x, y):
    return (round(x * im.width / 2048), round(y * im.height / 1024))
# The desk is wholly above preview y=880; the footer is outside this region.
candidate = Image.new('L', im.size)
candidate.putdata([255 if min(rgb) >= 200 and max(rgb) - min(rgb) <= 32 else 0
                   for rgb in im.getdata()])
ImageDraw.floodfill(candidate, (0, 0), 128)
# Enclosed background between drawer frame and the lower crossbar, checked
# against this source rather than coordinates from the earlier thumbnail.
assert candidate.getpixel(point(1024, 700)) == 255
ImageDraw.floodfill(candidate, point(1024, 700), 128)
assert candidate.getpixel(point(425, 280)) == 255
ImageDraw.floodfill(candidate, point(425, 280), 128)
alpha = candidate.point(lambda v: 0 if v == 128 else 255)
roi = Image.new('L', im.size)
ImageDraw.Draw(roi).rectangle((*point(180, 165), *point(1875, 870)), fill=255)
alpha = ImageChops.multiply(alpha, roi)
rgba = im.convert('RGBA')
rgba.putalpha(alpha)
rgba.save(ROOT / 'prepared/bank-desk.png')
if source.resolve() != (ROOT / 'refs/bank-desk.png').resolve():
    shutil.copyfile(source, ROOT / 'refs/bank-desk.png')
palette = ['#111b18', '#293025', '#35291f', '#523b28',
           '#715032', '#946a3e', '#b38b55', '#d1b47b',
           '#e5d4a5', '#a1926a', '#7e6226', '#bf9135',
           '#efd172', '#173d30', '#245d50', '#46a192']
anchor = {
    'subject': 'Wide carved wooden bank counter with green lamp, open ledger, paper, pen and gold coins',
    'kind': 'sprite', 'size': 128, 'palette': palette,
    'keep': [
        'Wide bevelled desktop, two sturdy feet, lower crossbar and open gap',
        'Green banker lamp and open cream ledger on image-left',
        'Writing mat, cream sheet and diagonal black pen at the center',
        'Three groups of gold coin stacks on image-right',
        'Three front panels, center pull and teal corner and leg ornaments'],
    'drop': ['White background and detached footer',
             'Hairline scratches, tiny coin ridges and tiny page lettering'],
    'regions': [
        {'name': 'lamp', 'box': [0.105, 0.168, 0.236, 0.383], 'detail': 'fine'},
        {'name': 'ledger', 'box': [0.23, 0.194, 0.39, 0.336], 'detail': 'fine'},
        {'name': 'pen and paper', 'box': [0.406, 0.235, 0.601, 0.393], 'detail': 'fine'},
        {'name': 'coins', 'box': [0.64, 0.23, 0.824, 0.389], 'detail': 'fine'}],
    'faces': []
}
(ROOT / 'refs/bank-desk.anchor.json').write_text(json.dumps(anchor, indent=2) + '\n', encoding='utf-8')
report = {
    'source': str(source), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'source_size': list(im.size), 'source_has_alpha': Image.open(source).mode == 'RGBA',
    'subject_bbox': rgba.getbbox(), 'image_model_used': False,
    'method': 'Source-specific white flood fill including the enclosed crossbar gap; original RGB preserved',
    'grid_size': [128, 128], 'palette': palette
}
(ROOT / 'source-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report))
