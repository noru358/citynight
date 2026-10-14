# Placeholder hero drawing until real art exists: coat, head, and a scarf that
# trails behind the motion so speed reads on screen.
extends Node2D
var mover: Mover
var trail: Array[Vector2] = []

func _process(_delta: float) -> void:
	var point: Vector2 = mover.global_position+Vector2(-mover.facing*mover.body_size.x*0.13,-mover.body_size.y*0.28)
	if not trail.is_empty() and trail[0].distance_to(point) > 50: trail.clear() # respawn or teleport
	trail.push_front(point)
	if trail.size() > 9: trail.pop_back()
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = mover.body_size
	var lean: float = clampf(mover.velocity.x/375.0,-0.25,0.25)
	draw_set_transform(Vector2.ZERO,lean,Vector2.ONE)
	var coat: Color = Color("2a2f45")
	var head: float = size.x*0.3
	draw_rect(Rect2(-size.x*0.4,-size.y/2+head*1.5,size.x*0.8,size.y-head*1.5),coat)
	draw_circle(Vector2(0,-size.y/2+head),head,Color("e9d8c4"))
	draw_rect(Rect2(-head,-size.y/2-1,head*2,head*0.8),Color("1b1e2c"))
	draw_set_transform(Vector2.ZERO)
	if trail.size() > 2:
		var points: PackedVector2Array = []
		for point: Vector2 in trail: points.append(point-mover.global_position)
		draw_polyline(points,Color("e2574c"),3,true)
	if mover.flash_remaining > 0:
		var strength: float = mover.flash_remaining/float(mover.tuning.bash_flash_time)
		draw_line(-mover.launch_direction*float(mover.tuning.bash_trail_length)*strength,Vector2.ZERO,Color(1,0.9,0.7,strength),6*strength)
