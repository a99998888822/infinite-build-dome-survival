"""Move the painted finance-wall light locally, without moving the fixtures.

Default writes a review PNG. The supplied original remains untouched.
"""
from pathlib import Path
import argparse
import json
import hashlib

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'artifacts/sources/finance_ui_20261018/finance_background_r03_restyle_16x9.png'
SOURCE_SHA = '3390e24822729ce510c24693befc9e1727ee606366442c2e0414e348a3c24550'
LIGHT_CENTER = (752, 207)
OLD_CENTER = (727, 284)
TINT = np.array([36, 3, 30], dtype=np.float32)


def fixture_mask(shape):
    result = np.zeros(shape, dtype=np.uint8)
    lantern = [(736,38),(762,38),(772,47),(766,62),(760,67),(760,88),
               (770,104),(772,121),(766,132),(785,146),(803,160),(803,172),
               (794,179),(782,237),(789,243),(789,254),(777,261),(764,270),
               (763,278),(753,287),(743,281),(741,273),(729,267),(713,258),
               (712,244),(719,237),(706,181),(697,174),(696,161),(710,152),
               (726,134),(731,129),(728,116),(731,103),(737,94),(737,74),
               (735,64),(729,59),(727,47)]
    scroll = [(811,120),(1216,117),(1222,146),(1208,159),(1205,199),
              (1223,216),(1225,240),(1205,247),(820,247),(805,241),
              (802,230),(805,219),(819,210),(821,198),(817,177),
              (815,159),(800,152),(798,135)]
    for polygon in (lantern, scroll):
        cv2.fillPoly(result, [np.array(polygon, dtype=np.int32)], 255)
    return result


def build():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_SHA
    original = np.array(Image.open(SOURCE).convert('RGB'))
    height, width = original.shape[:2]
    fixtures = fixture_mask((height, width))
    rgb = original.astype(np.float32)
    # The old, flat purple disk is distinguishable from the wall and fixtures.
    core = ((rgb[:,:,0] > 65) & (rgb[:,:,0] < 112)
            & (rgb[:,:,0] - rgb[:,:,1] > 26)
            & (rgb[:,:,2] - rgb[:,:,1] > 37)).astype(np.uint8) * 255
    bounds = np.zeros((height, width), dtype=np.uint8)
    bounds[155:409, 590:865] = 255
    core &= bounds
    core[fixtures > 0] = 0
    contours, _ = cv2.findContours(core, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    contour = max(contours, key=cv2.contourArea)
    disk = np.zeros_like(core)
    cv2.fillConvexPoly(disk, cv2.convexHull(contour), 255)
    # Preserve the visible faceted silhouette; interpolate its short occluded arc.
    points = contour[:,0,:].astype(np.float32)
    relative = points - np.array(OLD_CENTER, dtype=np.float32)
    angles = np.arctan2(relative[:,1], relative[:,0])
    radii = np.linalg.norm(relative, axis=1)
    valid = (radii > 108) & (radii < 132)
    angles, radii = angles[valid], radii[valid]
    order = np.argsort(angles)
    angles, radii = angles[order], radii[order]
    target_angles = np.linspace(-np.pi, np.pi, 48, endpoint=False)
    target_radii = np.interp(target_angles, angles, radii, period=2*np.pi)
    new_points = np.rint(np.array(LIGHT_CENTER) + np.stack(
        [np.cos(target_angles)*target_radii, np.sin(target_angles)*target_radii], axis=1)).astype(np.int32)
    new_disk = np.zeros_like(core)
    cv2.fillPoly(new_disk, [new_points], 255)
    # Remove the old tint while retaining its fine wall texture. Only its narrow
    # painted edge needs local interpolation; no large-area texture inpainting.
    inner = cv2.erode(disk, np.ones((5,5), np.uint8))
    outer = cv2.dilate(disk, np.ones((5,5), np.uint8))
    active = (inner > 0) & (fixtures == 0)
    wall = rgb.copy()
    wall[active] = np.maximum(0, wall[active] - TINT)
    ring = outer - inner
    ring[fixtures > 0] = 0
    wall = cv2.inpaint(np.rint(wall).astype(np.uint8), ring, 3, cv2.INPAINT_TELEA)
    # Apply the same tint at the lamp center, behind its chain and the sign.
    active_new = (new_disk > 0) & (fixtures == 0)
    result = wall.astype(np.float32)
    result[active_new] += TINT
    result = np.clip(np.rint(result), 0, 255).astype(np.uint8)
    result[fixtures > 0] = original[fixtures > 0]
    allowed = (outer > 0) | (new_disk > 0)
    assert np.array_equal(result[~allowed], original[~allowed])
    assert np.array_equal(result[fixtures > 0], original[fixtures > 0])
    return Image.fromarray(result), {
        'source': SOURCE.relative_to(ROOT).as_posix(), 'source_sha256': SOURCE_SHA,
        'old_center': list(OLD_CENTER), 'light_center': list(LIGHT_CENTER),
        'size': [width, height], 'method': 'local tint separation and repositioning',
        'fixture_pixels_unchanged': True, 'outside_light_regions_unchanged': True,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    image, report = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    report['sha256'] = hashlib.sha256(args.output.read_bytes()).hexdigest()
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
