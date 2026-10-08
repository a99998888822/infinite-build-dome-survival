"""Read and validate the canonical UTF-8, semantic-key localization catalogs.

Run with --require-complete before shipping a localized build. An unfinished
inventory remains inspectable without assigning order-dependent or hash IDs.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOGS = ROOT / 'localization/catalogs'
MANIFEST = json.loads((ROOT / 'localization/locales.json').read_text(encoding='utf-8'))
LOCALES = [entry['id'] for entry in MANIFEST['locales']]
KEY = re.compile(r'[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+')
FORMAT = re.compile(r'%%|%[-+0#]*\d*(?:\.\d+)?[sdif]')
TAG = re.compile(r'\[(/?)([a-z]+)(?:=[^\]]*)?\]')
TOKEN = re.compile(r'#[^\n]*|"(?:\\.|[^"\\])*"')


def read_catalogs(directory=CATALOGS):
    messages = {}
    for path in sorted(directory.glob('*.csv')):
        with path.open(encoding='utf-8', newline='') as stream:
            reader = csv.DictReader(stream)
            if reader.fieldnames != ['keys', *LOCALES]:
                raise ValueError(f'{path.name}: expected keys,{",".join(LOCALES)} columns')
            for row in reader:
                key = row['keys']
                if not key or not KEY.fullmatch(key):
                    raise ValueError(f'{path.name}:{reader.line_num}: invalid semantic key {key!r}')
                if key in messages:
                    raise ValueError(f'{path.name}:{reader.line_num}: duplicate key {key}')
                if None in row or any(value is None for value in row.values()):
                    raise ValueError(f'{path.name}:{reader.line_num}: malformed CSV row')
                messages[key] = row
    return messages


def validate(require_complete=False):
    messages = read_catalogs()
    errors = []
    if len(set(LOCALES)) != len(LOCALES):
        errors.append('duplicate locale IDs in locales.json')
    for field in ['source_locale', 'fallback_locale']:
        if MANIFEST.get(field) not in LOCALES:
            errors.append(f'{field} must name a registered locale')
    for entry in MANIFEST['locales']:
        path = entry.get('title_texture', '')
        if not path.startswith('res://') or not (ROOT / path[6:]).is_file():
            errors.append(f'{entry["id"]}: title texture is missing')
    # Stable keys referenced by production scripts/scenes must exist. This also
    # catches typos that a CJK-only inventory cannot discover after migration.
    domains = {key.split('.')[0] for key in messages}
    for folder, suffix in [('scripts', '*.gd'), ('autoloads', '*.gd'), ('scenes', '*.tscn')]:
        for path in (ROOT / folder).rglob(suffix):
            if set(path.parts) & {'tests', 'debug', 'tools'}:
                continue
            for token in TOKEN.finditer(path.read_text(encoding='utf-8')):
                if token.group().startswith('#'):
                    continue
                key = token.group()[1:-1]
                if key.count('.') >= 2 and key.split('.')[0] in domains and KEY.fullmatch(key) and key not in messages:
                    errors.append(f'{path.relative_to(ROOT)}: unknown message key {key}')
    for key, row in messages.items():
        for locale in LOCALES:
            value = row[locale]
            if not value.strip():
                errors.append(f'{key}: empty {locale} translation')
            if '\ufffd' in value or '????' in value:
                errors.append(f'{key}: damaged {locale} encoding')
            if FORMAT.findall(row['zh_CN']) != FORMAT.findall(row[locale]):
                errors.append(f'{key}: {locale} positional format placeholders differ')
            if TAG.findall(row['zh_CN']) != TAG.findall(row[locale]):
                errors.append(f'{key}: {locale} BBCode tags differ')
    meta = json.loads((ROOT / 'localization/catalog_meta.json').read_text(encoding='utf-8'))
    pending = []
    for entry in meta['entries']:
        key = entry.get('key')
        if not key:
            pending.append(entry)
        elif key not in messages:
            errors.append(f'{key}: inventory references a missing catalog entry')
    if require_complete and pending:
        errors.append(f'{len(pending)} inventory candidates still need review and translation')
    for error in errors:
        print('ERROR: ' + error)
    print(f'Catalog messages: {len(messages)}; pending inventory candidates: {len(pending)}; errors: {len(errors)}')
    return not errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--require-complete', action='store_true')
    parser.add_argument('--build', action='store_true', help='Generate source aliases and register native translations')
    args = parser.parse_args()
    if not validate(args.require_complete):
        raise SystemExit(1)
    if args.build:
        build()


def build():
    messages = read_catalogs()
    output = ROOT / 'localization/generated'
    output.mkdir(exist_ok=True)
    aliases = {}
    metadata = json.loads((ROOT / 'localization/catalog_meta.json').read_text(encoding='utf-8'))
    for entry in metadata['entries']:
        if entry.get('key') in messages:
            aliases[entry['source']] = entry['key']
    for key, row in messages.items():
        if row['zh_CN'] in aliases:
            continue
        aliases[row['zh_CN']] = key
    with (output / 'source_aliases.csv').open('w', encoding='utf-8', newline='') as stream:
        writer = csv.writer(stream, lineterminator='\n')
        writer.writerow(['keys', *LOCALES])
        for source, key in sorted(aliases.items()):
            writer.writerow([source, *[messages[key][locale] for locale in LOCALES]])
    # Generated compatibility map for untranslated data fields and constants.
    # It contains no source locations, inventory indices, or gameplay state.
    (output / 'source_keys.json').write_text(json.dumps(aliases, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    resources = []
    for path in [*sorted(CATALOGS.glob('*.csv')), output / 'source_aliases.csv']:
        for locale in LOCALES:
            resources.append('res://' + path.relative_to(ROOT).with_suffix('.' + locale + '.translation').as_posix())
    project = ROOT / 'project.godot'
    original = project.read_text(encoding='utf-8')
    value = 'locale/translations=PackedStringArray(' + ', '.join(json.dumps(p) for p in resources) + ')'
    if '[internationalization]' not in original:
        original += '\n[internationalization]\n\n' + value + '\nlocale/fallback="zh_CN"\n'
    elif re.search(r'^locale/translations=.*$', original, flags=re.M):
        original = re.sub(r'^locale/translations=.*$', lambda _: value, original, flags=re.M)
    else:
        original = original.replace('[internationalization]', '[internationalization]\n\n' + value)
    project.write_text(original, encoding='utf-8')
    print(f'Built {len(resources)} native translation references and {len(aliases)} data source aliases.')


if __name__ == '__main__':
    main()
