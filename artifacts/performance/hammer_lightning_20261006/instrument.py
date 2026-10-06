from pathlib import Path
import re

root = Path(__file__).parent / 'project'
def edit(rel, fn):
    p = root / rel
    text = p.read_text(encoding='utf-8')
    p.write_text(fn(text), encoding='utf-8', newline='\n')

def import_probe(text):
    lines = text.splitlines(True)
    lines.insert(2, 'const HAMMER_PROBE = preload("res://scripts/tests/hammer_probe.gd")\n')
    return ''.join(lines)

def wrapper(text, name, args, returns='void'):
    pattern = rf'^func {re.escape(name)}\(([^\n]*)\) -> {returns}:\n'
    m = re.search(pattern, text, flags=re.M)
    assert m, name
    signature = m.group(0)
    impl = name + '_hammer_probe_impl'
    call = f'{impl}({args})'
    wrapper_text = signature + '\tvar started := Time.get_ticks_usec() if HAMMER_PROBE.profiling else 0\n'
    wrapper_text += ('\t' if returns == 'void' else '\tvar result = ') + call + '\n'
    wrapper_text += f'\tHAMMER_PROBE.cost("{name}", started)\n'
    if returns != 'void': wrapper_text += '\treturn result\n'
    wrapper_text += '\n' + signature.replace(name, impl, 1)
    return text[:m.start()] + wrapper_text + text[m.end():]

def lightning(t):
    t = import_probe(t)
    t = t.replace('func _strike_ground(ground_position: Vector2) -> void:\n', 'func _strike_ground(ground_position: Vector2) -> void:\n\tHAMMER_PROBE.count("strikes")\n')
    t = t.replace('func _emit_hit_burst(hit_position: Vector2, burst_direction: Vector2) -> void:\n', 'func _emit_hit_burst(hit_position: Vector2, burst_direction: Vector2) -> void:\n\tHAMMER_PROBE.count("hit_bursts")\n\tif HAMMER_PROBE.remove_spray: return\n')
    t = t.replace('\tbolt.cell_size = 2', '\tbolt.rim_enabled = not HAMMER_PROBE.remove_glow\n\tbolt.cell_size = 2')
    t = t.replace('func _emit_bolt_light(global_position: Vector2, distance: float, glow_multiplier: float) -> void:\n', 'func _emit_bolt_light(global_position: Vector2, distance: float, glow_multiplier: float) -> void:\n\tif HAMMER_PROBE.remove_glow: return\n')
    t = t.replace('\t\tif dealt_damage > 0:\n', '\t\tif dealt_damage > 0:\n\t\t\tHAMMER_PROBE.count("thunder_enemy_hits")\n')
    t = wrapper(t, '_damage_ground_enemies', 'ground_position')
    t = wrapper(t, '_create_bolt_path', 'start_position, end_position, previous_points', 'Node2D')
    return t
edit('scripts/effects/lightning_particle_effect.gd', lightning)

def bolt(t):
    t = import_probe(t).replace('func build() -> void:\n', 'func build() -> void:\n\tHAMMER_PROBE.count("bolt_meshes")\n')
    t = t.replace('\tvertex_count = vertices.size()', '\tHAMMER_PROBE.count("bolt_vertices", vertices.size())\n\tvertex_count = vertices.size()')
    return wrapper(t, 'build', '')
edit('scripts/effects/lightning_pixel_bolt.gd', bolt)

def particle(t):
    t = import_probe(t)
    t = t.replace('\t# Reserve capacity for impacts;', '\tHAMMER_PROBE.count("requested_" + profile_id, count)\n\t# Reserve capacity for impacts;')
    t = t.replace('\tvar speed_multiplier :=', '\tHAMMER_PROBE.count("spawned_" + profile_id, count)\n\tvar speed_multiplier :=')
    for name, args in [('emit_event','event'),('_process','delta'),('_draw','')]:
        t = wrapper(t, name, args)
    return t
edit('scripts/effects/particle_world.gd', particle)

def spark(t):
    t = import_probe(t)
    return wrapper(t, '_draw', '')
edit('scripts/effects/electric_spark_effect.gd', spark)

def hammer(t):
    t = import_probe(t)
    t = t.replace('\tnode_created.emit(index, point)', '\tHAMMER_PROBE.count("hammer_nodes")\n\tnode_created.emit(index, point)')
    return wrapper(t, '_emit_node', 'index, ray')
edit('scripts/weapons/earth_hammer.gd', hammer)
print('Review-only instrumentation applied')
