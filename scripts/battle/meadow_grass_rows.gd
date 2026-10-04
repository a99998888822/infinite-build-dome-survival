extends Node
## Exact world-root rows, persistent MultiMeshes, incremental streamed-cell updates.
const SHADER=preload("res://shaders/battle/meadow/grass_rows.gdshader")
var meadow: MeadowBattleBackdrop
var mode:="original"
var cells: Dictionary={}
var cell_rows: Dictionary={}
var cell_blocks: Dictionary={}
var rows: Dictionary={}
var blocks: Array[CanvasItem]=[]
var block_rows: Dictionary={}
var previous_cell:=Rect2i()
var material:=ShaderMaterial.new()
var quad:=QuadMesh.new()
var build_count:=0
var node_builds:=0
var active_batches:=0
var visible_grass:=0
var update_us:=0
var records: Array=[]
var serial:=0
var visible_rows:=Vector2i(-1000000000,1000000000)
var view_size:=Vector2.ZERO
var pending_rows: Dictionary={}
var peak_update_us:=0
var peak_pending_rows:=0

func bind(target: MeadowBattleBackdrop) -> void:
	meadow=target
	process_priority=80
	material.shader=SHADER
	quad.size=Vector2.ONE
	_sync_cells()

func _process(_delta: float) -> void:
	if not is_instance_valid(meadow) or not meadow.initialized or not meadow.enabled: return
	if not is_instance_valid(meadow.player): return
	if mode=="batch": update()

func _scan() -> void:
	if previous_cell!=meadow.cell_rect: _sync_cells()

func set_mode(value: String) -> void:
	mode=value
	_scan()
	for cell: Array in cells.values():
		for grass: Sprite2D in cell:
			if is_instance_valid(grass): grass.visible=mode!="batch" or bool(grass.get_meta("row_pending",false))
	for row: Dictionary in rows.values():
		for mesh: MultiMeshInstance2D in row.meshes: mesh.visible=mode=="batch" and mesh.position.y>=visible_rows.x and mesh.position.y<visible_rows.y
	if mode=="batch": update()

func update() -> void:
	var start:=Time.get_ticks_usec()
	_scan()
	var size:=get_tree().root.get_visible_rect().size
	if size!=view_size:
		view_size=size
		material.set_shader_parameter("view_size",size)
		material.set_shader_parameter("transition_bottom",ceilf(size.x/16.0)+74.0)
	_update_visible_rows()
	# New grass keeps its original Sprite2D until this row's buffer is ready.
	# Removed cells are outside the preload border; stale offscreen instances can
	# retire over several frames without changing the visible image.
	var work_start:=Time.get_ticks_usec()
	for y in pending_rows.keys():
		pending_rows.erase(y)
		if rows.has(y): _refresh_row(y)
		if Time.get_ticks_usec()-work_start>=1500: break
	update_us=Time.get_ticks_usec()-start
	peak_update_us=maxi(peak_update_us,update_us)

func _update_visible_rows() -> void:
	var viewport:=meadow.get_viewport()
	var view: Rect2=viewport.get_canvas_transform().affine_inverse()*viewport.get_visible_rect()
	var next:=Vector2i(floori((view.position.y-64)/32.0)*32,ceili((view.end.y+64)/32.0)*32)
	if next==visible_rows: return
	# Check row visibility only on a 32px boundary; never scan individual clumps.
	for y: float in rows:
		var was_visible:=y>=visible_rows.x and y<visible_rows.y
		var now_visible:=y>=next.x and y<next.y
		if was_visible==now_visible: continue
		for node: MultiMeshInstance2D in rows[y].meshes: node.visible=mode=="batch" and now_visible
	visible_rows=next

