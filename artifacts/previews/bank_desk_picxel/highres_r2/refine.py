"""AI-guided local pixel repairs from the inspected desk and imported grid.
No generative model, whole-image filter, dithering or rescaling of the source.
"""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
sys.path.insert(0, str(REPO / '.agents/skills/picxel-external-images/vendor/picxel/scripts'))
from px import Grid
from picxel import load, render, check

work = ROOT / 'work'
grid, meta, colors = Grid.load(work / 'bank-desk-128.pxg')
before = grid.rows()
symbols = {value: key for key, value in colors.items()}
ink, wooddark, woodshadow = '#111b18', '#35291f', '#523b28'
wood, warm, edge = '#715032', '#946a3e', '#b38b55'
tan, paper, muted = '#d1b47b', '#e5d4a5', '#a1926a'
goldshadow, gold, glint = '#7e6226', '#bf9135', '#efd172'
green, teal, turquoise = '#173d30', '#245d50', '#46a192'
metal = '#293025'

def line(x0, y0, x1, y1, color):
    grid.line(x0, y0, x1, y1, symbols[color])

def rect(x0, y0, x1, y1, color):
    grid.rect(x0, y0, x1, y1, symbols[color])

def dot(x, y, color):
    grid.put(symbols[color], (x, y))

# Shade interior was almost black; restore the green planes inside its silhouette.
line(10, 41, 21, 41, teal)
line(9, 42, 22, 42, green)
line(8, 43, 23, 43, green)
line(9, 44, 23, 44, muted)
dot(9, 44, tan)
rect(14, 45, 18, 45, tan)
line(15, 46, 15, 51, tan)
line(16, 46, 16, 51, edge)
line(17, 46, 17, 51, goldshadow)
line(12, 52, 20, 52, green)
line(12, 53, 20, 53, teal)
line(12, 54, 20, 54, ink)

# The open ledger keeps its two-page angle; page text becomes short grouped marks.
line(29, 44, 32, 44, muted)
line(30, 46, 33, 46, muted)
line(34, 44, 35, 48, woodshadow)
line(36, 45, 41, 45, muted)
line(37, 47, 42, 47, muted)
line(29, 49, 34, 49, wood)
line(36, 49, 45, 49, wood)
line(28, 50, 44, 50, ink)

# Clean the small writing sheet's text into two unbroken strokes.
line(53, 51, 66, 51, muted)
line(56, 53, 69, 53, muted)
# Restore a continuous, diagonally rising pen with sparse ivory reflections.
line(70, 52, 77, 45, ink)
for x, y in ((73, 49), (75, 47), (77, 45)):
    dot(x, y, paper)

# Coin stacks: preserve source positions and separated tiers; remove speckled ridges.
def coin(x0, y, width):
    line(x0 + 1, y, x0 + width - 2, y, glint)
    line(x0, y + 1, x0 + width - 1, y + 1, gold)
    dot(x0, y + 1, tan)
    dot(x0 + width - 1, y + 1, goldshadow)
    line(x0 + 1, y + 2, x0 + width - 2, y + 2, goldshadow)

rect(85, 44, 93, 48, ink)
grid.erase(85, 44, 93, 48)
rect(85, 49, 93, 53, woodshadow)
coin(86, 44, 7)
coin(86, 47, 7)
coin(86, 50, 7)
rect(95, 48, 101, 54, woodshadow)
coin(95, 48, 7)
coin(95, 51, 7)
rect(104, 52, 111, 55, wood)
coin(104, 52, 7)

# The lip and drawer panels need longer material clusters than raw wood scratches.
line(7, 57, 120, 57, edge)
for a, b in ((8, 29), (39, 61), (74, 99), (108, 118)):
    line(a, 57, b, 57, tan)
line(7, 58, 120, 58, warm)
line(8, 59, 119, 59, woodshadow)
line(9, 61, 119, 61, wood)
line(19, 62, 111, 62, wooddark)

for x0, x1 in ((20, 51), (55, 77), (81, 110)):
    rect(x0, 65, x1, 73, wooddark)
    rect(x0 + 1, 66, x1 - 1, 72, wood)
    line(x0 + 1, 65, x1 - 1, 65, edge)
    line(x0 + 1, 72, x1 - 1, 72, woodshadow)
    line(x0 + 1, 73, x1 - 1, 73, edge)
    dot(x0, 66, warm)
    dot(x0, 71, warm)

# Select wood grain as intentional short horizontal runs with no random noise.
for x0, x1, y in ((22, 28, 68), (32, 40, 68), (46, 49, 70),
                  (27, 35, 71), (39, 46, 69), (56, 60, 70),
                  (70, 75, 69), (82, 88, 70), (102, 107, 68), (101, 107, 71)):
    line(x0, y, x1, y, woodshadow)
