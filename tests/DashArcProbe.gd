# Measures the arc after air dashes, in tiles, on flat ground with no map.
# Scenario: jump, then two air dashes in a direction. Prints apex height, how far
# the hero keeps rising after the last dash ends, and the time to that apex.
# Numbers, not feel: use it to compare tunings, then judge by hand.
extends Node
const SCENARIOS: Array = [["jump only",[]],["up x2",[&"up"]],["up-right x2",[&"up",&"right"]],["right x2",[&"right"]]]
var tuning: Dictionary
var tile: float

func _ready() -> void:
	Controls.scripted = true
	var path: String = OS.get_environment("CITYNIGHT_TUNING")
	if path.is_empty(): path = "res://data/movement_tuning.json"
	tuning = JSON.parse_string(FileAccess.get_file_as_string(path))
	tile = float(tuning.tile_size)
	for scenario: Array in SCENARIOS: await _run(scenario[0],scenario[1])
	print("RESULT dash arc failures=0")
	get_tree().quit(0)

func _run(title: String, aim: Array) -> void:
	var floor_body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(tile*400,tile)
	floor_body.add_child(shape)
	floor_body.position = Vector2(0,tile/2)
	add_child(floor_body)
	var hero: Mover = Mover.new()
	hero.tuning = tuning
	add_child(hero)
	hero.set_body_size(Vector2(tuning.player_width,tuning.player_height))
	hero.global_position = Vector2(0,-float(tuning.player_height)/2)
	for i: int in 10: await get_tree().physics_frame
	var ground: float = hero.global_position.y
	var dashes: int = 0
	var last_end_y: float = INF
	var last_end_frame: int = -1
	var apex: float = ground
	var apex_frame: int = 0
	var was_dash: bool = false
	for frame: int in 240:
		var held: Dictionary = {}
		for key: StringName in aim: held[key] = true
		Controls.held = held if dashes > 0 or frame >= 14 else {}
		if frame == 0: Controls.edges[&"jump"] = true
		if not aim.is_empty() and dashes < 2 and frame >= 15 and hero.state != Mover.State.DASH:
			Controls.edges[&"dash"] = true
			dashes += 1
		await get_tree().physics_frame
		var dashing: bool = hero.state == Mover.State.DASH
		if was_dash and not dashing and dashes == 2 and last_end_frame < 0:
			last_end_y = hero.global_position.y
			last_end_frame = frame
		was_dash = dashing
		if hero.global_position.y < apex:
			apex = hero.global_position.y
			apex_frame = frame
		if frame > 20 and hero.is_on_floor(): break
	var after: String = ""
	if last_end_frame >= 0: after = " rise_after_last_dash=%.2f tiles over %.2fs" % [maxf(0,last_end_y-apex)/tile,maxf(0,apex_frame-last_end_frame)/60.0]
	print("ARC %s: apex=%.2f tiles%s" % [title,(ground-apex)/tile,after])
	hero.queue_free()
	floor_body.queue_free()
	await get_tree().physics_frame
