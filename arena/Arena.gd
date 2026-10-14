# View test: the same fight in two cameras. One room, four waves of two monster
# kinds, slash / shoot / dash, ammo that only melee hits refill.
# side: the rooftop side view on the real hero movement (jump, wall jump, dash, bash).
# top:  a flat top-down street (no jump), shop fronts along the top edge.
# Numbers: arena/combat_tuning.json. Pick the view with the 뷰 바꾸기 button, V, or
# CITYNIGHT_ARENA=side|top. Grey-box art; this judges feel and readability only.
extends Node2D
const COMBAT_PATH: String = "res://arena/combat_tuning.json"
const MOVE_PATH: String = "res://data/movement_tuning.json"
static var picked_view: String = "side"
var top: bool = false
var tuning: Dictionary = {}
var move_tuning: Dictionary = {}
var errors: PackedStringArray = []
var room: Vector2 = Vector2(640,360)
var world: Node2D
var hero: CharacterBody2D
var hero_fighter: Node2D
var camera: Camera2D
var foes: Array[Node2D] = []
var shots: Array[Node2D] = []
var pending: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var ledges: Array[Rect2] = []
var wave_index: int = -1
var wave_timer: float = 1.0
var kills: int = 0
var over: bool = false
var won: bool = false
var started: int = 0
var shake_amount: float = 0
var logged: bool = false
var hud: Label
var help: Label
var result: Label
var error_label: Label

func t(key: String) -> float:
	return float(tuning[key])

func _ready() -> void:
	Engine.time_scale = 1
	var forced: String = OS.get_environment("CITYNIGHT_ARENA")
	if forced in ["side","top"]: picked_view = forced
	top = picked_view == "top"
	_build_ui()
	if not _load_data():
		error_label.text = "전투 시험을 시작할 수 없음\n\n"+"\n".join(errors)
		error_label.show()
		for line: String in errors: push_error("CITYNIGHT_DATA "+line)
		return
	room = Vector2(960,420) if top else Vector2(640,360)
	var backdrop: Node2D = preload("res://arena/Backdrop.gd").new()
	backdrop.top = top
	backdrop.size = room
	add_child(backdrop)
	world = Node2D.new()
	world.y_sort_enabled = top
	add_child(world)
	if top: _build_top()
	else: _build_side()
	backdrop.ledges = ledges
	_spawn_hero()
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = top
	camera.position_smoothing_speed = 8
	add_child(camera)
	camera.global_position = _camera_target()
	camera.reset_smoothing()
	started = Time.get_ticks_msec()
	DisplayServer.window_set_title("도시의 밤 — 전투 시험 ("+_view_name()+")")

func _view_name() -> String:
	return "탑뷰" if top else "옆 화면"

func _load_data() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMBAT_PATH)) if FileAccess.file_exists(COMBAT_PATH) else null
	if not data is Dictionary:
		errors.append("전투 수치 파일을 읽을 수 없음: "+COMBAT_PATH)
		return false
	tuning = data
	for key: String in ["hero_hp","hurt_invuln","hurt_knockback","slash_radius","slash_arc_deg","slash_damage","slash_cooldown","slash_knockback","slash_charge","pogo_speed","ammo_max","ammo_start","shot_damage","shot_speed","shot_cooldown","shot_recoil","shot_knockback","hitstop","shake","grunt_hp","grunt_speed","grunt_reach","grunt_windup","grunt_lunge_speed","grunt_lunge_time","grunt_recover","gunner_hp","gunner_speed","gunner_keep","gunner_fire_every","gunner_aim_time","gunner_shot_speed","spawn_warning","wave_pause","top_move_speed","top_accel","top_dash_distance","top_dash_time","top_dash_cooldown"]:
		if not tuning.has(key) or not (tuning[key] is float or tuning[key] is int) or float(tuning[key]) < 0: errors.append("전투 수치 오류: "+key)
	if not tuning.get("waves") is Array or tuning.waves.is_empty(): errors.append("전투 수치에 waves 없음")
	else:
		for wave: Variant in tuning.waves:
			if not wave is Dictionary or not (wave.get("grunt") is float or wave.get("grunt") is int) or not (wave.get("gunner") is float or wave.get("gunner") is int):
				errors.append("waves 항목 오류: "+str(wave))
	var move: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_PATH)) if FileAccess.file_exists(MOVE_PATH) else null
	if move is Dictionary: move_tuning = move
	else: errors.append("이동 수치 파일을 읽을 수 없음: "+MOVE_PATH)
	return errors.is_empty()

