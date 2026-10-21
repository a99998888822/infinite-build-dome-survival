"""Check production bat artwork, or explicitly rebuild its atlases and effects.

No arguments only validates. Historical pixel-processing directories are unused.
--rebuild uses the current formal frames; --rebuild-sonic only redraws the three
native-size effects. --assemble-captures requires --output-gif.
"""
from pathlib import Path
import argparse
import hashlib
import io
import json
import math
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/sprites/enemies/echo_bat'
SIZE = 96


def atlas(frames, name, output=OUT):
    w, h = frames[0].size
    sheet = Image.new('RGBA', (w * len(frames), h))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    output.mkdir(parents=True, exist_ok=True)
    sheet.save(output / (name + '.png'))
    return sheet


def sonic_art(output=OUT):
    # Redraw the existing motifs directly on their final pixel grids. No resize
    # or runtime coarse-grid sampling: these pixels are displayed at 1x.
    waves = []
    for i in range(8):
        # Keep a horizontal silhouette inside the square padded canvas.
        frame = Image.new('RGBA', (32, 32))
        d = ImageDraw.Draw(frame)
        phase = i * math.tau / 8
        strands = []
        for side in (0, math.pi):
            points = []
            for x in range(2, 30):
                progress = (x - 2) / 27
                radius = 2 + 5.5 * progress
                angle = progress * math.tau * 1.65 - phase + side
                points.append((x, round(15.5 + radius * math.sin(angle))))
            strands.append(points)
        for points in strands:
            d.line(points, fill='#241b43', width=4, joint='curve')
        d.line(strands[1], fill='#7962b9', width=2, joint='curve')
        d.line(strands[0], fill='#dfd5ff', width=2, joint='curve')
        # Highlights stay on the continuous front strand, never as stray dots.
        for x, y in strands[0]:
            if math.cos((x-2) / 27 * math.tau * 1.65 - phase) > 0.3:
                d.point((x, y), fill='#ffffff')
        waves.append(frame)
    atlas(waves, 'sonic_wave', output)
    charges = []
    hits = []
    for i in range(6):
        im = Image.new('RGBA', (20, 20))
        d = ImageDraw.Draw(im)
        radius = 7 - i
        d.ellipse((9-radius, 9-radius, 10+radius, 10+radius), outline=(177, 149, 246, 220), width=1)
        d.rectangle((9, 9, 10, 10), fill=(237, 223, 255, 255))
        charges.append(im)
        im = Image.new('RGBA', (32, 32))
        d = ImageDraw.Draw(im)
        radius = (3, 5, 8, 10, 12, 14)[i]
        color = (213, 198, 255, 255 - i * 35)
        # Merge the old tiny broken arcs into one readable expanding ring.
        d.ellipse((15-radius, 15-radius, 16+radius, 16+radius), outline=color, width=1)
        hits.append(im)
    atlas(charges, 'sonic_charge', output)
    atlas(hits, 'sonic_hit', output)


def sonic_warning_art():
    # Existing 1x path warning is independent of the three redrawn effects.
    warning = Image.new('RGBA', (320, 20))
    d = ImageDraw.Draw(warning)
    d.rectangle((0, 0, 319, 19), fill=(255, 68, 58, 31))
    d.line((0, 0, 319, 0), fill=(255, 104, 91, 170), width=1)
    d.line((0, 19, 319, 19), fill=(255, 104, 91, 170), width=1)
    # Fixed markings bake the visual language of the miniboss into one texture.
    for x in range(9, 320, 24):
        d.rectangle((x, 1, x+2, 2), fill=(255, 148, 129, 150))
        d.rectangle((x, 17, x+2, 18), fill=(255, 148, 129, 150))
    warning.save(OUT / 'sonic_warning.png')


