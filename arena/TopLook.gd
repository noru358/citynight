# Placeholder hero drawing for the top view: same coat colours as HeroLook, standing
# on its feet at the node origin, with a shadow and a short dash trail.
extends Node2D
var mover: TopMover
var trail: Array[Vector2] = []

func _process(_delta: float) -> void:
	if mover.dashing: trail.push_front(mover.global_position)
	elif not trail.is_empty(): trail.pop_back()
	if trail.size() > 6: trail.pop_back()
	queue_redraw()

func _draw() -> void:
	for i: int in trail.size():
		var p: Vector2 = trail[i]-mover.global_position
		draw_rect(Rect2(p+Vector2(-7,-30),Vector2(14,24)),Color(0.9,0.35,0.3,0.25*(1.0-i/6.0)))
	draw_set_transform(Vector2(0,1),0,Vector2(1,0.4))
	draw_circle(Vector2.ZERO,10,Color(0,0,0,0.4))
	draw_set_transform(Vector2.ZERO)
	var lean: float = clampf(mover.velocity.x/400.0,-0.2,0.2)
	draw_set_transform(Vector2.ZERO,lean,Vector2.ONE)
	draw_rect(Rect2(-8,-24,16,23),Color("2a2f45"))
	draw_circle(Vector2(0,-29),6,Color("e9d8c4"))
	draw_rect(Rect2(-6,-35,12,5),Color("1b1e2c"))
	var scarf: Vector2 = Vector2(-mover.face.x*8,-mover.face.y*4)
	draw_line(Vector2(0,-22),Vector2(0,-22)+scarf,Color("e2574c"),3)
	if mover.face.y < -0.5: draw_rect(Rect2(-6,-34,12,10),Color("1b1e2c")) # facing away
