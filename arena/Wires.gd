# Foreground power lines over the top-view street, drawn in front of everything.
extends Node2D
var size: Vector2 = Vector2(960,420)

func _ready() -> void:
	z_index = 20

func _draw() -> void:
	for wire: Array in [[30.0,22.0],[44.0,30.0],[size.y-30,30.0]]:
		var points: PackedVector2Array = []
		for i: int in 33:
			var x: float = size.x*i/32.0
			var sag: float = sin(PI*fmod(x,260.0)/260.0)*float(wire[1])
			points.append(Vector2(x,float(wire[0])+sag))
		draw_polyline(points,Color(0.02,0.02,0.04,0.9),2)
	for x: float in [size.x*0.3,size.x*0.7]: draw_rect(Rect2(x-3,size.y-50,6,50),Color(0.02,0.02,0.04,0.85))
