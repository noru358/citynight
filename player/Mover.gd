# The hero's whole movement: run, jump, wall jump, two air dashes, bash.
# Ported from the approved jump toy in noru358/tt (toys/movement/ToyMotion.gd) with
# the same tuning keys and numbers (data/movement_tuning.json). No combat here.
class_name Mover
extends CharacterBody2D
signal bashed(target: Node2D)
signal wall_jumped
signal dashed(direction: Vector2)
signal jumped

enum State { GROUND, AIR, DASH, BASH }
var tuning: Dictionary = {}
var state: State = State.AIR
var facing: int = 1
var body_size: Vector2 = Vector2(20,32)
var frozen: bool = false

var dash_uses: int = 0
var dash_cooldown: float = 0
var dash_time: float = 0
var dash_elapsed: float = 0
var dash_speed: float = 0
var dash_direction: Vector2 = Vector2.RIGHT
var dash_reaim: float = 0
var dash_pending: float = 0
var pending_direction: Vector2 = Vector2.ZERO
var dash_ended: bool = false

var jump_pending: float = 0
var wall_grace: float = 0
var wall_normal: Vector2 = Vector2.ZERO
var lock_time: float = 0

var target: Node2D
var aim: Vector2 = Vector2.UP
var held_since: int = 0
var bash_consumed: bool = false
var was_held: bool = false
var cooldowns: Dictionary = {}
var launch_age: float = -1
var coast_remaining: float = 0
var launch_direction: Vector2 = Vector2.ZERO
var launch_origin: Vector2 = Vector2.ZERO
var flash_remaining: float = 0
var collision: CollisionShape2D

func _ready() -> void:
	collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	add_child(collision)
	set_body_size(body_size)
	floor_snap_length = 3

func t(key: String) -> float:
	return float(tuning[key])

func set_body_size(size: Vector2) -> void:
	body_size = size
	if is_instance_valid(collision): collision.shape.size = size

func cancel_bash() -> void:
	target = null
	Engine.time_scale = 1
	was_held = true
	bash_consumed = true

func reset_motion() -> void:
	cancel_bash()
	velocity = Vector2.ZERO
	state = State.AIR
	dash_uses = 0
	dash_cooldown = 0
	dash_pending = 0
	jump_pending = 0
	lock_time = 0
	wall_grace = 0
	launch_age = -1
	coast_remaining = 0
	flash_remaining = 0
	dash_ended = false
	cooldowns.clear()
	reset_physics_interpolation()

func nearest_bashable() -> Node2D:
	var found: Node2D
	var distance: float = t("bash_radius")
	var now: int = Time.get_ticks_msec()
	for item: Node in get_tree().get_nodes_in_group("bashable"):
		item.set("highlight",false)
		if item.is_queued_for_deletion() or now < int(cooldowns.get(item.get_instance_id(),0)): continue
		var d: float = global_position.distance_to(item.global_position)
		if d > distance: continue
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position,item.global_position,1)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
		distance = d
		found = item
	if is_instance_valid(found): found.set("highlight",true)
	return found

func _launch() -> void:
	if not is_instance_valid(target):
		cancel_bash()
		return
	velocity = aim*t("bash_launch_speed")*t("bash_start_speed_ratio")
	launch_age = 0
	coast_remaining = t("bash_coast_time")
	flash_remaining = t("bash_flash_time")
	launch_origin = target.global_position
	launch_direction = aim
	if target.has_method("bash"): target.bash(-aim)
	cooldowns[target.get_instance_id()] = Time.get_ticks_msec()+int(t("bash_same_target_cooldown")*1000)
	dash_uses = 0
	dash_cooldown = 0
	lock_time = t("bash_air_control_delay")
	state = State.AIR
	bashed.emit(target)
	cancel_bash()

func _begin_dash(direction: Vector2) -> void:
	state = State.DASH
	dash_elapsed = 0
	dash_time = maxf(t("dash_duration"),1.0/Engine.physics_ticks_per_second)
	dash_speed = t("dash_distance")/dash_time
	dash_cooldown = t("dash_cooldown")
	dash_reaim = t("dash_aim_grace")
	launch_age = -1
	coast_remaining = 0
	_set_dash_direction(direction if direction != Vector2.ZERO else Vector2(facing,0))
	dash_uses += 1
	dashed.emit(dash_direction)

func _set_dash_direction(direction: Vector2) -> void:
	dash_direction = direction.normalized()
	if is_on_floor() and is_zero_approx(dash_direction.x) and dash_direction.y > 0: dash_direction = Vector2(facing,0)
	if dash_direction.x != 0: facing = int(signf(dash_direction.x))

