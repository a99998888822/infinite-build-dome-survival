"""Package native Godot captures into a comparison gallery; never synthesize attacks."""
from pathlib import Path
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--entry-index', type=Path)
    parser.add_argument('--update-gallery', type=Path,
                        help='Replace only captured weapons in a previously verified gallery.')
    args = parser.parse_args()
    report = json.loads((args.capture / 'review_report.json').read_text(encoding='utf-8'))
    desktop = json.loads((args.capture / 'runtime.json').read_text(encoding='utf-8'))
    assert not report['failures'], report['failures']
    assert desktop['exit_code'] == 0 and desktop['foreground_samples'] == 0
    assert desktop['private_desktop'] == desktop['verified_desktop']
    if args.update_gallery:
        previous = json.loads((args.update_gallery / 'verification.json').read_text(encoding='utf-8'))
        ids = {e['id'] for e in report['observations']}
        assert ids and ids.issubset({w['id'] for w in previous['weapons']})
        for weapon_id in ids:
            assert sorted(e['case'] for e in report['observations'] if e['id'] == weapon_id) == list(range(5))
    else:
        assert len(report['observations']) == 55
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / '.gdignore').touch()
    ffmpeg = shutil.which('ffmpeg')
    assert ffmpeg

    def encode(entry):
        key = entry['id'] + '_c' + str(entry['case'])
        samples = entry['samples']
        assert samples[0]['phase'] == 'aim' and samples[-1]['phase'] == 'result'
        lines = []
        for i, sample in enumerate(samples):
            path = (args.capture / sample['file']).resolve().as_posix()
            duration = ((samples[i + 1]['tick'] - sample['tick']) / report['physics_fps']
                        if i + 1 < len(samples) else .65)
            assert duration > 0
            last_file = "file '" + path.replace("'", "'\\''") + "'"
            lines.extend([last_file, 'option framerate 60', f'duration {duration:.9f}'])
        lines.extend([last_file, 'option framerate 60'])
        concat = args.capture / (key + '_concat.txt')
        concat.write_text('\n'.join(lines), encoding='utf-8')
        run([ffmpeg, '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(concat),
             '-fps_mode', 'vfr', '-enc_time_base', '1:60', '-c:v', 'libx264', '-bf', '0', '-preset', 'veryfast', '-crf', '19',
             '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(args.output / (key + '.mp4'))])
        actual_seconds = float(subprocess.check_output([
            'ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of',
            'default=noprint_wrappers=1:nokey=1', str(args.output / (key + '.mp4'))],
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)))
        expected_seconds = (samples[-1]['tick'] - samples[0]['tick']) / 60 + .65
        assert abs(actual_seconds - expected_seconds) <= .035, (key, actual_seconds, expected_seconds)
        entry['encoded_seconds'] = actual_seconds
        shutil.copyfile(args.capture / samples[0]['file'], args.output / (key + '_aim.png'))
        times = {'weapon_camp_dagger': .17, 'weapon_meteor_flail': .31,
                 'weapon_copper_lamp': .7, 'weapon_iron_grenade_cannon': .55,
                 'weapon_kunyu_ritual_tome': .55, 'weapon_mutant_tentacle': .10,
                 'weapon_earth_hammer': .99, 'weapon_nightwatch_spear': .20}
        attack = [s for s in samples if s['phase'] == 'attack']
        tick = attack[0]['tick'] + times.get(entry['id'], entry['action_ticks'] / 120) * 60
        peak = min(attack, key=lambda s: abs(s['tick'] - tick))
        shutil.copyfile(args.capture / peak['file'], args.output / (key + '_attack.png'))
        entry.update(video=key + '.mp4', aim=key + '_aim.png', attack=key + '_attack.png')
        return entry

    with ThreadPoolExecutor(max_workers=2) as pool:
        entries = list(pool.map(encode, report['observations']))
    weapons = []
    for entry in entries:
        if not weapons or weapons[-1]['id'] != entry['id']:
            weapons.append(dict(id=entry['id'], name=entry['name'], cases=[]))
        weapons[-1]['cases'].append(entry)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    for weapon in weapons:
        plate = Image.new('RGB', (1920, 360), '#101b1b')
        draw = ImageDraw.Draw(plate)
        draw.text((20, 10), weapon['name'] + '  |  ' + '\u4e0a\uff1a\u6307\u793a\u5668\uff1b\u4e0b\uff1a\u771f\u5b9e\u653b\u51fb\u5173\u952e\u5e27', font=font, fill='#c5edff')
        for i, entry in enumerate(weapon['cases']):
            draw.text((i * 384 + 8, 46), entry['case_name'], font=font, fill='#e2dbc3')
            for row, phase in enumerate(['aim', 'attack']):
                with Image.open(args.output / entry[phase]) as source:
                    # Same crop for every case, keeping the world scale identical.
                    crop = source.crop((0, 188, 1280, 575)).resize((384, 116), Image.Resampling.NEAREST)
                    # Full captures remain available in the gallery.
                    plate.paste(crop, (i * 384, 85 + row * 155))
            draw.text((i * 384 + 8, 201), f"R {entry['metrics']['reach']:.0f} / H {entry['metrics']['hit_radius']:.0f}", font=font, fill='#9bada7')
        plate.save(args.output / (weapon['id'] + '_comparison.png'))
        concat = args.capture / (weapon['id'] + '_videos.txt')
        concat.write_text('\n'.join("file '" + (args.output / e['video']).resolve().as_posix() + "'" for e in weapon['cases']), encoding='utf-8')
        run([ffmpeg, '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', str(concat),
             '-c', 'copy', '-movflags', '+faststart', str(args.output / (weapon['id'] + '.mp4'))])
        # Modest GIFs are portable to the conversation preview; original MP4s retain 1280x720.
        run([ffmpeg, '-y', '-v', 'error', '-i', str(args.output / (weapon['id'] + '.mp4')),
             '-filter_complex', '[0:v]fps=15,scale=768:-1:flags=neighbor,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none',
             '-loop', '0', str(args.output / (weapon['id'] + '.gif'))])
        print(weapon['id'], 'encoded', flush=True)
    dataset = dict(weapons=weapons, desktop=desktop, checks=report['checks'], revision=report.get('revision', 'R01'))
    gallery_root = args.output
    if args.update_gallery:
        gallery_root = args.update_gallery
        prefix = args.output.resolve().relative_to(gallery_root.resolve()).as_posix() + '/'
        for weapon in weapons:
            weapon['media_prefix'] = prefix
            for entry in weapon['cases']:
                for key in ('video', 'aim', 'attack'):
                    entry[key] = prefix + entry[key]
        replacements = {w['id']: w for w in weapons}
        previous['weapons'] = [replacements.get(w['id'], w) for w in previous['weapons']]
        previous.setdefault('updates', []).append(dict(
            folder=prefix, checks=report['checks'], desktop=desktop,
            weapons=sorted(replacements), cases=len(entries)))
        dataset = previous
    template = Path(__file__).with_name('weapon_range_gallery.html').read_text(encoding='utf-8')
    html = template.replace('__CAPTURE_DATA__', json.dumps(dataset, ensure_ascii=False).replace('</', '<\\/'))
    (gallery_root / 'index.html').write_text(html, encoding='utf-8')
    if args.entry_index:
        relative = gallery_root.resolve().relative_to(args.entry_index.resolve().parent).as_posix()
        entry_html = html.replace('<html lang="zh-CN">', '<html lang="zh-CN"><base href="' + relative + '/">', 1)
        args.entry_index.write_text(entry_html, encoding='utf-8')
    (gallery_root / 'verification.json').write_text(json.dumps(dataset, ensure_ascii=False, indent=2), encoding='utf-8')
    timing = [dict(file=e['video'], actual=e['encoded_seconds'],
                   expected=(e['samples'][-1]['tick'] - e['samples'][0]['tick']) / 60 + .65)
              for e in entries]
    (args.output / 'media_timing_check.json').write_text(json.dumps(timing, indent=2), encoding='utf-8')
    if args.update_gallery:
        timing_path = gallery_root / 'media_timing_check.json'
        previous_timing = json.loads(timing_path.read_text(encoding='utf-8'))
        replaced_names = {Path(e['file']).name for e in timing}
        previous_timing = [e for e in previous_timing if Path(e['file']).name not in replaced_names]
        timing_path.write_text(json.dumps(previous_timing + timing, indent=2), encoding='utf-8')
    shutil.copyfile(args.capture / 'review_report.json', args.output / 'review_report.json')
    print('GALLERY', (gallery_root / 'index.html').resolve(), flush=True)


if __name__ == '__main__':
    main()
