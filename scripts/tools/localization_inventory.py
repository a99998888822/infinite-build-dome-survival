"""Inventory player-facing text without modifying gameplay sources.

UTF-8 throughout. IDs survive subsequent inventories through catalog_meta.json.
"""
from __future__ import annotations
import argparse
import ast
import hashlib
import json
import re
import sys
from pathlib import Path
from localization_catalog import read_catalogs

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'localization'
CJK = re.compile(r'[\u3400-\u9fff]')
TOKEN = re.compile(r'#[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
FIELDS = {'display_name', 'name', 'title', 'description', 'shop_description', 'speech', 'body', 'detail', 'role'}
CATALOG = read_catalogs()


def script_strings(path):
    source = path.read_text(encoding='utf-8')
    for match in TOKEN.finditer(source):
        raw = match.group()
        if raw.startswith('#'): continue
        try: value = ast.literal_eval(raw)
        except (ValueError, SyntaxError): continue
        if not isinstance(value, str): continue
        if value in CATALOG:
            value = CATALOG[value]['zh_CN']
        elif not CJK.search(value):
            continue
        line = source.count('\n', 0, match.start()) + 1
        prefix = source[source.rfind('\n', 0, match.start()) + 1:match.start()]
        if re.search(r'\b(print|push_warning|push_error)\s*\(', prefix): continue
        yield value, {'file':path.relative_to(ROOT).as_posix(), 'line':line, 'raw':raw}


def data_strings(value, table, location='', record_id=''):
    if isinstance(value, dict):
        record_id = str(value.get('id', record_id))
        for key, child in value.items():
            child_path = location + '/' + key
            if isinstance(child, str) and CJK.search(child) and key in FIELDS:
                yield child, {'file':f'data_config/{table}.json', 'path':child_path, 'table':table, 'record_id':record_id, 'field':key}
            elif isinstance(child, (list, dict)):
                yield from data_strings(child, table, child_path, record_id)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            if isinstance(child, str) and CJK.search(child):
                yield child, {'file':f'data_config/{table}.json', 'path':location+'/'+str(index), 'table':table, 'record_id':record_id, 'field':location.split('/')[-1]}
            else: yield from data_strings(child, table, location+'/'+str(index), record_id)


def inventory():
    entries = {}
    def add(text, source):
        entry = entries.setdefault(text, {'source':text, 'locations':[]})
        entry['locations'].append(source)
    for folder in ('scripts', 'autoloads'):
        for path in sorted((ROOT/folder).rglob('*.gd')):
            if set(path.parts) & {'tools','tests','debug'} or path.name == 'localization.gd': continue
            for text, source in script_strings(path): add(text, source)
    for path in sorted((ROOT/'data_config').glob('*.json')):
        for text, source in data_strings(json.loads(path.read_text(encoding='utf-8')),path.stem): add(text, source)
    for path in sorted((ROOT/'scenes').rglob('*.tscn')):
        if set(path.parts) & {'tests','debug'}: continue
        for line_no,line in enumerate(path.read_text(encoding='utf-8').splitlines(),1):
            if not re.match(r'\s*(text|tooltip_text|placeholder_text)\s*=',line): continue
            for match in TOKEN.finditer(line):
                try: text=ast.literal_eval(match.group())
                except (ValueError,SyntaxError): continue
                if text in CATALOG:
                    text = CATALOG[text]['zh_CN']
                if isinstance(text,str) and CJK.search(text): add(text,{'file':path.relative_to(ROOT).as_posix(),'line':line_no})
    previous = {}
    if (OUT/'catalog_meta.json').exists():
        previous={e['source']:e for e in json.loads((OUT/'catalog_meta.json').read_text(encoding='utf-8'))['entries']}
    # The catalog is authoritative. Updating wording preserves its explicit ID;
    # new candidates stay pending until someone assigns a meaningful key.
    catalog_sources = {}
    for key, row in CATALOG.items():
        catalog_sources.setdefault(row['zh_CN'], key)
    results=[]
    for index, entry in enumerate(entries.values()):
        prior=previous.get(entry['source'],{})
        entry['key']=catalog_sources.get(entry['source'], prior.get('key'))
        entry['status']='translated' if entry['key'] in CATALOG else 'pending'
        entry['index']=index
        entry['source_hash']=hashlib.sha256(entry['source'].encode('utf-8')).hexdigest()
        results.append(entry)
    return results


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parser=argparse.ArgumentParser()
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--count',type=int,default=0)
    args=parser.parse_args()
    entries=inventory()
    OUT.mkdir(exist_ok=True)
    # One entry per line: source locations remain inspectable without 15k+ lines
    # of indentation. This is development metadata, not a runtime dependency.
    serialized = '{"version":2,"entries":[\n' + ',\n'.join(json.dumps(entry,ensure_ascii=False,separators=(',', ':')) for entry in entries) + '\n]}\n'
    (OUT/'catalog_meta.json').write_text(serialized,encoding='utf-8')
    print('TOTAL='+str(len(entries)))
    if args.count:
        for entry in entries[args.start:args.start+args.count]: print(str(entry['index'])+' '+entry['source'].replace('\n','\\n'))


if __name__=='__main__': main()
