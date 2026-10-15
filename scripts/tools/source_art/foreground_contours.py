"""Source-supported foreground contour repairs, without filesystem writes."""
from collections import Counter
from pathlib import Path
import sys
import numpy as np
from scipy import ndimage as ndi
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'.agents/skills/picxel-external-images/vendor/picxel/scripts'))
import picxel as px

def repair_foreground(grid, colors, source, palette, protected_boxes):
    arr = np.array(grid.g)
    original = arr.copy()
    mask = arr != '.'
    palette = (work / f'{name}.pal').read_text(encoding='utf-8').splitlines()
    by_hex = {value: key for key, value in colors.items()}

    def symbol(value):
        if value not in by_hex:
            assert value in palette
            available = next(c for c in 'ABCDEFGHIJKLMNOP' if c not in colors)
            colors[available] = value
            by_hex[value] = available
        return by_hex[value]

    dark = symbol('#15111c')
    for old, new in [('#f7bcf8', '#f6bcf8'), ('#4d305e', '#463150')]:
        if old in by_hex:
            arr[arr == by_hex[old]] = symbol(new)
    square = np.array(px._square(source, 128))
    block = square.shape[0] // 128
    cropped = source.getchannel('A').getbbox()
    left = (square.shape[1] - (cropped[2]-cropped[0])) // 2
    top = (square.shape[0] - (cropped[3]-cropped[1])) // 2
    protected = np.zeros_like(mask)
    for box in protected_boxes:
        x0, y0 = (box[0]-cropped[0]+left)//block, (box[1]-cropped[1]+top)//block
        x1, y1 = (box[2]-cropped[0]+left)//block, (box[3]-cropped[1]+top)//block
        protected[y0:y1+1, x0:x1+1] = True
    lum = square[:, :, :3].astype(float) @ np.array([.2126, .7152, .0722])
    ink = (square[:, :, 3] > 127) & (lum < 29)
    coverage = ink.reshape(128, block, 128, block).mean(axis=(1, 3))
    arr[mask & ~protected & (coverage >= .24)] = dark
    merged = 0
    for color in ['#3d3e44', '#465d5b', '#537a73', '#382340']:
        if color not in by_hex:
            continue
        key = by_hex[color]
        labels, count = ndi.label((arr == key) & ~protected, np.ones((3, 3)))
        for component in range(1, count+1):
            region = labels == component
            if region.sum() > 3:
                continue
            ring = ndi.binary_dilation(region) & mask & ~region & ~protected
            votes = Counter(arr[ring])
            votes.pop(dark, None)
            votes.pop(key, None)
            if not votes:
                continue
            replacement = votes.most_common(1)[0][0]
            rgb = np.array([int(colors[key][i:i+2], 16) for i in (1, 3, 5)])
            other = np.array([int(colors[replacement][i:i+2], 16) for i in (1, 3, 5)])
            if np.linalg.norm(rgb-other) <= 55:
                arr[region] = replacement
                merged += int(region.sum())
    outline = mask & ~ndi.binary_erosion(mask, ndi.generate_binary_structure(2, 1))
    arr[outline & ~protected] = dark
    assert np.array_equal(arr != '.', mask)
    return arr.tolist(), colors

def repair_crystal_foreground(grid, colors, source, palette, size=128):
    arr = np.array(grid.g)
    original = arr.copy()
    mask = arr != '.'
    by_hex = {value: key for key, value in colors.items()}

    def symbol(value):
        if value not in by_hex:
            assert value in palette
            available = next(c for c in 'ABCDEFGHIJKLMNOP' if c not in colors)
            colors[available] = value
            by_hex[value] = available
        return by_hex[value]

    dark = symbol('#15111c')
    # Consolidate nearly identical crystal shades; do not add a new color.
    for old, new in [('#f7bcf8', '#f6bcf8'), ('#4d305e', '#463150')]:
        if old in by_hex:
            arr[arr == by_hex[old]] = symbol(new)

    square = np.array(px._square(source, size))
    block = square.shape[0] // size
    cropped = source.getchannel('A').getbbox()
    left = (square.shape[1] - (cropped[2] - cropped[0])) // 2
    top = (square.shape[0] - (cropped[3] - cropped[1])) // 2

    def point(x, y):
        return int((x-cropped[0]+left)//block), int((y-cropped[1]+top)//block)

    crystal = np.zeros_like(mask)
    for box in [(18, 205, 119, 342), (133, 612, 310, 794)]:
        x0, y0 = point(box[0], box[1])
        x1, y1 = point(box[2], box[3])
        crystal[y0:y1+1, x0:x1+1] = True

    # Reconnect source-black seams that lose a majority vote at small sizes.
    # All proposed seam pixels must be supported by the original dark paint.
    lum = square[:, :, :3].astype(float) @ np.array([.2126, .7152, .0722])
    ink = (square[:, :, 3] > 127) & (lum < 29)
    coverage = ink.reshape(size, block, size, block).mean(axis=(1, 3))
    threshold = {128: .24, 64: .19, 32: .18}[size]
    seam = mask & ~crystal & (coverage >= threshold)
    arr[seam] = dark

    # Remove only small low-contrast rock flecks; preserve crystal glints and
    # the connected teal highlights that explain each plane's orientation.
    changed_islands = 0
    for color in ['#3d3e44', '#465d5b', '#537a73', '#382340']:
        if color not in by_hex:
            continue
        key = by_hex[color]
        labels, count = ndi.label((arr == key) & ~crystal, np.ones((3, 3)))
        for component in range(1, count+1):
            region = labels == component
            if region.sum() > (3 if size == 128 else 1):
                continue
            ring = ndi.binary_dilation(region) & mask & ~region & ~crystal
            votes = Counter(arr[ring])
            votes.pop(dark, None)
            votes.pop(key, None)
            if not votes:
                continue
            replacement = votes.most_common(1)[0][0]
            rgb = np.array([int(colors[key][i:i+2], 16) for i in (1, 3, 5)])
            other = np.array([int(colors[replacement][i:i+2], 16) for i in (1, 3, 5)])
            if np.linalg.norm(rgb-other) <= 55:
                arr[region] = replacement
                changed_islands += int(region.sum())

    # One inward pixel follows the intact silhouette; no color-key removal,
    # alpha erosion or filling of internal holes occurs here.
    outline = mask & ~ndi.binary_erosion(mask, ndi.generate_binary_structure(2, 1))
    arr[outline & ~crystal] = dark
    # At 32/64 the imported crystal highlights became isolated dots. Restore
    # short, connected crystal facets at the inspected grid coordinates.
    crystal_patches = {
        32: {
            '#e18af4': [(2, 9)],
            '#b574c2': [(2, 10), (6, 20)],
            '#8346ae': [(3, 10), (6, 21), (7, 22)],
            '#713b8f': [(2, 11), (5, 21), (6, 22)],
        },
        64: {
            '#f6bcf8': [(5, 18), (13, 39), (16, 42)],
            '#e18af4': [(5, 19), (13, 40)],
            '#b574c2': [(5, 20), (12, 40), (12, 41), (15, 43)],
            '#8346ae': [(6, 19), (6, 20), (6, 21), (11, 41), (11, 42), (15, 44)],
            '#713b8f': [(5, 21), (11, 43), (14, 44)],
        },
    }
    facet_pixels = 0
    for color, points in crystal_patches.get(size, {}).items():
        key = symbol(color)
        for x, y in points:
            assert mask[y, x] and crystal[y, x], (size, x, y)
            facet_pixels += int(arr[y, x] != key)
            arr[y, x] = key
    assert np.array_equal(arr != '.', mask)
    return arr.tolist(), colors
