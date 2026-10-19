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

The ratios in that authoring script only produce assets. Runtime layouts use
1920 x 1080 coordinates and request the native point sizes directly. Subpixel
positioning keeps fractional advances from being rounded separately for every
character; nearest filtering retains the existing pixel artwork.
