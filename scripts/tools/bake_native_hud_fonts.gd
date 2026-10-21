extends SceneTree
## One-time asset authoring: preserve approved pixel glyphs with native font metrics.
## Runtime controls request native point sizes and never scale a legacy font canvas.

const SOURCE = preload("res://assets/font/ark-pixel-12px-monospaced-zh_cn.otf")
const OUTPUT := "res://assets/font/native_hud/"

func _initialize() -> void:
	var characters := {}
	_collect_text("res://scripts/ui", characters)
	_collect_text("res://data_config", characters)
	_collect_text("res://localization", characters)
	for code in range(32, 256): characters[code] = true
	print("NATIVE_FONT_CHARACTERS ", characters.size())
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	if not OS.get_cmdline_user_args().has("--character-only"):
		_bake("interface.res", [[10,17],[11,18],[12,20],[14,23],[16,27],[18,30],[20,33],[24,40]], 5.0 / 3.0, characters)
	_bake("character.res", [[29,20],[34,24],[48,33]], 1920.0 / 2752.0, characters)
	quit()

func _collect_text(path: String, characters: Dictionary) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	for name in directory.get_files():
		if name.get_extension() not in ["gd", "json", "csv", "tscn"]: continue
		for code in FileAccess.get_file_as_string(path.path_join(name)).to_utf32_buffer().to_int32_array():
			if code >= 32 and SOURCE.has_char(code): characters[code] = true
	for name in directory.get_directories(): _collect_text(path.path_join(name), characters)

func _bake(filename: String, sizes: Array, ratio: float, characters: Dictionary) -> void:
	# Read unrounded advances separately: the source's integer glyph cache rounds
	# half-width Latin glyphs up at odd point sizes, but shaping retains the half.
	var metrics := SOURCE.duplicate() as FontFile
	metrics.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	var output := FontFile.new()
	# Bitmap pages are already rasterized; viewport oversampling cannot create
	# extra resolution caches from an empty font source at smaller windows.
	output.oversampling = 1.0
	output.font_name = "Ark Pixel Native HUD"
	output.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	output.hinting = TextServer.HINTING_NONE
	output.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	output.keep_rounding_remainders = true
	output.allow_system_fallback = true
	for pair in sizes:
		var source_size: int = pair[0]
		var native_size: int = pair[1]
		output.set_cache_ascent(0, native_size, SOURCE.get_ascent(source_size) * ratio)
		output.set_cache_descent(0, native_size, SOURCE.get_descent(source_size) * ratio)
		output.set_cache_underline_position(0, native_size, SOURCE.get_underline_position(source_size) * ratio)
		output.set_cache_underline_thickness(0, native_size, SOURCE.get_underline_thickness(source_size) * ratio)
		for outline in [0, 1, 2, 3]:
			var source_key := Vector2i(source_size, outline)
			var native_key := Vector2i(native_size, roundi(outline * ratio))
			for code: int in characters:
				var glyph := SOURCE.get_glyph_index(source_size, code, 0)
				SOURCE.render_glyph(0, source_key, glyph)
				output.set_glyph_advance(0, native_size, code, metrics.get_glyph_advance(0, source_size, glyph) * ratio)
				output.set_glyph_offset(0, native_key, code, SOURCE.get_glyph_offset(0, source_key, glyph) * ratio)
				output.set_glyph_size(0, native_key, code, SOURCE.get_glyph_size(0, source_key, glyph) * ratio)
				output.set_glyph_uv_rect(0, native_key, code, SOURCE.get_glyph_uv_rect(0, source_key, glyph))
				output.set_glyph_texture_idx(0, native_key, code, SOURCE.get_glyph_texture_idx(0, source_key, glyph))
			for index in SOURCE.get_texture_count(0, source_key):
				output.set_texture_image(0, native_key, index, SOURCE.get_texture_image(0, source_key, index))
		print(filename, " size=", native_size, " height=", output.get_height(native_size))
	assert(ResourceSaver.save(output, OUTPUT.path_join(filename), ResourceSaver.FLAG_COMPRESS) == OK)
	# Verify the saved artifact, not only the authoring object's configuration.
	var saved := ResourceLoader.load(OUTPUT.path_join(filename), "FontFile", ResourceLoader.CACHE_MODE_IGNORE) as FontFile
	assert(saved != null and is_equal_approx(saved.oversampling, 1.0), "Bitmap fonts must not request unbaked viewport-scale caches")
	for pair in sizes:
		assert(saved.get_texture_count(0, Vector2i(pair[1], 0)) > 0, "Saved bitmap font is missing an atlas")
