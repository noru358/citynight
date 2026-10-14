# A solid street prop in the top view (cover): the node sits at the bottom edge of
# its footprint so y-sorting puts it in front of things behind it.
extends StaticBody2D
var footprint: Vector2 = Vector2(40,24)
var height: float = 18
var kind: String = "crate"

func _ready() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = footprint
	shape.position = Vector2(0,-footprint.y/2)
	add_child(shape)

func _draw() -> void:
	var w: float = footprint.x
	var d: float = footprint.y
	var top_face: Rect2 = Rect2(Vector2(-w/2,-d-height),Vector2(w,d))
	var front: Rect2 = Rect2(Vector2(-w/2,-height),Vector2(w,height))
	draw_set_transform(Vector2(0,2),0,Vector2(1,0.35))
	draw_circle(Vector2.ZERO,w*0.6,Color(0,0,0,0.3))
	draw_set_transform(Vector2.ZERO)
	match kind:
		"table":
			draw_rect(front,Color("5a2a2a"))
			draw_rect(top_face,Color("c0392b"))
			draw_rect(Rect2(top_face.position+Vector2(4,3),Vector2(w-8,d-6)),Color("e67e5a"),false,1)
			draw_circle(top_face.get_center(),3,Color("ffe08a"))
		"barricade":
			draw_rect(front,Color("2c2f3a"))
			draw_rect(top_face,Color("8a8f99"))
			for i: int in int(w/10): draw_line(Vector2(-w/2+i*10,-height),Vector2(-w/2+i*10+6,0),Color("f1c40f"),3)
		_:
			draw_rect(front,Color("1f5a3a"))
			draw_rect(top_face,Color("2e8b57"))
			draw_line(front.position+Vector2(0,height/2),front.position+Vector2(w,height/2),Color("16402a"),1)
