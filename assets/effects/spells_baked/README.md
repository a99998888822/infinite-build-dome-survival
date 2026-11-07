# Selected spell artwork

Production selection: water R02, black hole R03, ground lightning R01. Copper-lamp pixel art remains the style anchor. The hole sphere is already baked at 0.8 of its original visual radius; gameplay radius is unchanged.

Eight shared, lossless RGBA8 atlases use nearest filtering, no mipmaps and fixed union crops with 2px guards. Metadata contains frame dimensions, origin relative to the contact pivot, columns, count and 18fps sampling. Current allocated pixel estimate is **7.898 MiB**, shared across instances; this is not a measured driver allocation. Transparent GPU readback is converted from premultiplied to straight alpha during packing.

Water and the default 0.85s hole use 16 frames. Extended hole durations hold a separate 36-frame, 2s periodic middle, then play the closing tail. Ground lightning separates primary/echo columns, impact core, ground arcs and sparks. The existing yellow warning stays live. Flash visibility follows the exact gameplay clock; art advances at 18fps. Column height and ground radius scale independently. Dynamic chain lightning retains its current implementation.

Runtime: `scripts/effects/selected_spell_visual.gd`, `baked_ground_strike.gd`, and generated `selected_spell_frames.gd`. Loading prewarms nonempty atlas regions under the dungeon curtain. Runtime never reads review artifacts or the adjacent pixelfx repository. Damage, pulling, reactions and pause are controlled by their original spell controllers, not animation completion.

## Rebuild

Run from the project root with Python (Pillow and NumPy), Godot and the existing Windows background-capture helper:

```powershell
python scripts/tools/run_godot_background.py --godot <absolute-godot-engine.exe> --log artifacts/reviews/spell-baked-integration/bake.log --timeout 90 -- --path . --scene res://scenes/tests/bake_selected_spells.tscn
python scripts/tools/pack_selected_spells.py
<absolute-godot-console.exe> --headless --editor --path . --quit
```

Editable sources are in `scripts/tools/spell_vfx_sources/`; the capture driver is `scripts/tools/bake_selected_spells.gd`. `strike_points.json` records the deterministic reviewed paths. Keep the checked-in license files when rebuilding. Godot owns resource UID generation.

## Validation

`scenes/tests/selected_spell_baked_review.tscn` checks playback contracts and captures selected-source/production comparisons. Run GPU reviews through `run_godot_background.py`. Add `-- --benchmark` to measure isolated visual rendering for 1/20/100 instances. Other regressions cover terminal ranges, reactions, stacking, flash timing, RNG compatibility, loading cancellation and production battle depth. See `docs/spell_vfx_baked_integration_20261107.md` for results and limits.

## Attribution

Adapted water-ring movement, inward motes and ballistic sparks reference pixelfx, MIT, and its Sprite Fusion adaptations, MIT, Copyright (c) 2026 Hugo Duprez. Project palettes, silhouette treatment, timing and lightning geometry remain project adaptations. See `PIXELFX_LICENSE` and `PIXELFX_NOTICE.md`. No external font is included.
