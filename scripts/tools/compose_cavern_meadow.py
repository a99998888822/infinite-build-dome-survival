"""Compose the original production battlefield assets under cavern depth layers.

Only writes a scene configuration; all PNG sources remain byte-identical.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
source = json.loads((ROOT/'data_config/green_battlefield.json').read_text(encoding='utf-8'))

def asset(name):
    definition = source['assets'][name]
    return {'id':name,'texture':definition['texture'],'anchor':definition['anchor'],
            'source_sha256':hashlib.sha256((ROOT/definition['texture'][6:]).read_bytes()).hexdigest()}

config = {
    'source':'Original production meadow ground, grass, rubble and ruins',
    'method':'World-space surface projection and sparse grouped scenery; no image generation or PNG edits',
    'surface_texture':'res://assets/sprites/background/meadow/meadow-ground.png',
    'surface_context':'res://assets/sprites/background/meadow/ground-context.png',
    'floor_color':[.26,.28,.25,1.0],
    'ground':[], 'details':[],
    'grass':[asset(name) for name in source['groups']['grass']],
    'rubble':[asset(name) for name in source['groups']['rubble']],
    'props':[],
    'initial_groups':[],
    'preserved_depth_config':'res://data_config/cavern_battlefield.json',
}
for field in ['surface_texture','surface_context']:
    config[field+'_sha256'] = hashlib.sha256((ROOT/config[field][6:]).read_bytes()).hexdigest()
(ROOT/'data_config/cavern_meadow_battlefield.json').write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:len(config[key]) for key in ['ground','grass','rubble','props']}))
