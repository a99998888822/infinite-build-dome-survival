extends RefCounted
## Procedural pixel portraits for unreleased roster slots.


static func gray(texture: Texture2D, brightness: float) -> Texture2D:
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			var value := (color.r*0.299+color.g*0.587+color.b*0.114)*brightness
			image.set_pixel(x,y,Color(value,value,value,color.a))
	return ImageTexture.create_from_image(image)


static func silhouette(index: int) -> Texture2D:
	# Faceless human busts on a 48px grid. Each uses a distinct head/hair/hat
	# contour; large joined shapes and two solid tones, no antialiasing.
	var parts: Array[PackedVector2Array] = []
	parts.append(PackedVector2Array([Vector2(5,46),Vector2(7,37),Vector2(18,31),Vector2(18,27),Vector2(30,27),Vector2(30,31),Vector2(41,37),Vector2(43,46)]))
	match index:
		0: # Raised hood, pointed cloak shoulders.
			parts.append(PackedVector2Array([Vector2(9,34),Vector2(10,17),Vector2(16,7),Vector2(24,3),Vector2(32,8),Vector2(38,19),Vector2(39,34),Vector2(34,39),Vector2(14,39)]))
		1: # Bent pointed hat with a broad brim.
			parts.append(PackedVector2Array([Vector2(5,20),Vector2(16,18),Vector2(24,2),Vector2(35,5),Vector2(29,8),Vector2(32,18),Vector2(43,22),Vector2(39,25),Vector2(8,25)]))
			parts.append(PackedVector2Array([Vector2(15,22),Vector2(32,22),Vector2(33,31),Vector2(27,36),Vector2(18,32)]))
		2: # High ponytail with swept forehead.
			parts.append(PackedVector2Array([Vector2(15,13),Vector2(22,6),Vector2(33,7),Vector2(36,12),Vector2(44,13),Vector2(45,24),Vector2(40,34),Vector2(39,23),Vector2(35,19),Vector2(33,30),Vector2(24,34),Vector2(17,29)]))
		3: # Closed helmet with comb crest.
			parts.append(PackedVector2Array([Vector2(13,31),Vector2(11,15),Vector2(18,9),Vector2(18,3),Vector2(28,2),Vector2(32,5),Vector2(27,9),Vector2(35,14),Vector2(36,29),Vector2(30,35),Vector2(18,35)]))
		4: # Travel hat, dropped back brim.
			parts.append(PackedVector2Array([Vector2(3,19),Vector2(14,16),Vector2(17,7),Vector2(30,7),Vector2(34,16),Vector2(44,19),Vector2(43,24),Vector2(8,25)]))
			parts.append(PackedVector2Array([Vector2(15,21),Vector2(33,21),Vector2(32,31),Vector2(28,35),Vector2(19,32)]))
		5: # Strong jaw, broad mohawk.
			parts.append(PackedVector2Array([Vector2(12,18),Vector2(18,13),Vector2(18,3),Vector2(23,2),Vector2(23,5),Vector2(31,5),Vector2(31,10),Vector2(35,14),Vector2(36,26),Vector2(30,35),Vector2(18,35),Vector2(12,28)]))
		6: # Long flowing hair, offset parting.
			parts.append(PackedVector2Array([Vector2(8,39),Vector2(11,29),Vector2(10,17),Vector2(14,7),Vector2(24,4),Vector2(34,8),Vector2(38,17),Vector2(35,27),Vector2(41,39),Vector2(32,38),Vector2(27,32),Vector2(20,32),Vector2(17,39)]))
		7: # High collar, swept hair and angular profile.
			parts.append(PackedVector2Array([Vector2(8,28),Vector2(17,31),Vector2(14,23),Vector2(15,12),Vector2(12,8),Vector2(25,5),Vector2(35,9),Vector2(34,18),Vector2(39,23),Vector2(32,26),Vector2(29,32),Vector2(41,27),Vector2(37,42),Vector2(12,42)]))
		8: # Wide horned helmet and heavy shoulder plates.
			parts.append(PackedVector2Array([Vector2(5,3),Vector2(8,15),Vector2(17,10),Vector2(31,10),Vector2(40,15),Vector2(43,3),Vector2(46,16),Vector2(35,23),Vector2(34,32),Vector2(28,37),Vector2(20,37),Vector2(13,32),Vector2(12,23),Vector2(2,16)]))
			parts.append(PackedVector2Array([Vector2(2,34),Vector2(13,31),Vector2(24,39),Vector2(35,31),Vector2(46,34),Vector2(47,46),Vector2(1,46)]))
		9: # Round cloud of curls and a small chin.
			parts.append(PackedVector2Array([Vector2(7,27),Vector2(3,23),Vector2(4,14),Vector2(9,12),Vector2(9,6),Vector2(17,3),Vector2(22,5),Vector2(27,2),Vector2(36,5),Vector2(37,10),Vector2(43,13),Vector2(45,22),Vector2(40,27),Vector2(33,27),Vector2(30,34),Vector2(24,37),Vector2(17,33),Vector2(15,27)]))
		10: # Two high buns and long separated braids.
			parts.append(PackedVector2Array([Vector2(4,8),Vector2(8,3),Vector2(15,4),Vector2(18,10),Vector2(30,10),Vector2(33,4),Vector2(40,3),Vector2(44,8),Vector2(42,15),Vector2(37,18),Vector2(39,30),Vector2(44,40),Vector2(37,43),Vector2(32,31),Vector2(29,34),Vector2(19,34),Vector2(16,31),Vector2(11,43),Vector2(4,40),Vector2(9,30),Vector2(11,18),Vector2(6,15)]))
		11: # Plague doctor's long beak beneath a flat cap.
			parts.append(PackedVector2Array([Vector2(7,14),Vector2(11,5),Vector2(27,5),Vector2(32,14),Vector2(39,15),Vector2(39,19),Vector2(31,20),Vector2(45,29),Vector2(46,34),Vector2(28,30),Vector2(23,37),Vector2(14,33),Vector2(11,21),Vector2(4,20),Vector2(4,16)]))
	var mask := Image.create(48,48,false,Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for y in 48:
		for x in 48:
			for polygon in parts:
				if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),polygon):
					mask.set_pixel(x,y,Color("6e6a73"))
					break
	var image := mask.duplicate() as Image
	for y in range(1,47):
		for x in range(1,47):
			if mask.get_pixel(x,y).a>0 and mask.get_pixel(x,y-1).a==0:
				image.set_pixel(x,y,Color("99919a"))
	return ImageTexture.create_from_image(image)
