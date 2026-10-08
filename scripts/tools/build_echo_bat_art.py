"""Check production bat artwork, or explicitly rebuild its atlases and effects.

No arguments only validates. Historical pixel-processing directories are unused.
--rebuild uses the current formal frames; --assemble-captures requires --output-gif.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/sprites/enemies/echo_bat'
SIZE = 128


def atlas(frames, name):
    w, h = frames[0].size
    sheet = Image.new('RGBA', (w * len(frames), h))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * w, 0))
    sheet.save(OUT / (name + '.png'))
    return sheet


def sonic_art():
    # Local pixel drawing at native resolution. Runtime only selects PNG frames.
    waves = []
    for i in range(8):
        # Draw at half resolution, then nearest upscale: every visible pixel
        # occupies a 2x2 block. Two rotating helical strands form a sonic drill.
        frame = Image.new('RGBA', (24, 16))
        d = ImageDraw.Draw(frame)
        phase = i * math.tau / 8
        strands = []
        for side in (0, math.pi):
            points = []
            for x in range(3, 22):
                radius = 2 + 3 * (x - 3) / 18
                angle = (x - 3) / 18 * math.tau * 1.65 - phase + side
                points.append((x, round(8 + radius * math.sin(angle))))
            strands.append(points)
        for points in strands:
            d.line(points, fill='#241b43', width=3)
        d.line(strands[1], fill='#7962b9', width=1)
        d.line(strands[0], fill='#dfd5ff', width=1)
        # The front-facing bright sections rotate across a darker back strand.
        for x, y in strands[0]:
            if math.cos((x-3) / 18 * math.tau * 1.65 - phase) > 0.3:
                d.point((x, y), fill='#ffffff')
        d.point((1, 8), fill='#7962b9')
        d.point((22, 8), fill='#dfd5ff')
        waves.append(frame.resize((48, 32), Image.Resampling.NEAREST))
    atlas(waves, 'sonic_wave')
    charges = []
    hits = []
    for i in range(6):
        im = Image.new('RGBA', (40, 40))
        d = ImageDraw.Draw(im)
        radius = 14 - i * 2
        d.ellipse((20-radius, 20-radius, 20+radius, 20+radius), outline=(177, 149, 246, 220), width=2)
        d.rectangle((18, 18, 22, 22), fill=(237, 223, 255, 255))
        charges.append(im)
        im = Image.new('RGBA', (48, 48))
        d = ImageDraw.Draw(im)
        radius = 5 + i * 3
        color = (213, 198, 255, 255 - i * 35)
        for a in range(0, 360, 60):
            d.arc((24-radius, 24-radius, 24+radius, 24+radius), a, a+36, fill=color, width=2)
        hits.append(im)
    atlas(charges, 'sonic_charge')
    atlas(hits, 'sonic_hit')
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
    mode.add_argument('--assemble-captures', type=Path)
    parser.add_argument('--output-gif', type=Path)
    args = parser.parse_args()
    if args.assemble_captures:
        if not args.output_gif:
            parser.error('--assemble-captures requires --output-gif')
        assemble(args.assemble_captures, args.output_gif)
        return
    if args.output_gif:
        parser.error('--output-gif requires --assemble-captures')
    manifest = json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    records = {record['frame']:record for record in manifest['frames']}
    expected = {f'assets/sprites/enemies/echo_bat/{action}/{i:02}.png'
                for action,count in (('move',6),('attack',9)) for i in range(1,count+1)}
    assert records.keys() == expected
    palette = {tuple(bytes.fromhex(color[1:])) for color in manifest['palette']}
    groups = {}
    for action,count in (('move',6),('attack',9)):
        frames = []
        for i in range(1,count+1):
            path = OUT/action/f'{i:02}.png'
            record = records[path.relative_to(ROOT).as_posix()]
            assert hashlib.sha256(path.read_bytes()).hexdigest() == record['frame_sha256'], path
            image = Image.open(path).convert('RGBA')
            assert image.size == (128,128), path
            assert set(image.getchannel('A').tobytes()) == {0,255}, path
            colors = {rgba[:3] for _,rgba in image.getcolors(128*128) if rgba[3]}
            assert len(colors) <= 16 and colors <= palette, path
            frames.append(image)
        groups[action] = frames
    if args.rebuild:
        for action,frames in groups.items():
            atlas(frames,action)
        shutil.copyfile(OUT/'move/01.png',OUT/'idle.png')
        sonic_art()
    for action,frames in groups.items():
        sheet = Image.open(OUT/f'{action}.png').convert('RGBA')
        assert sheet.size == (128*len(frames),128)
        for i,frame in enumerate(frames):
            assert sheet.crop((i*128,0,(i+1)*128,128)).tobytes() == frame.tobytes()
    assert (OUT/'idle.png').read_bytes() == (OUT/'move/01.png').read_bytes()
    for name,size in {'sonic_wave':(384,32),'sonic_charge':(240,40),
                      'sonic_hit':(288,48),'sonic_warning':(320,20)}.items():
        assert Image.open(OUT/f'{name}.png').size == size
    print('BAT_PRODUCTION_VALID frames=15 atlases=2 effects=4 historical_packages_required=false')


if __name__ == '__main__':
    main()
