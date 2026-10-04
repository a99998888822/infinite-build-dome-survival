extends "res://scripts/battle/meadow_grass_bands.gd"
## Upload streamed cells during the existing offscreen preload interval.
## If a pending cell reaches the view (including teleports), finish synchronously.
var upload_regions: Array[Rect2]=[]
var forced_visible_updates:=0

func _quad_data(_grass: Sprite2D,_y: float) -> PackedFloat32Array:
	# Cell registration stays cheap; prepare new quad attributes inside the budget.
	return PackedFloat32Array()

func _refresh_band(band: float) -> void:
	for n in range(int(band),int(band)+8):
		var y:=float(n)
		if not rows.has(y): continue
		for grass in rows[y].grass:
			var data: PackedFloat32Array=grass.get_meta("row_quad")
			if data.is_empty(): grass.set_meta("row_quad",super._quad_data(grass,y))
	super._refresh_band(band)

func _sync_cells() -> void:
	var added: Array=[]
	for key in meadow.cells:
		if not cells.has(key): added.append(key)
	super._sync_cells()
	for key in added:
		upload_regions.append(Rect2(Vector2(key)*256.0,Vector2(256,256)).grow(64))
		if mode=="batch":
			for grass in cells[key]: grass.hide()

func set_mode(value: String) -> void:
	super.set_mode(value)
	if mode=="batch":
		for cell: Array in cells.values():
			for grass in cell:
				if bool(grass.get_meta("row_pending",false)): grass.hide()

func update() -> void:
	var started:=Time.get_ticks_usec()
	_scan()
	var size:=get_tree().root.get_visible_rect().size
	if size!=view_size:
		view_size=size
		for mat in [back_material,front_material]:
			mat.set_shader_parameter("view_size",size)
			mat.set_shader_parameter("transition_bottom",ceilf(size.x/16.0)+74.0)
	var y:=meadow.proxy.position.y
	var next_cut:=floorf(y) if cut_mode=="floor" else (ceilf(y) if cut_mode=="ceil" else roundf(y))
	if actor_cut!=next_cut:
		actor_cut=next_cut
		back_material.set_shader_parameter("actor_key",_height_key(actor_cut))
		front_material.set_shader_parameter("actor_key",_height_key(actor_cut))
	var viewport:=meadow.get_viewport()
	var view: Rect2=viewport.get_canvas_transform().affine_inverse()*viewport.get_visible_rect()
	var force_all:=false
	for region in upload_regions:
		if region.intersects(view): force_all=true; break
	if force_all and not pending_rows.is_empty(): forced_visible_updates+=1
	var upload_start:=Time.get_ticks_usec()
	for band in pending_rows.keys():
		pending_rows.erase(band)
		_refresh_band(band)
		if not force_all and Time.get_ticks_usec()-upload_start>=1500: break
	if pending_rows.is_empty(): upload_regions.clear()
	_update_groups_visibility()
	update_us=Time.get_ticks_usec()-started
	peak_update_us=maxi(peak_update_us,update_us)
