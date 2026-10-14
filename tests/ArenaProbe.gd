# A scripted fighter plays the view-test room in both views (side, then top):
# walks to the nearest monster, slashes in reach, shoots gunners while it has ammo,
# dashes away from a grunt's wind-up. Pass = both rooms run without script errors
# and the bot takes down at least 4 monsters in each. Synthetic, not feel.
extends Node
const LIMIT: int = 60*90
var ArenaScript: Script = preload("res://arena/Arena.gd")
var views: Array[String] = ["side","top"]
var arena: Node2D
var frame: int = 0
var results: Array[Dictionary] = []

func _ready() -> void:
	process_physics_priority = -50
	Controls.scripted = true
	_start()

func _start() -> void:
	frame = 0
	ArenaScript.picked_view = views[results.size()]
	arena = preload("res://arena/arena.tscn").instantiate()
	add_child(arena)

func _physics_process(_delta: float) -> void:
	frame += 1
	if arena.over or frame >= LIMIT:
		var s: Dictionary = arena.hero_fighter.stats
		var entry: Dictionary = {"view":ArenaScript.picked_view,"won":arena.won,"seconds":frame/60.0,"wave":arena.wave_index+1,"kills":arena.kills,"hp":arena.hero_fighter.hp}
		entry.merge(s)
		print("ARENA "+JSON.stringify(entry))
		for foe: Node2D in arena.foes: print("  left %s at %s phase %d" % [foe.kind,str(foe.global_position.round()),foe.phase])
		results.append(entry)
		arena.queue_free()
		Engine.time_scale = 1
		if results.size() < views.size():
			_start.call_deferred()
			set_physics_process(false)
			(func() -> void: set_physics_process(true)).call_deferred()
			return
		var failures: int = 0
		for item: Dictionary in results: if item.kills < 4: failures += 1
		print("RESULT arena failures=%d" % failures)
		get_tree().quit(0 if failures == 0 else 1)
		return
	_drive()
	var capture: String = OS.get_environment("CITYNIGHT_CAPTURE")
	if not capture.is_empty() and frame in [60*8,60*20]:
		get_viewport().get_texture().get_image().save_png(capture.path_join("arena_%s_%d.png" % [ArenaScript.picked_view,frame/60]))

func _drive() -> void:
	Controls.held = {}
	var hero: CharacterBody2D = arena.hero
	var fighter: Node2D = arena.hero_fighter
	if not is_instance_valid(hero) or arena.foes.is_empty(): return
	var near: Node2D
	var gunner: Node2D
	for foe: Node2D in arena.foes:
		if not is_instance_valid(near) or hero.global_position.distance_to(foe.global_position) < hero.global_position.distance_to(near.global_position): near = foe
		if foe.kind == "gunner": gunner = foe
	var to: Vector2 = near.global_position-hero.global_position
	var held: Dictionary = {}
	if arena.top:
		if to.length() > 28:
			if to.x > 8: held[&"right"] = true
			elif to.x < -8: held[&"left"] = true
			if to.y > 8: held[&"down"] = true
			elif to.y < -8: held[&"up"] = true
		if near.kind == "grunt" and near.phase == 1 and to.length() < 50:
			held = {(&"left" if to.x > 0 else &"right"):true}
			Controls.edges[&"dash"] = true
	else:
		if absf(to.x) > 24: held[(&"right" if to.x > 0 else &"left")] = true
		if to.y < -30 and hero.is_on_floor() and absf(to.x) < 120:
			Controls.edges[&"jump"] = true
			held[&"jump"] = true
		elif not hero.is_on_floor() and hero.velocity.y < 0: held[&"jump"] = true
	Controls.held = held
	if to.length() < 40:
		fighter.bot_aim = to
		Controls.edges[&"slash"] = true
	elif is_instance_valid(gunner) and fighter.ammo >= 1 and frame%20 == 0:
		fighter.bot_aim = gunner.global_position-hero.global_position
		Controls.edges[&"shoot"] = true
