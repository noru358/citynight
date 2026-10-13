# Draws the buildings from the map text: dark walls, a lit roof edge, a few lit
# windows (deterministic), ledges as thin bright slabs. Collision lives elsewhere.
extends Node2D
var stage: Node2D

func _draw() -> void:
	var tile: float = stage.tile
	var lines: PackedStringArray = stage.lines
	var thickness: float = float(stage.tuning.platform_thickness)
	for row: int in lines.size():
		var line: String = lines[row].trim_suffix("\r")
		for col: int in line.length():
			var c: String = line[col]
			var rect: Rect2 = Rect2(Vector2(col,row)*tile,Vector2(tile,tile))
			if c == "#":
				var shade: float = 0.06*NightSkyHash.h(col/6,7)
				draw_rect(rect.grow(0.5),Color(0.10+shade,0.10+shade,0.17+shade))
				if not stage.solid_at(col,row-1):
					draw_rect(Rect2(rect.position,Vector2(tile,4)),Color("6f6a9a"))
				elif NightSkyHash.h(col,row) > 0.78:
					var warm: bool = NightSkyHash.h(col+3,row) > 0.35
					draw_rect(Rect2(rect.position+Vector2(9,8),Vector2(14,16)),Color("f2c27a") if warm else Color("8fb8e8"),true)
			elif c == "=":
				draw_rect(Rect2(rect.position,Vector2(tile,thickness)),Color("b9a7d6"))
