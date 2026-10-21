# Native HUD pixel fonts

These bitmap font resources preserve the project's existing Ark Pixel glyph art
while storing glyph extents, advances, ascent and descent in native HUD units.
They do not resize any Control or introduce a second UI canvas.

- `interface.res`: native interface sizes 17, 18, 20, 23, 27, 30, 33 and 40.
- `character.res`: native character dossier sizes 20, 24 and 33.

The authoring script reads characters from the UI, data and localization catalogs.
Regenerate after adding text that needs additional glyphs:

```text
godot --headless --path . --script res://scripts/tools/bake_native_hud_fonts.gd
```

Use `-- --character-only` to rebuild only the character-selection font. Bitmap
resources explicitly use `oversampling = 1.0`; allowing viewport oversampling
requests unbaked glyph caches at smaller window sizes and makes labels invisible.
This also affects fullscreen displays larger than the 1920 x 1080 design canvas.
Commit the regenerated `.res` files along with authoring changes: changing the
script alone does not update the font used by the game. The baker reloads each
saved resource to check its oversampling and atlas pages.

Run `scenes/tests/fullscreen_font_test.tscn` headless to check the saved resources.
For GPU regression checks, run it through `scripts/tools/run_godot_background.py`
with `--transient-session` and optionally `--capture-dir=res://artifacts/reviews/fullscreen_font/after`.
It checks actual rendered glyph pixels at different window sizes and through
fullscreen round trips, and captures settings, talents, character selection and
the battle HUD. The test isolates window preferences and progression saves.

The ratios in that authoring script only produce assets. Runtime layouts use
1920 x 1080 coordinates and request the native point sizes directly. Subpixel
positioning keeps fractional advances from being rounded separately for every
character; nearest filtering retains the existing pixel artwork.
