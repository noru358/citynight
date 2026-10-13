# One chapter on the night rooftops: builds the text map, runs the hero, fires
# story beats as the hero passes them, cues music stems, and plays the ending sit.
# Map characters: # building, = ledge (one-way), P start, o/m bash light (still/swaying),
# ^ hazard, 1-9 story beat (fires when the hero passes its column), E ending spot.
extends Node2D
signal chapter_finished
const CHAPTER_DEFAULT: String = "res://data/chapters/ch00.json"
const TUNING_DEFAULT: String = "res://data/movement_tuning.json"
const SCHEMA_PATH: String = "res://data/movement_schema.json"
var chapter_path: String = CHAPTER_DEFAULT
var tuning_path: String = TUNING_DEFAULT
var chapter: Dictionary
var tuning: Dictionary
var schema: Dictionary
var lines: PackedStringArray = []
var map_size: Vector2
var tile: float = 32
var hero: Mover
var camera: Camera2D
var sky: Node2D
var facade: Node2D
var geometry: Node2D
var spawn: Vector2
var checkpoint: Vector2
var hazards: Array[Rect2] = []
var beats: Array[Dictionary] = []
var ending_spot: Vector2 = Vector2.INF
var fired: Dictionary = {}
var floor_time: float = 0
var lead: float = 0
var respawning: bool = false
var ending: bool = false
var finished: bool = false
var errors: PackedStringArray = []
var started: int = 0
var log_data: Dictionary = {}
var logged: bool = false
var caption: Label
var fade: ColorRect
var panel: PanelContainer
var error_label: Label
var end_label: Label

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not OS.get_environment("CITYNIGHT_CHAPTER").is_empty(): chapter_path = OS.get_environment("CITYNIGHT_CHAPTER")
	if not OS.get_environment("CITYNIGHT_TUNING").is_empty(): tuning_path = OS.get_environment("CITYNIGHT_TUNING")
	_build_ui()
	if not _load_data():
		_show_errors()
		return
	hero = Mover.new()
	hero.tuning = tuning
	add_child(hero)
	hero.set_body_size(Vector2(tuning.player_width,tuning.player_height))
	var look: Node2D = preload("res://player/HeroLook.gd").new()
	look.mover = hero
	hero.add_child(look)
	hero.bashed.connect(func(_t: Node2D) -> void: log_data.bash_count += 1)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	var back: CanvasLayer = CanvasLayer.new()
	back.layer = -10
	add_child(back)
	sky = preload("res://world/NightSky.gd").new()
	sky.stage = self
	sky.set_colors(chapter.get("sky",{}))
	back.add_child(sky)
	_build_map()
	started = Time.get_ticks_msec()
	log_data = {"chapter":chapter.id,"started_at":Time.get_datetime_string_from_system(true),"falls":0,"bash_count":0,"beats":{},"finished":false}
	hero.global_position = spawn
	checkpoint = spawn
	camera.global_position = spawn
	camera.reset_smoothing()
	var music: Dictionary = chapter.get("music",{})
	MusicDirector.play(str(music.get("track","")),music.get("stems_on",[]))
	DisplayServer.window_set_title("도시의 밤 — "+str(chapter.title))