func _solid(rect: Rect2, one_way: bool = false) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.get_center()
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = rect.size
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)

func _build_side() -> void:
	_solid(Rect2(0,320,640,60))
	_solid(Rect2(0,-300,20,680))
	_solid(Rect2(620,-300,20,680))
	_solid(Rect2(-20,-320,680,20))
	for ledge: Rect2 in [Rect2(80,280,140,4),Rect2(420,280,140,4),Rect2(250,220,140,4)]:
		ledges.append(ledge)
		_solid(ledge,true)
	var light: Node2D = preload("res://world/Bashable.gd").new()
	light.kind = "o"
	light.tuning = move_tuning
	light.position = Vector2(320,150)
	add_child(light)

func _build_top() -> void:
	_solid(Rect2(0,0,room.x,130))
	_solid(Rect2(0,0,16,room.y))
	_solid(Rect2(room.x-16,0,16,room.y))
	_solid(Rect2(0,room.y-16,room.x,16))
	for item: Array in [["table",Vector2(230,250),Vector2(56,26)],["crate",Vector2(560,330),Vector2(40,22)],["crate",Vector2(420,380),Vector2(46,22)],["barricade",Vector2(760,260),Vector2(24,56)],["table",Vector2(120,370),Vector2(52,26)]]:
		var prop: StaticBody2D = preload("res://arena/Prop.gd").new()
		prop.kind = item[0]
		prop.position = item[1]
		prop.footprint = item[2]
		world.add_child(prop)
	var wires: Node2D = preload("res://arena/Wires.gd").new()
	wires.size = room
	add_child(wires)

func _spawn_hero() -> void:
	if top:
		var mover: TopMover = TopMover.new()
		mover.tuning = tuning
		mover.position = Vector2(480,280)
		world.add_child(mover)
		var look: Node2D = preload("res://arena/TopLook.gd").new()
		look.name = "Look"
		look.mover = mover
		mover.add_child(look)
		hero = mover
	else:
		var mover: Mover = Mover.new()
		mover.tuning = move_tuning
		mover.position = Vector2(320,300)
		add_child(mover)
		mover.set_body_size(Vector2(move_tuning.player_width,move_tuning.player_height))
		var look: Node2D = preload("res://player/HeroLook.gd").new()
		look.name = "Look"
		look.mover = mover
		mover.add_child(look)
		hero = mover
	hero_fighter = preload("res://arena/Fighter.gd").new()
	hero_fighter.arena = self
	hero_fighter.body = hero
	hero_fighter.top = top
	hero_fighter.tuning = tuning
	hero_fighter.setup()
	hero.add_child(hero_fighter)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hero) or over: return
	for item: Dictionary in pending.duplicate():
		item.time -= delta
		if item.time <= 0:
			pending.erase(item)
			_spawn_foe(item.kind,item.at)
	if foes.is_empty() and pending.is_empty():
		wave_timer -= delta
		if wave_timer <= 0: _next_wave()
	for burst: Dictionary in bursts.duplicate():
		burst.time -= delta
		if burst.time <= 0: bursts.erase(burst)
	queue_redraw()

func _next_wave() -> void:
	wave_index += 1
	wave_timer = t("wave_pause")
	if wave_index >= tuning.waves.size():
		_finish(true)
		return
	var wave: Dictionary = tuning.waves[wave_index]
	var order: int = 0
	for kind: String in ["grunt","gunner"]:
		for i: int in int(wave[kind]):
			pending.append({"kind":kind,"at":_spawn_point(kind,i),"time":t("spawn_warning")+order*0.3})
			order += 1

func _spawn_point(kind: String, i: int) -> Vector2:
	if top:
		var points: Array[Vector2] = [Vector2(40,260),Vector2(920,330),Vector2(480,395),Vector2(300,150),Vector2(660,150),Vector2(40,390),Vector2(920,170)]
		points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(hero.global_position) > b.distance_to(hero.global_position))
		return points[i%3] if kind == "gunner" else points[i%points.size()]
	if kind == "gunner": return [Vector2(150,264),Vector2(490,264),Vector2(320,204)][i%3]
	return Vector2(40 if i%2 == 0 else 600,307)

