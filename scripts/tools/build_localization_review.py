"""Package paired, real Godot viewport captures into an offline review gallery."""
from pathlib import Path
import argparse
import csv
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/localization/review'


def main():
    global OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUT)
    parser.add_argument('--baseline', type=Path)
    args = parser.parse_args()
    OUT = args.output.resolve()
    grouped = {}
    findings = []
    for path in sorted(OUT.glob('manifest_*.json')):
        manifest = json.loads(path.read_text(encoding='utf-8'))
        locale = manifest['locale']
        findings.extend(dict(item, locale=locale) for item in manifest['findings'])
        for shot in manifest['shots']:
            entry = grouped.setdefault(shot['id'], {'id': shot['id'], 'category': shot['category']})
            entry[locale] = shot
    entries = list(grouped.values())
    if findings:
        raise ValueError(f'Visible text audit failed: {findings}')
    missing = [(e['id'], lang) for e in entries for lang in ('zh_CN', 'en') if lang not in e]
    if missing:
        raise ValueError(f'Unpaired captures: {missing}')
    from PIL import Image
    thumbs = OUT / 'thumbs'
    thumbs.mkdir(exist_ok=True)
    for entry in entries:
        entry['title'] = entry['zh_CN']['title']
        for lang in ('zh_CN', 'en'):
            shot = entry[lang]
            source = OUT / shot['file']
            if not source.is_file():
                raise FileNotFoundError(source)
            thumbnail = thumbs / f'{lang}_{entry["id"]}.webp'
            with Image.open(source) as image:
                assert image.size == (1280, 720), (source, image.size)
                if not thumbnail.exists() or thumbnail.stat().st_mtime < source.stat().st_mtime:
                    image.thumbnail((640, 360))
                    image.save(thumbnail, quality=84)
            shot['thumbnail'] = thumbnail.relative_to(OUT).as_posix()
    review = {}
    if args.baseline:
        baseline = args.baseline.resolve()
        original = json.loads((OUT / 'round1_feedback.json').read_text(encoding='utf-8'))
        feedback = original['reviews']
        resolutions = json.loads((OUT / 'resolutions.json').read_text(encoding='utf-8'))
        missing_feedback = set(feedback) - {e['id'] for e in entries}
        if missing_feedback:
            raise ValueError(f'Missing revised feedback captures: {missing_feedback}')
        related = {
            'resolution_dropdown': 'menu_settings', 'battle_settings': 'menu_settings',
            'encyclopedia_categories': 'encyclopedia_empty',
            'sell_enchantment_bottom': 'sell_enchantment',
        }
        for path in (ROOT / 'data_config').glob('*.json'):
            if path.stem not in {'relics', 'weapons'}:
                continue
            for record in json.loads(path.read_text(encoding='utf-8')):
                if record.get('bond_id'):
                    related['encyclopedia_' + record['id']] = 'encyclopedia_empty'
        for entry in entries:
            key = entry['id']
            if key.startswith('select_character_'):
                related[key] = 'select_character_void_hunter_1'
            if key.startswith('settlement_'):
                related[key] = 'settlement_death_refused'
            if key.startswith('bank_'):
                related[key] = 'bank_shop'
            origin = key if key in feedback else related.get(key)
            entry['review_scope'] = 'primary' if key in feedback else ('related' if origin else 'accepted')
            if not origin:
                continue
            entry['feedback'] = feedback[origin]['note']
            entry['resolution'] = resolutions[origin]
            entry['feedback_source'] = origin
            entry['before'] = {}
            for lang in ('zh_CN', 'en'):
                source = baseline / lang / (key + '.png')
                if not source.exists():
                    continue
                target = OUT / 'before' / lang / source.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                thumbnail = thumbs / f'before_{lang}_{key}.webp'
                with Image.open(source) as image:
                    image.thumbnail((640, 360))
                    image.save(thumbnail, quality=84)
                entry['before'][lang] = {'file': target.relative_to(OUT).as_posix(),
                                         'thumbnail': thumbnail.relative_to(OUT).as_posix()}
            if len(entry['before']) not in (0, 2):
                raise ValueError(f'Unpaired baseline: {key}')
        review = {'round': 2, 'feedback_count': len(feedback), 'exported': original['exported'],
                  'storage_key': 'goblin-localization-review-round2'}
    messages = []
    for path in sorted((ROOT / 'localization/catalogs').glob('*.csv')):
        with path.open(encoding='utf-8', newline='') as stream:
            messages.extend(csv.DictReader(stream))
    data = {'screens': entries, 'messages': messages, 'findings': findings, 'review': review}
    template_name = 'localization_review_round2.html' if args.baseline else 'localization_review.html'
    template = (ROOT / 'scripts/tools/templates' / template_name).read_text(encoding='utf-8')
    html = template.replace('__REVIEW_DATA__', json.dumps(data, ensure_ascii=False).replace('<', '\\u003c'))
    (OUT / 'index.html').write_text(html, encoding='utf-8')
    before_count = sum(len(e.get('before', {})) for e in entries)
    report = {'pairs': len(entries), 'screenshots': len(entries) * 2, 'before_screenshots': before_count,
              'review_items': sum(e.get('review_scope') == 'primary' for e in entries), 'messages': len(messages),
              'findings': len(findings), 'categories': {k: sum(e['category'] == k for e in entries)
              for k in sorted({e['category'] for e in entries})}}
    (OUT / 'summary.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    archive_name = 'localization_review_round2' if args.baseline else 'localization_review'
    with zipfile.ZipFile(OUT.parent / (archive_name + '.zip'), 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in OUT.rglob('*'):
            if path.is_file() and path.suffix in {'.png', '.webp', '.html', '.json'}:
                compression = zipfile.ZIP_STORED if path.suffix in {'.png', '.webp'} else zipfile.ZIP_DEFLATED
                archive.write(path, archive_name + '/' + path.relative_to(OUT).as_posix(), compress_type=compression)
    print(json.dumps(report))


if __name__ == '__main__':
    main()