# Fail closed: a bad tuning, chapter or map stops the chapter with a readable list.
func _load_data() -> bool:
	schema = _json(SCHEMA_PATH)
	var parsed: Variant = _json(tuning_path)
	if parsed is Dictionary:
		for key: String in schema:
			if not parsed.has(key) or not (parsed[key] is float or parsed[key] is int) or float(parsed[key]) < float(schema[key].min) or float(parsed[key]) > float(schema[key].max):
				errors.append("이동 수치 오류: "+key)
		tuning = parsed
	else: errors.append("이동 수치 파일을 읽을 수 없음: "+tuning_path)
	var data: Variant = _json(chapter_path)
	if not data is Dictionary:
		errors.append("장 파일을 읽을 수 없음: "+chapter_path)
		return false
	chapter = data
	for key: String in ["id","title","map","beats","ending"]:
		if not chapter.has(key): errors.append("장 파일에 %s 없음" % key)
	if not errors.is_empty(): return false
	# Shipped chapters read maps/; a test chapter outside res:// reads its map from its own folder.
	var map_path: String = "res://maps/"+str(chapter.map) if chapter_path.begins_with("res://") else chapter_path.get_base_dir().path_join(str(chapter.map))
	if not FileAccess.file_exists(map_path):
		errors.append("맵 파일 없음: "+map_path)
		return false
	lines = FileAccess.get_file_as_string(map_path).strip_edges(false,true).split("\n")
	var used: Dictionary = {}
	var has_spawn: bool = false
	var has_end: bool = false
	for row: int in lines.size():
		var line: String = lines[row].trim_suffix("\r")
		for col: int in line.length():
			var c: String = line[col]
			if c in "123456789":
				used[c] = true
				if not chapter.beats.has(c): errors.append("맵 %d행 %d열의 비트 %s가 장 파일에 없음" % [row+1,col+1,c])
			elif c == "P": has_spawn = true
			elif c == "E": has_end = true
			elif not c in "#=om^. ": errors.append("맵 %d행 %d열 모르는 문자 '%s'" % [row+1,col+1,c])
	for key: String in chapter.beats:
		if not used.has(key): errors.append("장 파일의 비트 %s가 맵에 없음" % key)
	if not has_spawn: errors.append("맵에 시작점 P 없음")
	if not has_end: errors.append("맵에 엔딩 자리 E 없음")
	return errors.is_empty()

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _build_map() -> void:
	tile = float(tuning.tile_size)
	if is_instance_valid(geometry): geometry.queue_free()
	geometry = Node2D.new()
	add_child(geometry)
	hazards.clear()
	beats.clear()
	var width: int = 0
	for line: String in lines: width = maxi(width,line.trim_suffix("\r").length())
	map_size = Vector2(width,lines.size())*tile
	for row: int in lines.size():
		var line: String = lines[row].trim_suffix("\r")
		for col: int in line.length():
			var c: String = line[col]
			var center: Vector2 = (Vector2(col,row)+Vector2(0.5,0.5))*tile
			match c:
				"#", "=":
					var body: StaticBody2D = StaticBody2D.new()
					body.position = center if c == "#" else center+Vector2(0,-tile/2+float(tuning.platform_thickness)/2)
					var shape: CollisionShape2D = CollisionShape2D.new()
					shape.shape = RectangleShape2D.new()
					shape.shape.size = Vector2(tile,tile if c == "#" else float(tuning.platform_thickness))
					shape.one_way_collision = c == "="
					body.add_child(shape)
					geometry.add_child(body)
				"o", "m":
					var light: Node2D = preload("res://world/Bashable.gd").new()
					light.kind = c
					light.tuning = tuning
					light.position = center
					geometry.add_child(light)
				"^": hazards.append(Rect2(Vector2(col,row)*tile+Vector2(4,tile*0.4),Vector2(tile-8,tile*0.6)))
				"P": spawn = center+Vector2(0,tile/2-float(tuning.player_height)/2)
				"E": ending_spot = center
				_:
					if c in "123456789": beats.append({"key":c,"x":center.x})
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	facade = preload("res://world/Facade.gd").new()
	facade.stage = self
	geometry.add_child(facade)
	geometry.move_child(facade,0)

func solid_at(col: int, row: int) -> bool:
	if row < 0 or row >= lines.size() or col < 0: return false
	var line: String = lines[row].trim_suffix("\r")
	return col < line.length() and line[col] in "#="

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hero) or panel.visible: return
	if ending or respawning: return
	var body: Rect2 = Rect2(hero.global_position-hero.body_size/2,hero.body_size)
	for hazard: Rect2 in hazards:
		if hazard.intersects(body):
			respawn()
			return
	if hero.global_position.y > map_size.y+tile:
		respawn()
		return
	_auto_checkpoint(delta)
	for beat: Dictionary in beats:
		if not fired.has(beat.key) and hero.global_position.x >= beat.x: _fire_beat(beat.key)
	if ending_spot != Vector2.INF and hero.is_on_floor() and absf(hero.global_position.x-ending_spot.x) < tile and absf(hero.global_position.y-ending_spot.y) < tile*1.5:
		_start_ending()

func _auto_checkpoint(delta: float) -> void:
	if not hero.is_on_floor() or hero.state == Mover.State.DASH:
		floor_time = 0
		return
	floor_time += delta
	if floor_time < 0.15: return
	var feet: float = hero.global_position.y+hero.body_size.y/2+4
	for side: float in [-1.0,1.0]:
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = Vector2(hero.global_position.x+side*(hero.body_size.x/2+6),feet)
		if get_world_2d().direct_space_state.intersect_point(query).is_empty(): return
	checkpoint = hero.global_position

func _fire_beat(key: String) -> void:
	fired[key] = true
	var beat: Dictionary = chapter.beats[key]
	log_data.beats[key] = (Time.get_ticks_msec()-started)/1000.0
	for stem: Variant in beat.get("stems_on",[]): MusicDirector.stem(str(stem),true)
	for stem: Variant in beat.get("stems_off",[]): MusicDirector.stem(str(stem),false)
	if beat.has("caption"): show_caption(str(beat.caption),float(beat.get("seconds",4)))

func show_caption(text: String, seconds: float) -> void:
	caption.text = text
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(caption,"modulate:a",1.0,0.6)
	tween.tween_interval(seconds)
	tween.tween_property(caption,"modulate:a",0.0,1.0)

func _start_ending() -> void:
	ending = true
	hero.frozen = true
	var data: Dictionary = chapter.ending
	MusicDirector.fade_all(float(data.get("music_fade_seconds",5)))
	show_caption(str(data.get("caption","")),float(data.get("hold_seconds",7)))
	var tween: Tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	var zoom_target: float = camera.zoom.x*float(data.get("zoom_out",0.6))
	tween.tween_property(camera,"zoom",Vector2.ONE*zoom_target,4.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera,"offset",Vector2(0,-tile*3),4.0).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_interval(float(data.get("hold_seconds",7)))
	tween.chain().tween_property(fade,"color:a",1.0,2.0)
	tween.chain().tween_callback(_finish)

