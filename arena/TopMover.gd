# Flat top-down movement for the view test: 8-way run with a little acceleration and
# one dash (Space or Shift). The node sits at the hero's feet; the body is a small
# footprint so the drawn figure can overlap walls and props behind it.
class_name TopMover
extends CharacterBody2D
var tuning: Dictionary = {}
var facing: int = 1
var face: Vector2 = Vector2.RIGHT
var dashing: bool = false
var dash_time: float = 0
var dash_cooldown: float = 0
var dash_direction: Vector2 = Vector2.RIGHT
var push: Vector2 = Vector2.ZERO
var frozen: bool = false
var body_size: Vector2 = Vector2(16,8)

func _ready() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = body_size
	add_child(shape)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func t(key: String) -> float:
	return float(tuning[key])

func _physics_process(delta: float) -> void:
	dash_cooldown = maxf(0,dash_cooldown-delta)
	push = push.move_toward(Vector2.ZERO,900*delta)
	if frozen:
		velocity = push
		move_and_slide()
		return
	var input: Vector2 = Controls.dir()
	if input != Vector2.ZERO:
		input = input.normalized()
		face = input
		if input.x != 0: facing = int(signf(input.x))
	if not dashing and dash_cooldown <= 0 and (Controls.just(&"dash") or Controls.just(&"jump")):
		dashing = true
		dash_time = t("top_dash_time")
		dash_direction = input if input != Vector2.ZERO else face
	if dashing:
		dash_time -= delta
		velocity = dash_direction*t("top_dash_distance")/t("top_dash_time")
		if dash_time <= 0:
			dashing = false
			dash_cooldown = t("top_dash_cooldown")
			velocity *= 0.35
	else:
		velocity = velocity.move_toward(input*t("top_move_speed"),t("top_accel")*delta)
	velocity += push
	move_and_slide()
	velocity -= push