func _sync_cells() -> void:
	var dirty: Dictionary={}
	for key in cells.keys():
		if meadow.cells.has(key): continue
		for y in cell_rows[key]:
			rows[y].grass=rows[y].grass.filter(func(g):return is_instance_valid(g) and not g.is_queued_for_deletion())
			dirty[y]=true
		for block: Dictionary in cell_blocks[key]:
			for y in range(floori(block.y)-1,floori(block.y)+2): dirty[float(y)]=true
		cells.erase(key)
		cell_rows.erase(key)
		cell_blocks.erase(key)
	for key in meadow.cells:
		if cells.has(key): continue
		var original: Array[Sprite2D]=[]
		var ys: Dictionary={}
		var props: Array=[]
		for node: Node in meadow.cells[key].nodes:
			if node.get_parent()!=meadow.roots: continue
			node.set_meta("row_order",serial)
			serial+=1
			if node is CanvasItem and not node.has_meta("grass_id"):
				props.append({"node":node,"y":node.position.y})
				for y in range(floori(node.position.y)-1,floori(node.position.y)+2): dirty[float(y)]=true
			if not node is Sprite2D or not node.has_meta("grass_id"): continue
			var y: float=node.position.y
			if not rows.has(y): rows[y]={"grass":[],"meshes":[]}
			rows[y].grass.append(node)
			dirty[y]=true
			original.append(node)
			ys[y]=true
			node.set_meta("row_quad",_quad_data(node,y))
			node.set_meta("row_pending",true)
			node.visible=true
		cells[key]=original
		cell_rows[key]=ys.keys()
		cell_blocks[key]=props
	blocks.clear()
	block_rows.clear()
	for props: Array in cell_blocks.values():
		for prop: Dictionary in props:
			blocks.append(prop.node)
			for y in range(floori(prop.y)-1,floori(prop.y)+2):
				var key:=float(y)
				if not block_rows.has(key): block_rows[key]=[]
				block_rows[key].append(prop.node)
	for y in dirty:
		if rows.has(y): pending_rows[y]=true
	peak_pending_rows=maxi(peak_pending_rows,pending_rows.size())
	previous_cell=meadow.cell_rect
	active_batches=0
	records.clear()
	for cell: Array in cells.values(): records.append_array(cell)
	for row: Dictionary in rows.values(): active_batches+=row.meshes.size()

func _refresh_row(y: float) -> void:
	var row: Dictionary=rows[y]
	if row.grass.is_empty():
		for mesh: Node2D in row.meshes:
			mesh.hide()
			mesh.queue_free()
		rows.erase(y)
		return
	var spans: Array=[]
	if not block_rows.has(y):
		# Existing entries keep their original order; new cells append at the end.
		spans.append(row.grass)
	else:
		var atoms: Array=row.grass.duplicate()
		atoms.append_array(block_rows[y])
		atoms.sort_custom(func(a,b):return int(a.get_meta("row_order"))<int(b.get_meta("row_order")))
		var current: Array=[]
		for atom in atoms:
			if atom.has_meta("grass_id"): current.append(atom)
			elif not current.is_empty():
				spans.append(current)
				current=[]
		if not current.is_empty(): spans.append(current)
	while row.meshes.size()>spans.size():
		var old: Node2D=row.meshes.pop_back()
		old.hide()
		old.queue_free()
	for i in spans.size():
		if row.meshes.size()<=i: row.meshes.append(_new_mesh(y))
		var node: MultiMeshInstance2D=row.meshes[i]
		_fill(node,spans[i],y)
		meadow.roots.move_child(node,spans[i][0].get_index())
	for grass in row.grass:
		grass.set_meta("row_pending",false)
		grass.visible=mode!="batch"

func _new_mesh(y: float) -> MultiMeshInstance2D:
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_2D
	multi.use_colors=true
	multi.use_custom_data=true
	multi.mesh=quad
	var node:=MultiMeshInstance2D.new()
	node.position=Vector2(0,y)
	node.multimesh=multi
	node.texture=meadow.grass_atlas
	node.material=material
	node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	node.set_meta("meadow_grass_mesh",true)
	meadow.roots.add_child(node)
	node_builds+=1
	return node

func _fill(node: MultiMeshInstance2D, grasses: Array,y: float) -> void:
	var multi:=node.multimesh
	if multi.instance_count<grasses.size():
		multi.instance_count=maxi(4,int(pow(2,ceil(log(float(grasses.size()))/log(2.0)))))
	var data:=PackedFloat32Array()
	for grass in grasses: data.append_array(grass.get_meta("row_quad"))
	data.resize(multi.instance_count*16)
	multi.buffer=data
	multi.visible_instance_count=grasses.size()
	node.visible=mode=="batch" and y>=visible_rows.x and y<visible_rows.y
	build_count+=1

func _quad_data(grass: Sprite2D,y: float) -> PackedFloat32Array:
	var rect:=grass.get_rect()
	var center:=grass.position+rect.get_center()-Vector2(0,y)
	var color:=grass.modulate
	var uv:=Rect2(grass.region_rect.position/meadow.grass_atlas.get_size(),grass.region_rect.size/meadow.grass_atlas.get_size())
	return PackedFloat32Array([rect.size.x,0,0,center.x,0,rect.size.y,0,center.y,color.r,color.g,color.b,color.a,uv.position.x,uv.position.y,uv.size.x,uv.size.y])
