# A simple player crosses the chapter: hold right, jump at ledges and walls, dash
# over open drops, bash any light ahead toward up-right. Hazards stay on.
# Pass = reaches the ending spot and the chapter finishes. Synthetic, not feel.
extends Node
var stage: Node2D
var frame: int = 0
var bash_hold: int = 0
const LIMIT: int = 60*180

func _ready() -> void:
	process_physics_priority = -50
	Controls.scripted = true
	stage = preload("res://world/stage.tscn").instantiate()
	add_child(stage)

func _physics_process(_delta: float) -> void:
	frame += 1
	if stage.finished or frame >= LIMIT:
		var result: Dictionary = {"finished":stage.finished,"reached_ending":stage.ending,"seconds":frame/60.0,"falls":stage.log_data.falls,"bash":stage.log_data.bash_count,"beats":stage.log_data.beats,"max_x_tile":int(stage.hero.global_position.x/stage.tile)}
		print("ROUTE "+JSON.stringify(result))
		print("RESULT route failures=%d" % (0 if stage.finished else 1))
		get_tree().quit(0 if stage.finished else 1)
		return
	var hero: Mover = stage.hero
	Controls.held = {&"right":true}
	if stage.ending: 
		Controls.held = {}
		return
	var tile: float = stage.tile
	var col: int = int(hero.global_position.x/tile)
	var feet: int = int((hero.global_position.y+hero.body_size.y/2+2)/tile)
	var ahead: int = int((hero.global_position.x+hero.body_size.x/2+10)/tile)
	if hero.is_on_floor():
		var ledge: bool = not stage.solid_at(ahead,feet) and not stage.solid_at(ahead,feet+1)
		var wall: bool = stage.solid_at(ahead,feet-1) or stage.solid_at(ahead,feet-2)
		if ledge or wall: Controls.edges[&"jump"] = true
	elif hero.state == Mover.State.AIR and hero.velocity.y > 0:
		var ground_near: bool = false
		for dc: int in range(0,4):
			for dr: int in range(0,5):
				if stage.solid_at(col+dc,feet+dr): ground_near = true
		if not ground_near and hero.dash_uses < int(stage.tuning.air_dash_count):
			Controls.edges[&"dash"] = true
			Controls.held = {&"right":true,&"up":hero.dash_uses == 0}
	var target: Node2D = hero.nearest_bashable()
	if bash_hold > 0:
		bash_hold -= 1
		Controls.held = {&"right":true,&"up":true,&"bash":bash_hold > 0}
	elif is_instance_valid(target) and not hero.is_on_floor() and target.global_position.x > hero.global_position.x-8:
		bash_hold = 4
		Controls.held = {&"right":true,&"bash":true}