func _spawn_foe(kind: String, at: Vector2) -> void:
	var foe: CharacterBody2D = preload("res://arena/Foe.gd").new()
	foe.arena = self
	foe.kind = kind
	foe.top = top
	foe.tuning = tuning
	foe.position = at
	(world if top else self).add_child(foe)
	foes.append(foe)

func foe_died(foe: Node2D) -> void:
	if not foes.has(foe): return
	foes.erase(foe)
	kills += 1
	bursts.append({"at":foe.global_position-Vector2(0,12 if top else 0),"time":0.35})
	shake(2)
	foe.queue_free()

func melee(origin: Vector2, aim: Vector2, radius: float, half_arc: float, damage: int, force: float) -> int:
	var count: int = 0
	for foe: Node2D in foes.duplicate():
		var to: Vector2 = foe.global_position-origin
		if to.length() > radius+8: continue
		if to.length() > 10 and absf(aim.angle_to(to)) > half_arc: continue
		count += 1
		foe.take_hit(damage,to if to.length() > 1 else aim,force)
	for shot: Node2D in shots.duplicate():
		if shot.from_hero: continue
		var to: Vector2 = shot.global_position-origin
		if to.length() <= radius+6 and (to.length() < 10 or absf(aim.angle_to(to)) <= half_arc):
			remove_shot(shot)
			hero_fighter.stats.deflects += 1
	return count

func spawn_shot(at: Vector2, velocity: Vector2, from_hero: bool, damage: int, force: float) -> void:
	var shot: Node2D = preload("res://arena/Shot.gd").new()
	shot.arena = self
	shot.velocity = velocity
	shot.from_hero = from_hero
	shot.damage = damage
	shot.force = force
	shot.lift = (14.0 if from_hero else 12.0) if top else 0.0
	shot.position = at
	shot.z_index = 4
	(world if top else self).add_child(shot)
	shots.append(shot)

func remove_shot(shot: Node2D) -> void:
	shots.erase(shot)
	shot.queue_free()

func hitstop() -> void:
	if t("hitstop") <= 0 or not is_equal_approx(Engine.time_scale,1.0): return
	Engine.time_scale = 0.05
	get_tree().create_timer(t("hitstop"),true,false,true).timeout.connect(func() -> void:
		if is_equal_approx(Engine.time_scale,0.05): Engine.time_scale = 1.0)

func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount,amount*t("shake")/3.0)

func hero_down() -> void:
	_finish(false)

func _finish(victory: bool) -> void:
	if over: return
	over = true
	won = victory
	Engine.time_scale = 1
	if hero is Mover:
		hero.cancel_bash()
		hero.frozen = true
	else: hero.frozen = true
	var s: Dictionary = hero_fighter.stats
	result.text = "%s · %s\n\n%d초 · 파도 %d/%d · 쓰러뜨림 %d · 맞음 %d\n베기 %d번(맞힘 %d) · 사격 %d번(맞힘 %d) · 탄 쳐내기 %d%s\n\nR 또는 처음부터 · V 또는 뷰 바꾸기" % [_view_name(),"다 잡음" if victory else "쓰러짐",_seconds(),mini(wave_index+1,tuning.waves.size()),tuning.waves.size(),kills,s.hurt,s.slashes,s.slash_hits,s.shots,s.shot_hits,s.deflects,"" if top else " · 튕겨 오르기 %d" % s.pogos]
	result.show()
	write_log()

func _seconds() -> int:
	return int((Time.get_ticks_msec()-started)/1000)

func _camera_target() -> Vector2:
	if not top: return room/2
	var viewport: Vector2 = get_viewport_rect().size
	var half: Vector2 = viewport/maxf(viewport.x/640.0,viewport.y/360.0)/2
	var target: Vector2 = hero.global_position+Vector2(0,-40)
	return Vector2(clampf(target.x,half.x,maxf(half.x,room.x-half.x)),clampf(target.y,half.y,maxf(half.y,room.y-half.y)))

