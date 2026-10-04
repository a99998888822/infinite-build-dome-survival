extends "res://scripts/battle/meadow_grass_rows.gd"
## Static ordered depth spans, two shared-buffer passes around the player.
## The GPU selects the side; player motion never rebuilds instance data.
const BAND_SHADER=preload("res://shaders/battle/meadow/grass_bands.gdshader")
var groups: Dictionary={}
var back_material:=ShaderMaterial.new()
var front_material:=ShaderMaterial.new()
var actor_cut:=INF
var cut_mode:="round"

func bind(target: MeadowBattleBackdrop) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cut="): cut_mode=arg.trim_prefix("--cut=")
	back_material.shader=BAND_SHADER
	front_material.shader=BAND_SHADER
	back_material.set_shader_parameter("front_pass",false)
	front_material.set_shader_parameter("front_pass",true)
	super.bind(target)
	back_material.set_shader_parameter("atlas_size",meadow.grass_atlas.get_size())
	front_material.set_shader_parameter("atlas_size",meadow.grass_atlas.get_size())

func set_mode(value: String) -> void:
	super.set_mode(value)
	_update_groups_visibility()

func _sync_cells() -> void:
	super._sync_cells()
	var bands: Dictionary={}
	for y in pending_rows: bands[float(floori(y/8.0)*8)]=true
	pending_rows=bands
	for y in rows.keys():
		if rows[y].grass.is_empty(): rows.erase(y)

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
	for band in pending_rows: _refresh_band(band)
	pending_rows.clear()
	_update_groups_visibility()
	update_us=Time.get_ticks_usec()-started
	peak_update_us=maxi(peak_update_us,update_us)

func _refresh_band(band: float) -> void:
	var spans: Array=[]
	var pending: Array=[]
	for n in range(int(band),int(band)+8):
		var y:=float(n)
		if block_rows.has(y):
			if not pending.is_empty(): spans.append(pending); pending=[]
			if not rows.has(y): continue
			var atoms: Array=rows[y].grass.duplicate()
			atoms.append_array(block_rows[y])
			atoms.sort_custom(func(a,b):return int(a.get_meta("row_order"))<int(b.get_meta("row_order")))
			var span: Array=[]
			for atom in atoms:
				if atom.has_meta("grass_id"): span.append(atom)
				elif not span.is_empty(): spans.append(span); span=[]
			if not span.is_empty(): spans.append(span)
		elif rows.has(y): pending.append_array(rows[y].grass)
	if not pending.is_empty(): spans.append(pending)
	if not groups.has(band): groups[band]=[]
	var list: Array=groups[band]
	while list.size()>spans.size():
		var old: Dictionary=list.pop_back()
		old.back.hide(); old.front.hide()
		old.back.queue_free(); old.front.queue_free()
	for i in spans.size():
		var grasses: Array=spans[i]
		if list.size()<=i: list.append(_create_group())
		var group: Dictionary=list[i]
		var multi: MultiMesh=group.multi
		if multi.instance_count<grasses.size(): multi.instance_count=maxi(4,int(pow(2,ceil(log(float(grasses.size()))/log(2.0)))))
		var data:=PackedFloat32Array()
		for grass in grasses: data.append_array(grass.get_meta("row_quad"))
		data.resize(multi.instance_count*16)
		multi.buffer=data
		multi.visible_instance_count=grasses.size()
		group.low=grasses[0].position.y
		group.high=grasses.back().position.y
		group.back.position=Vector2(0,group.low)
		group.front.position=Vector2(0,group.high)
		group.back_item.position=Vector2(0,-group.low)
		group.front_item.position=Vector2(0,-group.high)
		# Native Y sorting already orders different heights. Reordering thousands
		# of siblings for every upload was expensive; only exact prop ties need it.
		var first_order:=int(grasses[0].get_meta("row_order"))
		if group.low==group.high and block_rows.has(float(group.low)) and group.order!=first_order:
			meadow.roots.move_child(group.back,grasses[0].get_index())
			meadow.roots.move_child(group.front,grasses[0].get_index())
			group.order=first_order
		for grass in grasses:
			if bool(grass.get_meta("row_pending",false)):
				grass.set_meta("row_pending",false)
				grass.visible=mode!="batch"
		build_count+=1
	if list.is_empty(): groups.erase(band)

func _create_group() -> Dictionary:
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_2D
	multi.use_colors=true
	multi.use_custom_data=true
	multi.mesh=quad
	var group: Dictionary={"multi":multi,"low":0.0,"high":0.0,"order":-1}
	for side in ["back","front"]:
		var anchor:=Node2D.new()
		anchor.set_meta("meadow_grass_mesh",true)
		var item:=MultiMeshInstance2D.new()
		item.multimesh=multi
		item.texture=meadow.grass_atlas
		item.material=back_material if side=="back" else front_material
		item.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		anchor.add_child(item)
		meadow.roots.add_child(anchor)
		group[side]=anchor
		group[side+"_item"]=item
	node_builds+=2
	return group

func _update_groups_visibility() -> void:
	var viewport:=meadow.get_viewport()
	var view: Rect2=viewport.get_canvas_transform().affine_inverse()*viewport.get_visible_rect()
	active_batches=0
	for list: Array in groups.values():
		for group: Dictionary in list:
			var visible: bool=mode=="batch" and group.high>=view.position.y-64 and group.low<view.end.y+64
			group.back.visible=visible and group.low<actor_cut
			group.front.visible=visible and group.high>=actor_cut
			active_batches+=int(group.back.visible)+int(group.front.visible)

func _quad_data(grass: Sprite2D,_y: float) -> PackedFloat32Array:
	var rect:=grass.get_rect()
	var center:=grass.position+rect.get_center()
	var color:=grass.modulate
	var region:=grass.region_rect
	var tile:=floorf(region.position.x/32.0)+floorf(region.position.y/32.0)*(meadow.grass_atlas.get_width()/32)
	var key:=_height_key(grass.position.y)
	return PackedFloat32Array([rect.size.x,0,0,center.x,0,rect.size.y,0,center.y,color.r,color.g,color.b,color.a,tile,region.size.x,key.x,key.y])

func _height_key(y: float) -> Vector2:
	return Vector2(posmod(floori(y/256.0),256),posmod(int(y),256))
