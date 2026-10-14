# Which gaps the hero clears, in tiles, between two flat roofs at the same height.
# Running right, jumping at the last moment on the roof (best) or with the body's
# center at the edge (early, closer to a person), with or without one air dash
# right at the jump's apex. Numbers, not feel: use it to size maps.
extends Node
const MOVES: Array = [["jump",false,false],["jump early",true,false],["jump+dash",false,true],["jump early+dash",true,true]]
var tuning: Dictionary
var tile: float

func _ready() -> void:
	Controls.scripted = true
	var path: String = OS.get_environment("CITYNIGHT_TUNING")
	if path.is_empty(): path = "res://data/movement_tuning.json"
	tuning = JSON.parse_string(FileAccess.get_file_as_string(path))
	tile = float(tuning.tile_size)
	for move: Array in MOVES:
		var cleared: PackedStringArray = []
		var widest: int = 0
		for gap: int in range(1,13):
			if await _run(gap,move[1],move[2]):
				widest = gap
				cleared.append(str(gap))
		print("GAP %s: widest=%d cleared=%s" % [move[0],widest,",".join(cleared)])
	print("RESULT gap failures=0")
	get_tree().quit(0)

func _roof(left: float, width: float) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(width,tile)
	body.add_child(shape)
	body.position = Vector2(left+width/2,tile/2)
	add_child(body)
	return body

func _run(gap: int, early: bool, dash: bool) -> bool:
	var near: StaticBody2D = _roof(-tile*20,tile*20)
	var far: StaticBody2D = _roof(tile*gap,tile*20)
	var hero: Mover = Mover.new()
	hero.tuning = tuning
	add_child(hero)
	hero.set_body_size(Vector2(tuning.player_width,tuning.player_height))
	hero.global_position = Vector2(-tile*15,-float(tuning.player_height)/2)
	var half: float = float(tuning.player_width)/2
	var step: float = float(tuning.move_speed)/60.0
	var jumped: bool = false
	var dashed: bool = false
	var landed: bool = false
	for frame: int in 600:
		Controls.held = {&"right":true,&"jump":true}
		var x: float = hero.global_position.x
		if not jumped and hero.is_on_floor() and (x >= 0 if early else x-half+step*1.5 >= 0):
			Controls.edges[&"jump"] = true
			jumped = true
		if jumped and dash and not dashed and hero.velocity.y >= 0 and not hero.is_on_floor():
			Controls.edges[&"dash"] = true
			dashed = true
		await get_tree().physics_frame
		if hero.global_position.y > tile*3: break
		if jumped and hero.is_on_floor() and hero.global_position.x-half > tile*gap-half:
			landed = true
			break
	hero.queue_free()
	near.queue_free()
	far.queue_free()
	await get_tree().physics_frame
	return landed
