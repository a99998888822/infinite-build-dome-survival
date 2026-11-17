"""Build an ignored instrumented copy; never wrap production methods in place."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[2]
lab = root / ".godot" / "seven_weapon_profile"
lab.mkdir(exist_ok=True)
for name in ["scripts", "scenes", "autoloads", "data_config", "localization", "shaders"]:
    shutil.copytree(root / name, lab / name, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__"))
shutil.copy2(root / "project.godot", lab / "project.godot")
(lab / ".godot").mkdir(exist_ok=True)
for name in ["global_script_class_cache.cfg", "uid_cache.bin"]:
    if (root / ".godot" / name).exists():
        shutil.copy2(root / ".godot" / name, lab / ".godot" / name)


def wrap(relative, name, signature, arguments, returns=False):
    path = lab / relative
    source = path.read_text(encoding="utf-8")
    source = source.replace("func " + name + "(", "func _probe_" + name + "(", 1)
    probe = 'preload("res://scripts/battle/combat_diagnostics.gd")'
    key = Path(relative).stem + "." + name
    wrapper = "\n\nfunc " + signature + ":\n"
    wrapper += f"\tvar started := {probe}.begin()\n"
    wrapper += "\t" + ("var result = " if returns else "") + f"_probe_{name}({arguments})\n"
    wrapper += f'\t{probe}.finish(&"scope.{key}", started)\n'
    wrapper += f'\t{probe}.count(&"scope.{key}.calls")\n'
    if returns:
        wrapper += "\treturn result\n"
    path.write_text(source + wrapper, encoding="utf-8")


for relative in ["scripts/enemies/enemy_controller.gd", "scripts/weapons/projectile_instance.gd",
                 "scripts/weapons/copper_lamp.gd", "scripts/weapons/camp_dagger.gd"]:
    wrap(relative, "_physics_process", "_physics_process(delta: float) -> void", "delta")
wrap("scripts/enemies/enemy_controller.gd", "_process_chase", "_process_chase() -> void", "")
wrap("scripts/enemies/enemy_controller.gd", "_chase_direction", "_chase_direction(destination: Vector2) -> Vector2", "destination", True)
wrap("scripts/weapons/projectile_instance.gd", "_sweep_flight", "_sweep_flight(step: float) -> void", "step")
wrap("scripts/weapons/camp_dagger.gd", "_contact", "_contact(cut: Dictionary, origin: Vector2, at: float) -> void", "cut, origin, at")
print(lab)
