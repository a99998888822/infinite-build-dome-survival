extends Node2D
## Review-only overlay: outlines come from the live physics shapes, not art boxes.
var player: PlayerController
var enemies: Array[EnemyController] = []
var ground: CavernBattleBackdrop
var weapon: WeaponInstance
var caption := "1920×1080 · 原生像素与碰撞体审阅"
var names := {
	"enemy_mutated_grub": "幼体 128×128",
	"enemy_elite_rusher": "铁骑士 256×256",
	"enemy_echo_bat": "蝙蝠 128×128",
	"enemy_underworld_wolf": "冥狼：体型放大 2 倍",
}
const HERO := Color("67e4ff")
const ENEMY := Color("ffb35c")
const OBSTACLE := Color("9df080")
var font: Font = preload("res://assets/font/theme_global.tres").default_font

func _process(_delta: float) -> void:
	queue_redraw()

func outline(points: PackedVector2Array, color: Color, transform: Transform2D) -> void:
	if points.size() < 3: return
	var p := transform * points
	draw_colored_polygon(p, Color(color, .09))
	p.append(p[0])
	draw_polyline(p, color, 2.0, true)

func collider(node: CollisionShape2D, color: Color) -> void:
	if node == null or node.disabled or node.shape == null: return
	var points := PackedVector2Array()
	var shape := node.shape
	if shape is CircleShape2D:
		for i in 64: points.append(Vector2.from_angle(TAU*i/64.0)*shape.radius)
	elif shape is CapsuleShape2D:
		var straight: float = shape.height*.5-shape.radius
		for i in 33:
			points.append(Vector2(0,-straight)+Vector2.from_angle(PI+PI*i/32.0)*shape.radius)
		for i in 33:
			points.append(Vector2(0,straight)+Vector2.from_angle(PI*i/32.0)*shape.radius)
	elif shape is RectangleShape2D:
		var r := shape.get_rect()
		points = PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	outline(points,color,node.get_global_transform_with_canvas())

func label_sprite(sprite: Sprite2D, text: String, color: Color) -> void:
	var rect: Rect2 = sprite.get_global_transform_with_canvas()*sprite.get_rect()
	var pos := Vector2(rect.get_center().x-font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x*.5,rect.position.y-12)
	draw_string_outline(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,19,5,Color("11161d"))
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,19,color)

func _draw() -> void:
	if not is_instance_valid(player): return
	draw_style_box(panel_style(),Rect2(1010,164,875,118))
	draw_string(font,Vector2(1030,196),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
	draw_string(font,Vector2(1030,227),"青：玩家实体    橙：敌人实体    绿：障碍物实体",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color.WHITE)
	draw_string(font,Vector2(1030,257),"虚线：拾取 180    黄线：武器射程    仅审阅显示",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ccd5de"))
	collider(player.get_node("CollisionShape2D"),HERO)
	label_sprite(player.sprite,"玩家：下半身圆形 R24",HERO)
	var center := player.get_global_transform_with_canvas().origin
	var pickup := (player.get_node("PickupArea/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	for i in 48:
		draw_arc(center,pickup.radius,i*TAU/48.0,(i+.48)*TAU/48.0,4,Color(HERO,.6),1.0,true)
	if weapon != null:
		var reach := weapon.get_attack_range()
		var end := center+Vector2(reach,0)
		draw_line(center,end,Color("ffe08a"),2.0)
		draw_line(end+Vector2(0,-8),end+Vector2(0,8),Color("ffe08a"),2.0)
		draw_string_outline(font,center+Vector2(45,30),"武器射程 %d" % int(reach),HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,Color("11161d"))
		draw_string(font,center+Vector2(45,30),"武器射程 %d" % int(reach),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe08a"))
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive or not enemy.sprite.is_visible_in_tree(): continue
		collider(enemy.get_node("CollisionShape2D"),ENEMY)
		label_sprite(enemy.sprite,str(names.get(enemy.enemy_id,enemy.enemy_id)),ENEMY)
	if is_instance_valid(ground):
		for node in ground.find_children("*","CollisionPolygon2D",true,false):
			var polygon := node as CollisionPolygon2D
			if not polygon.disabled: outline(polygon.polygon,OBSTACLE,polygon.get_global_transform_with_canvas())

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.04,.06,.08,.86)
	style.set_corner_radius_all(8)
	return style
