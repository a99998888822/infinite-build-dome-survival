from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
BASE='res://artifacts/validation/pixel_effects_install_20261010/'
old=(OUT/'before/scripts/weapons/meteor_flail.gd').read_text(encoding='utf-8')
(OUT/'baseline_flail.gd').write_text('extends MeteorFlail\n'+old[old.index('func _draw() -> void:'):],encoding='utf-8')
test=(ROOT/'scripts/tests/meteor_flail_test.gd').read_text(encoding='utf-8')
test=test.replace('MeteorFlail.new()',f'(load("{BASE}baseline_flail.gd").new() as MeteorFlail)')
(OUT/'baseline_flail_test.gd').write_text(test,encoding='utf-8')
(OUT/'baseline_flail_test.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="'+BASE+'baseline_flail_test.gd" id="1"]\n[node name="BaselineFlailTest" type="Node2D"]\nscript = ExtResource("1")\n',encoding='utf-8')
review=ROOT/'artifacts/previews/pixel_effects_r01_20261010'
capture=(review/'capture.gd').read_text(encoding='utf-8')
capture=capture.replace('const BASE := "res://artifacts/previews/pixel_effects_r01_20261010/"','const BASE := "'+BASE+'"')
capture=capture.replace('BASE + "manifest.json"','"res://artifacts/previews/pixel_effects_r01_20261010/manifest.json"')
capture=capture.replace('for variant in ["baseline", "candidate"]:','for variant in ["installed"]:')
capture=capture.replace('if variant == "baseline":','if variant == "installed":')
capture=capture.replace('var img := get_tree().root.get_texture().get_image().get_region(CROP)', 'var region := Rect2i(320,100,640,520) if path.begins_with("renders/live_") else CROP\n\tvar img := get_tree().root.get_texture().get_image().get_region(region)')
capture=capture.replace('for key: String in manifest.effects:', 'for key: String in manifest.effects:\n\t\tif "--live-only" in OS.get_cmdline_user_args(): continue')
capture=capture.replace('for i in 18:', 'for i in (0 if "--live-only" in OS.get_cmdline_user_args() else 18):')
capture=capture.replace('"gpu_capture.json" if graphical else "headless.json"', '"gpu_live_capture.json" if "--live-only" in OS.get_cmdline_user_args() else "gpu_capture.json" if graphical else "headless.json"')
capture=capture.replace('\t# Existing copper lamp', '\tawait capture_live_variants()\n\t# Existing copper lamp')
capture+='\n'+(OUT/'live_variants.gdpart').read_text(encoding='utf-8')
(OUT/'capture.gd').write_text(capture,encoding='utf-8')
(OUT/'launch.gd').write_text('extends SceneTree\nfunc _initialize() -> void:\n\tboot.call_deferred()\nfunc boot() -> void:\n\troot.add_child(load("'+BASE+'capture.gd").new())\n',encoding='utf-8')
for name in ['godot_frames','renders']:(OUT/name).mkdir(exist_ok=True)
