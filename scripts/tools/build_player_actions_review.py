"""Package verified real-GPU player animation captures for review."""
from pathlib import Path
import json
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / 'artifacts/previews/player_actions_128_20261014'
FRAMES = TASK / 'gpu_frames'
OUT = TASK / 'delivery'


def main():
    report = json.loads((FRAMES / 'capture.json').read_text(encoding='utf-8'))
    desktop = json.loads((TASK / 'live_gpu.json').read_text(encoding='utf-8'))
    assert report['valid'] and report['covered_frames'] == 50
    assert desktop['foreground_samples'] == 0
    assert desktop['verified_desktop'] == desktop['private_desktop']
    assert len(list(FRAMES.glob('frame_*.png'))) == report['frames']
    ffmpeg = shutil.which('ffmpeg')
    ffprobe = shutil.which('ffprobe')
    assert ffmpeg and ffprobe
    video = OUT / 'novice_128_live_review.mp4'
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '30',
                    '-i', str(FRAMES / 'frame_%04d.png'), '-frames:v', str(report['frames']),
                    '-c:v', 'libx264', '-preset', 'fast', '-crf', '16', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(video)], check=True)
    # This second video uses exactly the recorded frames at half speed.
    slow = OUT / 'novice_128_live_review_half_speed.mp4'
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '15',
                    '-i', str(FRAMES / 'frame_%04d.png'), '-frames:v', str(report['frames']),
                    '-c:v', 'libx264', '-preset', 'fast', '-crf', '16', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(slow)], check=True)
    media = {}
    for path in [video, slow]:
        info = json.loads(subprocess.check_output([ffprobe, '-v', 'error', '-select_streams', 'v:0',
             '-show_entries', 'stream=width,height,nb_frames,duration,avg_frame_rate', '-of', 'json', str(path)]))['streams'][0]
        assert int(info['nb_frames']) == report['frames']
        assert (info['width'], info['height']) == (1280,720)
        media[path.name] = info
    for path in OUT.glob('*_slow.gif'):
        with Image.open(path) as gif:
            assert gif.info['loop'] == 0
            durations = []
            for index in range(gif.n_frames):
                gif.seek(index)
                durations.append(gif.info.get('duration', 0))
            media[path.name] = {'frames':gif.n_frames,'duration_ms':sum(durations),'loop':0,'size':gif.size}
    # Evidence sheet: one actual viewport crop for each distinct played cell.
    clips = json.loads((ROOT / 'assets/sprites/player/actions/novice_128/animations.json').read_text(encoding='utf-8'))['clips']
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 17)
    board = Image.new('RGB', (1580, 7*176), '#111820')
    draw = ImageDraw.Draw(board)
    first = {}
    for frame in report['timeline']:
        first.setdefault((frame['clip'],frame['cell']),frame['frame'])
    for row, (clip, spec) in enumerate(clips.items()):
        y = row*176
        draw.text((12,y+4), clip, font=font, fill='#b3d4d0')
        for cell in range(spec['frames']):
            index = first[(clip,cell)]
            with Image.open(FRAMES / f'frame_{index:04d}.png') as image:
                crop = image.crop((568,280,712,424))
                board.paste(crop,(cell*158,y+28))
            draw.text((cell*158+4,y+24),f'{cell+1:02d}',font=font,fill='#ecdda2')
    board.save(OUT / 'live_all_50_frames.png')
    shutil.copyfile(FRAMES / 'capture.json', OUT / 'live_capture.json')
    shutil.copyfile(TASK / 'live_gpu.json', OUT / 'background_capture.json')
    (OUT / 'media_validation.json').write_text(json.dumps(media, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'video':str(video),'duration':report['frames']/30,'covered_frames':50,'real_casts':len(report['casts']),'media':media},indent=2))


if __name__ == '__main__':
    main()