func _finish() -> void:
	finished = true
	log_data.finished = true
	end_label.text = "엔딩 몽타주 자리\n\n%d분 %02d초 · 떨어짐 %d번 · 튕기기 %d번\n\nEnter 또는 화면 버튼: 처음부터" % [_seconds()/60,_seconds()%60,log_data.falls,log_data.bash_count]
	end_label.show()
	write_log()
	chapter_finished.emit()

func _seconds() -> int:
	return int((Time.get_ticks_msec()-started)/1000)

func respawn() -> void:
	if respawning: return
	respawning = true
	log_data.falls += 1
	hero.cancel_bash()
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(fade,"color:a",1.0,0.15)
	tween.tween_callback(func() -> void:
		hero.global_position = checkpoint
		hero.reset_motion())
	tween.tween_property(fade,"color:a",0.0,0.15)
	tween.tween_callback(func() -> void: respawning = false)

func _process(delta: float) -> void:
	if not is_instance_valid(hero): return
	var viewport: Vector2 = get_viewport_rect().size
	if not ending:
		var zoom_value: float = maxf(viewport.x/float(tuning.camera_view_width),viewport.y/float(tuning.camera_view_height))
		camera.zoom = Vector2.ONE*zoom_value
	camera.position_smoothing_speed = float(tuning.camera_smoothing)
	var half: Vector2 = viewport/camera.zoom.x/2
	lead = lerpf(lead,110.0*hero.facing,clampf(2.5*delta,0,1))
	var target: Vector2 = hero.global_position+Vector2(lead,-tile)
	camera.global_position = Vector2(clampf(target.x,half.x,maxf(half.x,map_size.x-half.x)),clampf(target.y,half.y,maxf(half.y,map_size.y-half.y)))
	sky.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(hero): return
	if is_instance_valid(hero.target):
		var at: Vector2 = hero.target.global_position
		draw_line(hero.global_position,at,Color(1,0.85,0.5,0.8),2)
		var end: Vector2 = at+hero.aim*float(tuning.bash_radius)
		draw_line(at,end,Color.WHITE,3)
		draw_line(end,end-hero.aim.rotated(0.5)*12,Color.WHITE,3)
		draw_line(end,end-hero.aim.rotated(-0.5)*12,Color.WHITE,3)
	for hazard: Rect2 in hazards: draw_rect(hazard,Color(0.9,0.3,0.3,0.8))

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.offset_top = -120
	caption.offset_bottom = -70
	caption.offset_left = -500
	caption.offset_right = 500
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	caption.modulate.a = 0
	layer.add_child(caption)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.position = Vector2(16,12)
	buttons.modulate.a = 0.6
	layer.add_child(buttons)
	for title: String in ["튜닝 Tab","처음부터","종료"]:
		var button: Button = Button.new()
		button.text = title
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_command.bind(title))
		buttons.add_child(button)
	panel = preload("res://ui/TuningPanel.gd").new()
	panel.stage = self
	panel.position = Vector2(16,56)
	panel.hide()
	layer.add_child(panel)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.02,0.02,0.05,0)
	layer.add_child(fade)
	end_label = Label.new()
	end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size",24)
	end_label.hide()
	layer.add_child(end_label)
	error_label = Label.new()
	error_label.position = Vector2(24,60)
	error_label.add_theme_color_override("font_color",Color(1,0.6,0.6))
	error_label.hide()
	layer.add_child(error_label)

func _show_errors() -> void:
	error_label.text = "장을 시작할 수 없음\n\n"+"\n".join(errors)
	error_label.show()
	for line: String in errors: push_error("CITYNIGHT_DATA "+line)

func _command(title: String) -> void:
	match title:
		"튜닝 Tab":
			if not is_instance_valid(hero): return
			panel.visible = not panel.visible
			Controls.blocked = panel.visible
			get_tree().paused = false
		"처음부터": restart()
		"종료":
			write_log()
			get_tree().quit()

func restart() -> void:
	Controls.blocked = false
	Engine.time_scale = 1
	MusicDirector.stop()
	write_log()
	get_tree().reload_current_scene()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_TAB: _command("튜닝 Tab")
	elif finished and event.keycode in [KEY_ENTER,KEY_KP_ENTER]: restart()

func write_log() -> void:
	if logged or log_data.is_empty(): return
	logged = true
	var path: String = OS.get_environment("CITYNIGHT_LOG")
	if path.is_empty(): path = "user://citynight_log.jsonl"
	var file: FileAccess = FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if not file: return
	log_data.duration_sec = (Time.get_ticks_msec()-started)/1000.0
	file.seek_end()
	file.store_line(JSON.stringify(log_data))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: write_log()

func _exit_tree() -> void:
	Engine.time_scale = 1
	write_log()
