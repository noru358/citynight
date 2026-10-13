# Something to grab and launch off. Placeholder look: a small warm light
# (a street lamp, a hanging sign, a lit window ledge; decided with the story).
extends Node2D
var kind: String = "o" # o: still, m: sways sideways
var home: Vector2
var offset: Vector2 = Vector2.ZERO
var age: float = 0
var highlight: bool = false
var tuning: Dictionary = {}

func _ready() -> void:
	home = position
	add_to_group("bashable")

func bash(direction: Vector2) -> void:
	offset += direction*float(tuning.get("orb_push_distance",40))

func _physics_process(delta: float) -> void:
	age += delta
	var back: float = float(tuning.get("orb_push_distance",40))/maxf(0.01,float(tuning.get("orb_return_time",0.6)))
	offset = offset.move_toward(Vector2.ZERO,back*delta)
	position = home+offset
	if kind == "m": position.x += sin(age*TAU/float(tuning.get("moving_orb_period",3)))*float(tuning.get("moving_orb_range",4))*float(tuning.get("tile_size",32))
	queue_redraw()

func _draw() -> void:
	var radius: float = float(tuning.get("orb_radius",10))
	var pulse: float = 0.5+0.5*sin(age*2.4)
	draw_circle(Vector2.ZERO,radius*2.6,Color(1,0.78,0.45,0.10+0.05*pulse))
	draw_circle(Vector2.ZERO,radius*1.6,Color(1,0.8,0.5,0.22))
	draw_circle(Vector2.ZERO,radius,Color(1,0.88,0.62))
	if highlight: draw_arc(Vector2.ZERO,radius+5,0,TAU,32,Color(1,1,1,0.9),2)