def assemble(directory, output):
    paths = sorted(directory.glob('frame_*.png'))
    assert paths, 'No actual engine captures'
    # Keep actual viewport pixels; resizing would soften the reviewed outlines.
    frames = [Image.open(p).convert('RGB') for p in paths]
    # One shared palette keeps the terrain stable from frame to frame.
    width, height = frames[0].size
    samples = Image.new('RGB', (width, height * 8))
    for i in range(8):
        samples.paste(frames[min(len(frames)-1, i*len(frames)//8)], (0, i*height))
    palette = samples.quantize(colors=256)
    frames = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(output, save_all=True,
                   append_images=frames[1:], duration=50, loop=0, optimize=True)
    print('ENGINE_GIF_READY', len(frames), output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--rebuild', action='store_true')
    mode.add_argument('--rebuild-sonic', action='store_true')
    mode.add_argument('--assemble-captures', type=Path)
    parser.add_argument('--output-gif', type=Path)
    parser.add_argument('--effects-output', type=Path, default=OUT)
    args = parser.parse_args()
    if args.assemble_captures:
        if not args.output_gif:
            parser.error('--assemble-captures requires --output-gif')
        assemble(args.assemble_captures, args.output_gif)
        return
    if args.output_gif:
        parser.error('--output-gif requires --assemble-captures')
    if args.rebuild_sonic:
        sonic_art(args.effects_output)
        print('BAT_NATIVE_EFFECTS_READY', args.effects_output)
        return
    manifest = json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    records = {}
    for record in manifest['frames']:
        if 'atlas' in record:
            key = (Path(record['atlas']).stem,int(record['atlas_frame']))
        else:
            path = Path(record['frame'])
            key = (path.parent.name,int(path.stem)-1)
        assert key not in records, key
        records[key] = record
    expected = {(action,i) for action,count in (('move',6),('attack',9)) for i in range(count)}
    assert records.keys() == expected
    palette = {tuple(bytes.fromhex(color[1:])) for color in manifest['palette']}
    groups = {}
    for action,count in (('move',6),('attack',9)):
        sheet = Image.open(OUT/f'{action}.png').convert('RGBA')
        assert sheet.size == (96*count,96)
        frames = []
        for i in range(1,count+1):
            record = records[action,i-1]
            if 'frame' in record:
                path = ROOT/record['frame']
                encoded = path.read_bytes()
                image = Image.open(path).convert('RGBA')
            else:
                assert record['atlas'] == (OUT/f'{action}.png').relative_to(ROOT).as_posix()
                image = sheet.crop((96*(i-1),0,96*i,96))
                buffer = io.BytesIO()
                image.save(buffer,format='PNG')
                encoded = buffer.getvalue()
            assert hashlib.sha256(encoded).hexdigest() == record['frame_sha256'], (action,i)
            assert image.size == (96,96), (action,i)
            assert set(image.getchannel('A').tobytes()) == {0,255}, (action,i)
            colors = {rgba[:3] for _,rgba in image.getcolors(96*96) if rgba[3]}
            assert len(colors) <= 16 and colors <= palette, (action,i)
            frames.append(image)
        groups[action] = frames
    if args.rebuild:
        for action,frames in groups.items():
            atlas(frames,action)
        groups['move'][0].save(OUT/'idle.png')
        sonic_art()
        sonic_warning_art()
    for action,frames in groups.items():
        sheet = Image.open(OUT/f'{action}.png').convert('RGBA')
        assert sheet.size == (96*len(frames),96)
        for i,frame in enumerate(frames):
            assert sheet.crop((i*96,0,(i+1)*96,96)).tobytes() == frame.tobytes()
    idle = Image.open(OUT/'idle.png').convert('RGBA')
    assert idle.size == groups['move'][0].size and idle.tobytes() == groups['move'][0].tobytes()
    for name,size in {'sonic_wave':(256,32),'sonic_charge':(120,20),
                      'sonic_hit':(192,32),'sonic_warning':(320,20)}.items():
        assert Image.open(OUT/f'{name}.png').size == size
    print('BAT_PRODUCTION_VALID frames=15 atlases=2 effects=4 historical_packages_required=false')


if __name__ == '__main__':
    main()