func _process(delta: float) -> void:
	if not is_instance_valid(camera): return
	var viewport: Vector2 = get_viewport_rect().size
	camera.zoom = Vector2.ONE*maxf(viewport.x/640.0,viewport.y/360.0)
	camera.global_position = _camera_target()
	shake_amount = move_toward(shake_amount,0,30*delta)
	camera.offset = Vector2(randf_range(-1,1),randf_range(-1,1))*shake_amount
	var s: Dictionary = hero_fighter.stats
	var hearts: String = "♥".repeat(maxi(hero_fighter.hp,0))+"♡".repeat(maxi(int(t("hero_hp"))-hero_fighter.hp,0))
	hud.text = "%s · 파도 %d/%d · 체력 %s · 탄 %.1f/%d · 쓰러뜨림 %d" % [_view_name(),clampi(wave_index+1,1,tuning.waves.size()),tuning.waves.size(),hearts,hero_fighter.ammo,int(t("ammo_max")),kills]

func _draw() -> void:
	for item: Dictionary in pending:
		var at: Vector2 = item.at
		var r: float = 6+10*(1.0-clampf(item.time/t("spawn_warning"),0,1))
		if top:
			draw_set_transform(at,0,Vector2(1,0.45))
			draw_arc(Vector2.ZERO,r,0,TAU,20,Color(1,0.3,0.5,0.8),2)
			draw_set_transform(Vector2.ZERO)
		else: draw_arc(at,r,0,TAU,20,Color(1,0.3,0.5,0.8),2)
	for burst: Dictionary in bursts:
		var k: float = burst.time/0.35
		draw_arc(burst.at,24*(1.0-k)+4,0,TAU,20,Color(0.8,0.6,1,k),3*k+1)
		for i: int in 6:
			var dir: Vector2 = Vector2.RIGHT.rotated(TAU*i/6.0)
			draw_line(burst.at+dir*(30*(1.0-k)),burst.at+dir*(30*(1.0-k)+6),Color(0.6,0.9,1,k),2)

func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.position = Vector2(16,12)
	buttons.modulate.a = 0.6
	layer.add_child(buttons)
	for title: String in ["처음부터","뷰 바꾸기","옥상으로","종료"]:
		var button: Button = Button.new()
		button.text = title
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_command.bind(title))
		buttons.add_child(button)
	hud = Label.new()
	hud.position = Vector2(18,52)
	hud.add_theme_font_size_override("font_size",18)
	hud.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	layer.add_child(hud)
	help = Label.new()
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_top = -64
	help.offset_left = 18
	help.offset_bottom = -12
	help.add_theme_font_size_override("font_size",15)
	help.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	help.modulate.a = 0.75
	help.text = ("이동 WASD · 대시 Space 또는 Shift · 점프 없음" if picked_view == "top" else "이동 A/D · 점프 Space · 대시 Shift · 튕기기 K(괴물에게도) · 공중에서 아래+베기 = 튕겨 오르기")+"\n베기 J 또는 좌클릭 · 사격 L 또는 우클릭 · 베기가 맞으면 탄이 찬다(세 번에 한 발)"
	layer.add_child(help)
	result = Label.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size",24)
	result.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	result.hide()
	layer.add_child(result)
	error_label = Label.new()
	error_label.position = Vector2(24,60)
	error_label.add_theme_color_override("font_color",Color(1,0.6,0.6))
	error_label.hide()
	layer.add_child(error_label)

func _command(title: String) -> void:
	match title:
		"처음부터": _restart()
		"뷰 바꾸기":
			picked_view = "side" if picked_view == "top" else "top"
			_restart()
		"옥상으로":
			write_log()
			Engine.time_scale = 1
			get_tree().change_scene_to_file("res://world/stage.tscn")
		"종료":
			write_log()
			get_tree().quit()

func _restart() -> void:
	write_log()
	Engine.time_scale = 1
	get_tree().reload_current_scene()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_R or (over and event.keycode in [KEY_ENTER,KEY_KP_ENTER]): _command("처음부터")
	elif event.keycode == KEY_V: _command("뷰 바꾸기")

func write_log() -> void:
	if logged or started == 0: return
	logged = true
	var path: String = OS.get_environment("CITYNIGHT_LOG")
	if path.is_empty(): path = "user://citynight_log.jsonl"
	var file: FileAccess = FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if not file: return
	var entry: Dictionary = {"arena":picked_view,"started_at":Time.get_datetime_string_from_system(true),"seconds":(Time.get_ticks_msec()-started)/1000.0,"won":won,"over":over,"wave":wave_index+1,"kills":kills}
	entry.merge(hero_fighter.stats)
	file.seek_end()
	file.store_line(JSON.stringify(entry))

func _exit_tree() -> void:
	Engine.time_scale = 1
	write_log()
