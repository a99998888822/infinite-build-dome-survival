"""Reuse the approved real-contact fixture, with no enabling override for R02."""
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
REVIEW = ROOT / 'artifacts/previews/combat_feedback_r02_20261010'
source = (REVIEW / 'capture.gd').read_text(encoding='utf-8')
source = source.replace('res://artifacts/previews/combat_feedback_r02_20261010/', 'res://artifacts/validation/combat_feedback_r02_install_20261010/')
source = source.replace('var graphical := false', 'var graphical := false\nvar mark_sounds := 0')
source = source.replace('CampProgression.begin_transient_session()', 'CampProgression.begin_transient_session()\n\tAudioManager.combat_sfx_played.connect(func(cue: String, _path: String):\n\t\tif cue == "ritual_mark_r02": mark_sounds += 1)')
source = source.replace('GameGlobal.set_runtime_flag(RESPONSE.SETTINGS.FLAG, variant == "r02")', '''if variant == "before":
		GameGlobal.set_runtime_flag(RESPONSE.SETTINGS.FLAG, false)
	else:
		GameGlobal.clear_runtime_flag(RESPONSE.SETTINGS.FLAG)
		if GameGlobal.has_runtime_flag(RESPONSE.SETTINGS.FLAG) or not RESPONSE.enabled():
			failures.append("production default is not active")
	mark_sounds = 0''')
source = source.replace('var health: Array = []', '''var mark_pulses := 0
	for card in bar.cards:
		for child in card.get_children():
			if child.get_script() == preload("res://scripts/ui/weapon_pulse_r02.gd"):
				mark_pulses += child.pulses
	if variant == "r02" and entry.id in ["tome", "dense"]:
		if mark_pulses != 3 or mark_sounds != 3:
			failures.append(entry.id + " primary marks must produce three icon pulses and sounds")
	var health: Array = []''')
source = source.replace('"responses":responses}', '"responses":responses,"mark_pulses":mark_pulses,"mark_sounds":mark_sounds}')
source = source.replace('var screenshot := get_tree().root.get_texture().get_image()', '''if not id.ends_with("_r02") or frame not in [4,7,19,23,28,40,53,65]:
		return
	var screenshot := get_tree().root.get_texture().get_image()''')
(OUT / 'capture.gd').write_text(source, encoding='utf-8')
launch = (REVIEW / 'launch.gd').read_text(encoding='utf-8').replace('artifacts/previews/combat_feedback_r02_20261010/', 'artifacts/validation/combat_feedback_r02_install_20261010/')
(OUT / 'launch.gd').write_text(launch, encoding='utf-8')
print('PRODUCTION_FIXTURE_READY')