func _physics_process(delta: float) -> void:
	flash_remaining = maxf(0,flash_remaining-delta)
	if tuning.is_empty(): return
	if frozen:
		if is_instance_valid(target): cancel_bash()
		state = State.GROUND if is_on_floor() else State.AIR
		velocity.x = move_toward(velocity.x,0,t("air_control_accel")*delta)
		if not is_on_floor(): velocity.y = minf(velocity.y+t("gravity")*delta,t("max_fall_speed"))
		move_and_slide()
		return
	# Bash: hold to grab the nearest orb in reach, time slows, aim, release to launch.
	var holding: bool = Controls.is_held(&"bash")
	var candidate: Node2D = nearest_bashable()
	if not holding or not was_held: bash_consumed = false
	if holding and not bash_consumed and not is_instance_valid(target) and is_instance_valid(candidate):
		bash_consumed = true
		target = candidate
		held_since = Time.get_ticks_msec()
		aim = Vector2.UP
		velocity = Vector2.ZERO
		dash_pending = 0
		jump_pending = 0
		launch_age = -1
		coast_remaining = 0
		state = State.BASH
		Engine.time_scale = t("bash_time_scale")
	was_held = holding
	if is_instance_valid(target):
		var direction: Vector2 = Controls.dir8()
		if direction != Vector2.ZERO: aim = direction
		if not holding or (Time.get_ticks_msec()-held_since)/1000.0 >= t("bash_max_hold"): _launch()
		return
	elif state == State.BASH:
		state = State.AIR
		Engine.time_scale = 1
	# A dash that ran its full distance keeps only part of its speed. Rising speed
	# keeps less: at 0.65 an up dash kept lifting the hero ~1.7 tiles afterwards,
	# a second small jump after the dash ("frog hop").
	if dash_ended:
		dash_ended = false
		if state != State.DASH:
			velocity.x *= t("dash_end_keep")
			velocity.y *= t("dash_end_up_keep") if velocity.y < 0 else t("dash_end_keep")
	lock_time = maxf(0,lock_time-delta)
	dash_cooldown = maxf(0,dash_cooldown-delta)
	var axis: float = signf(Controls.dir().x)
	if axis != 0 and state != State.DASH: facing = int(axis)
	if is_on_floor() and state != State.DASH: dash_uses = 0
	var on_wall: bool = is_on_wall() and not is_on_floor() and axis*get_wall_normal().x < 0
	jump_pending = maxf(0,jump_pending-delta)
	wall_grace = maxf(0,wall_grace-delta)
	if is_on_wall() and not is_on_floor() and lock_time <= 0:
		wall_normal = get_wall_normal()
		wall_grace = t("wall_jump_grace")
	if Controls.just(&"jump"): jump_pending = t("wall_jump_buffer")
	if jump_pending > 0:
		if wall_grace > 0 and not is_on_floor():
			jump_pending = 0
			wall_grace = 0
			velocity = Vector2(wall_normal.x*t("wall_jump_push_x"),-t("wall_jump_push_y"))
			lock_time = t("wall_jump_lock_time")
			state = State.AIR
			launch_age = -1
			coast_remaining = 0
			dash_uses = 0
			dash_cooldown = 0
			wall_jumped.emit()
		elif is_on_floor():
			jump_pending = 0
			velocity.y = -t("jump_velocity")
			state = State.AIR
			launch_age = -1
			coast_remaining = 0
			dash_pending = 0
			jumped.emit()
	# Each dash press owns its direction and may cut the first dash short.
	dash_pending = maxf(0,dash_pending-delta)
	if Controls.just(&"dash") and dash_uses < int(t("air_dash_count")):
		dash_pending = t("dash_input_buffer")
		pending_direction = Controls.dir8()
		if pending_direction == Vector2.ZERO: pending_direction = Vector2(facing,0)
	if dash_pending > 0 and (dash_cooldown <= 0 or dash_uses > 0) and dash_uses < int(t("air_dash_count")):
		dash_pending = 0
		_begin_dash(pending_direction)
	if state == State.DASH:
		if dash_reaim > 0:
			var fresh: Vector2 = Controls.dir8()
			if fresh != Vector2.ZERO and not fresh.is_equal_approx(dash_direction): _set_dash_direction(fresh)
			dash_reaim = maxf(0,dash_reaim-delta)
		var remaining: float = maxf(0,dash_time-dash_elapsed)
		dash_elapsed += delta
		velocity = dash_direction*dash_speed*minf(1,remaining/delta)
		if dash_elapsed >= dash_time or is_equal_approx(dash_elapsed,dash_time):
			state = State.AIR
			dash_ended = true
			if dash_uses < int(t("air_dash_count")): dash_cooldown = 0
	else:
		if launch_age >= 0:
			launch_age = minf(launch_age+delta,t("bash_launch_ramp"))
			var progress: float = smoothstep(0,1,launch_age/t("bash_launch_ramp"))
			velocity = launch_direction*t("bash_launch_speed")*lerpf(t("bash_start_speed_ratio"),1,progress)
			velocity.y += t("gravity")*launch_age
			if launch_age >= t("bash_launch_ramp"): launch_age = -1
		else:
			coast_remaining = maxf(0,coast_remaining-delta)
			if is_on_floor(): coast_remaining = 0
			var coast: float = coast_remaining/t("bash_coast_time")
			var control: float = t("wall_control_mult") if lock_time > 0 else 1.0
			var acceleration: float = lerpf(t("air_control_accel"),t("bash_coast_accel"),coast)
			velocity.x = move_toward(velocity.x,axis*t("move_speed"),acceleration*control*delta)
			if coast_remaining > 0 and velocity.y > t("max_fall_speed"):
				velocity.y = move_toward(velocity.y,t("max_fall_speed"),acceleration*delta)
			else:
				velocity.y += t("gravity")*delta
				if lock_time <= 0: velocity.y = minf(t("max_fall_speed"),velocity.y)
		if on_wall and velocity.y > t("wall_slide_speed"): velocity.y = t("wall_slide_speed")
		state = State.GROUND if is_on_floor() else State.AIR
	move_and_slide()
	for index: int in get_slide_collision_count():
		if get_slide_collision(index).get_normal().dot(launch_direction) < 0: launch_age = -1
