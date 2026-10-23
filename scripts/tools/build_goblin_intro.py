"""Compose a seven-second intro from the shipped menu art; no game state changes.

Pillow renders native pixel eye patches and the camera crop. FFmpeg writes
silent 1080p60 video with no audio stream.
No subtitles are rendered; the English VO is left unrecorded.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[2]
SIZE = (1920, 1080)
FPS = 60
SECONDS = 7
ART = PROJECT / "assets/ui/main_menu/bg_main_menu.png"
TITLE = PROJECT / "assets/ui/main_menu/title_main_menu.png"
GAZE_FRAME = 129
INK = (25, 16, 28)
CREAM = (232, 200, 173)
# Inclusive row spans cover the original pupils as well as the sclera. Leaving
# the dark pixels at (835, 329) intact would suggest a second, forward pupil.
EYE_ROWS = [
    [(327, 792, 795), (328, 791, 796), (329, 791, 797), (330, 795, 798)],
    [(328, 837, 838), (329, 831, 838), (330, 829, 837), (331, 829, 835), (332, 832, 833)],
]


def eye_frame(source, step):
    """Look left initially; the final gaze is the unmodified original artwork."""
    assert 0 <= step <= 3
    result = source.copy()
    if step == 3:
        return result
    for index, rows in enumerate(EYE_ROWS):
        mask = Image.new('L', source.size)
        md = ImageDraw.Draw(mask)
        for y, left, right in rows:
            md.line((left, y, right, y), fill=255)
        eye = Image.new('RGB', source.size, CREAM)
        d = ImageDraw.Draw(eye)
        y = 327 if index == 0 else 329
        d.rectangle((0, y + 2, source.width, source.height), fill=(197, 145, 120))
        x = (791, 792, 793)[step] if index == 0 else (831, 833, 834)[step]
        d.rectangle((x, y, x + 1, y + 2), fill=INK)
        d.line((x + 2, y + 1, x + 2, y + 2), fill=(147, 103, 84))
        result.paste(eye, (0, 0), mask)
    return result


def smoother(t):
    t = max(0.0, min(1.0, t))
    return t * t * t * (t * (t * 6 - 15) + 10)


def camera(t, source_size):
    width, height = source_size
    # The artwork is slightly wider than 16:9. Start with a centered fill crop.
    start_w, start_h = height * 16 / 9, float(height)
    start_x, start_y = (width - start_w) / 2, 0.0
    end_w, end_h = start_w * .60, start_h * .60
    # Right-aligned final crop preserves the art edge and places the eyes on
    # the right third, opposite the falling title. No invented border pixels.
    end_x, end_y = width - end_w, 174.0
    u = smoother((t - .5) / 1.7)
    x, y = start_x + (end_x-start_x)*u, start_y+(end_y-start_y)*u
    w, h = start_w+(end_w-start_w)*u, start_h+(end_h-start_h)*u
    assert 0 <= x <= width-w+.001 and 0 <= y <= height-h+.001
    return x, y, x+w, y+h


def title_y(t):
    elapsed = t - 5.0
    if elapsed < 0: return -500
    if elapsed < .55:
        return round(-430 + 512 * (1-(1-elapsed/.55)**3))
    if elapsed < .85:
        return round(82 - 16 * math.sin((elapsed-.55)/.30*math.pi))
    return 82


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(tempfile.gettempdir()) / 'goblin_intro_20261023_v4')
    args = parser.parse_args()
    ffmpeg = shutil.which('ffmpeg')
    ffprobe = shutil.which('ffprobe')
    assert ffmpeg and ffprobe
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = Image.open(ART).convert('RGB')
    source_hash = hashlib.sha256(ART.read_bytes()).hexdigest()
    eye_frames = [eye_frame(source, index) for index in range(4)]
    assert np.array_equal(np.array(eye_frames[3]), np.array(source))
    allowed = {(x, y) for rows in EYE_ROWS for y, left, right in rows for x in range(left, right+1)}
    changed = []
    for index, frame in enumerate(eye_frames):
        difference = np.any(np.array(frame) != np.array(source), axis=2)
        ys, xs = np.where(difference)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)] if len(xs) else None
        changed.append({'frame': index, 'pixels': int(difference.sum()), 'bounds': bounds})
        assert all((x, y) in allowed for y,x in zip(ys,xs))
        frame.crop((780, 316, 854, 344)).resize((888,336),Image.Resampling.NEAREST).save(out/f'eyes_{index}.png')
    title = Image.open(TITLE).convert('RGBA')
    title = title.resize((title.width*3, title.height*3), Image.Resampling.NEAREST)
    title_shadow = Image.new('RGBA', title.size, (16, 10, 24, 0))
    title_shadow.putalpha(title.getchannel('A').point(lambda a: round(a*.70)))
    shots = {0:'opening', 60:'push_in', 119:'before_glance', GAZE_FRAME:'gaze_turn', 132:'direct_gaze',
             150:'gaze_hold', 180:'clean_hold_1', 240:'clean_hold_2', 315:'title_falling', 360:'title_hold', 419:'final'}
    destination = out / 'goblin_intro.mp4'
    command = [ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-f', 'rawvideo', '-pixel_format', 'rgb24',
               '-video_size', '1920x1080', '-framerate', str(FPS), '-i', '-',
               '-map', '0:v:0', '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '16',
               '-pix_fmt', 'yuv420p', '-t', str(SECONDS),
               '-movflags', '+faststart', str(destination)]
    with (out/'render.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stderr=log)
        try:
            for frame in range(FPS*SECONDS):
                t = frame / FPS
                # Two short in-between poses, followed by the original image
                # at 2.15 s. No crossfade or redrawn final eyes.
                step = 0 if frame < 120 else 1 if frame < 124 else 2 if frame < GAZE_FRAME else 3
                picture = eye_frames[step].resize(SIZE, Image.Resampling.NEAREST, box=camera(t, source.size)).convert('RGBA')
                if t >= 5.0:
                    y = title_y(t)
                    picture.alpha_composite(title_shadow, (154, y+10))
                    picture.alpha_composite(title, (144, y))
                if frame in shots: picture.convert('RGB').save(out/(shots[frame]+'.png'))
                process.stdin.write(picture.convert('RGB').tobytes())
            process.stdin.close()
            code = process.wait(timeout=90)
            assert code == 0, (out/'render.log').read_text(encoding='utf-8')
        except BaseException:
            process.kill()
            process.wait()
            raise
    probe=json.loads(subprocess.check_output([ffprobe,'-v','error','-show_streams','-show_format','-of','json',str(destination)],encoding='utf-8'))
    video=next(s for s in probe['streams'] if s['codec_type']=='video')
    assert int(video['nb_frames'])==420 and abs(float(probe['format']['duration'])-7)<.02
    assert not any(s['codec_type']=='audio' for s in probe['streams'])
    assert not any(s['codec_type']=='subtitle' for s in probe['streams'])
    assert hashlib.sha256(ART.read_bytes()).hexdigest() == source_hash
    report={'duration':7,'fps':60,'resolution':list(SIZE),'bgm':0,'voiceover_recorded':False,
            'audio_streams':0,'chuckle_included':False,'original_gaze_from':GAZE_FRAME / FPS,
            'final_gaze_matches_source':True,'eye_changes':changed,'camera_final':list(camera(2.2,source.size)),
            'retained_width_and_height':.60,'title_interval':[5,7],
            'background_sha256':source_hash,
            'method':'Existing menu artwork composited locally. Only the initial and transitional eye openings are patched; final gaze uses the exact original. No audio or image model generation.',
            'subtitles':[],'title_retained':True}
    (out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'export.json').write_text(json.dumps(probe,indent=2),encoding='utf-8')
    print(destination)


if __name__ == '__main__':
    main()