for x0, x1, y in ((22, 30, 67), (34, 41, 70), (58, 61, 68), (102, 108, 70)):
    line(x0, y, x1, y, warm)

# Restrained bronze/iron hardware: continuous rail, two straps and central handle.
for x0, x1 in ((20, 51), (81, 110)):
    line(x0, 66, x1, 66, metal)
    line(x0 + 1, 66, x1 - 1, 66, muted)
    for x in (x0 + 1, x1 - 1):
        dot(x, 66, paper)
for x in (25, 45):
    line(x, 65, x, 73, ink)
    line(x + 1, 65, x + 1, 73, muted)
    dot(x + 1, 65, tan)
    dot(x + 1, 73, tan)
rect(61, 67, 70, 71, ink)
rect(63, 67, 68, 68, edge)
line(63, 67, 68, 67, tan)
line(62, 71, 69, 71, metal)

# Front fittings: readable teal engraving and lighter metal borders.
for x0 in (11, 112):
    rect(x0, 59, x0 + 5, 74, ink)
    line(x0, 60, x0, 73, teal)
    line(x0 + 1, 60, x0 + 4, 60, muted)
    line(x0 + 4, 61, x0 + 4, 72, metal)
    dot(x0 + 1, 61, tan)
    dot(x0 + 1, 72, tan)
    line(x0 + 2, 63, x0 + 3, 64, teal)
    line(x0 + 3, 64, x0 + 1, 66, teal)
    line(x0 + 1, 66, x0 + 3, 68, teal)
    line(x0 + 3, 68, x0 + 1, 70, teal)
    dot(x0 + 2, 65, turquoise)
    dot(x0 + 2, 69, turquoise)

# The front-right scroll motif is a tiny symmetric metal flourish, not lettering.
for x0, y0, x1, y1 in ((91, 69, 94, 67), (94, 67, 97, 69),
                        (91, 69, 94, 71), (94, 71, 97, 69)):
    line(x0, y0, x1, y1, teal)
dot(91, 69, turquoise)
dot(96, 69, turquoise)
line(94, 68, 94, 70, muted)

# Restore depth and ornament on the legs without filling the open crossbar gap.
line(24, 79, 109, 79, woodshadow)
line(24, 80, 109, 80, wooddark)
for x0, direction in ((14, 1), (114, -1)):
    line(x0, 77, x0, 83, wood)
    line(x0 + direction, 77, x0 + direction, 83, edge)
    line(x0 + 2 * direction, 78, x0 + 2 * direction, 83, woodshadow)
    line(x0 + 4 * direction, 78, x0 + 4 * direction, 80, teal)
    line(x0 + 4 * direction, 80, x0 + 3 * direction, 82, teal)
    dot(x0 + 4 * direction, 82, turquoise)
line(14, 84, 20, 84, edge)
line(13, 85, 20, 85, wood)
line(13, 86, 19, 86, woodshadow)
line(108, 84, 114, 84, edge)
line(109, 85, 115, 85, wood)
line(110, 86, 114, 86, woodshadow)

# Material repairs on the body must remain within the inspected source silhouette.
for y in range(56, 128):
    for x in range(128):
        if before[y][x] == '.':
            grid.g[y][x] = '.'

target = work / 'bank-desk-128-detail.pxg'
grid.write(target, target.stem, 'sprite', colors, palette=meta['palette'])
sheet = load(target)
errors, warnings = check(sheet)
assert not errors, errors
render(sheet, work)
img = sheet.image().convert('RGBA')
assert set(img.getchannel('A').tobytes()) <= {0, 255}
changed = sum(a != b for ar, br in zip(before, grid.rows()) for a, b in zip(ar, br))
(ROOT / 'refinement-report.json').write_text(json.dumps({
    'method': 'AI-inspected local Grid edits', 'image_model_used': False,
    'changes': changed, 'errors': errors, 'warnings': warnings,
    'retained': 'Source layout, desk proportions, transparency and original imported base',
    'repairs': ['Green lamp planes', 'Ledger marks and pen continuity', 'Coin tiers',
                'Clustered wood grain and bevels', 'Drawer rails and handle', 'Teal fittings and legs']
}, indent=2) + '\n', encoding='utf-8')
# A close inspection preview, same pixels at exactly 8x nearest-neighbor.
crop = img.crop((0, 32, 128, 96))
back = Image.new('RGBA', crop.size, '#c2c6bf')
back.alpha_composite(crop)
back.resize((1024, 512), Image.Resampling.NEAREST).save(work / 'detail-inspection@8x.png')
print(json.dumps({'changed_pixels': changed, 'errors': errors, 'warnings': warnings}))
