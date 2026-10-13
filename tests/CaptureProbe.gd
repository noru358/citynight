# Screenshots along the chapter for review. Needs a display (e.g. xvfb-run).
# CITYNIGHT_CAPTURE_DIR=/path godot --path . res://tests/CaptureProbe.tscn
extends Node
func _ready() -> void:
	var stage: Node2D = preload("res://world/stage.tscn").instantiate()
	add_child(stage)
	var directory: String = OS.get_environment("CITYNIGHT_CAPTURE_DIR")
	for spot: Vector2i in [Vector2i(4,13),Vector2i(32,12),Vector2i(64,11),Vector2i(76,9),Vector2i(90,11),Vector2i(140,13),Vector2i(158,10)]:
		stage.hero.global_position = (Vector2(spot)+Vector2(0.5,0.5))*32
		stage.hero.reset_motion()
		stage.camera.global_position = stage.hero.global_position
		stage.camera.reset_smoothing()
		for i: int in 30: await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		if not directory.is_empty(): get_viewport().get_texture().get_image().save_png("%s/cn_%03d.png" % [directory,spot.x])
	stage.hero.global_position = stage.ending_spot
	for i: int in 300: await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	if not directory.is_empty(): get_viewport().get_texture().get_image().save_png(directory+"/cn_ending.png")
	print("CAPTURE done")
	get_tree().quit()
