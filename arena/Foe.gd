# Two placeholder monsters for the view test.
# grunt: walks up, winds up (flashes), lunges; only the lunge hurts. A slash during
#   the wind-up staggers it. Side view: hops when the hero is above it.
# gunner: keeps its distance, aims (a thin line), then fires one slow shot.
# Side view uses gravity and the node is the body centre; top view floats and the
# node is the feet. Foes sit on physics layer 2 so the hero passes through them and
# the hero's bash ray (layer 1) still reaches them: in the side view they are bashable.
extends CharacterBody2D
enum Phase { MOVE, WINDUP, LUNGE, RECOVER, AIM }
var arena: Node2D
var kind: String = "grunt"
var top: bool = false
var tuning: Dictionary = {}
var hp: int = 1
var phase: Phase = Phase.MOVE
var timer: float = 0
var fire_timer: float = 0
var lunge_direction: Vector2 = Vector2.RIGHT
var knock: Vector2 = Vector2.ZERO
var hurt_flash: float = 0
var hop_cooldown: float = 0
var highlight: bool = false
var size: Vector2 = Vector2(20,24)
var gravity: float = 750
var facing: int = 1
var strafe: float = 1
var detour: float = 0

func t(key: String) -> float:
	return float(tuning[key])

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	hp = int(t(kind+"_hp"))
	if kind == "gunner": size = Vector2(18,30)
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(14,8) if top else size
	add_child(shape)
	if top: motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	else: add_to_group("bashable")
	fire_timer = t("gunner_fire_every")*randf_range(0.5,1.0)
	strafe = 1.0 if randf() < 0.5 else -1.0

func take_hit(damage: int, direction: Vector2, force: float) -> void:
	hp -= damage
	hurt_flash = 0.12
	knock = direction.normalized()*force
	if phase == Phase.WINDUP or phase == Phase.AIM:
		phase = Phase.RECOVER
		timer = 0.3
	if hp <= 0: arena.foe_died(self)

# Side view bash: the hero kicks off this monster.
func bash(direction: Vector2) -> void:
	take_hit(1,direction,180)
	arena.hero_fighter.ammo = minf(t("ammo_max"),arena.hero_fighter.ammo+t("slash_charge"))

func _physics_process(delta: float) -> void:
	hurt_flash = maxf(0,hurt_flash-delta)
	hop_cooldown = maxf(0,hop_cooldown-delta)
	knock = knock.move_toward(Vector2.ZERO,700*delta)
	var hero: Vector2 = arena.hero.global_position
	var to: Vector2 = hero-global_position
	var distance: float = to.length()
	if to.x != 0 and phase == Phase.MOVE: facing = int(signf(to.x))
	var want: Vector2 = Vector2.ZERO
	timer -= delta
	if arena.over: phase = Phase.RECOVER
	match phase:
		Phase.MOVE:
			if kind == "grunt":
				want = Vector2(signf(to.x),0)*t("grunt_speed") if not top else to.normalized()*t("grunt_speed")
				var lined_up: bool = top or absf(to.y) < 30
				if distance < t("grunt_reach") and lined_up:
					phase = Phase.WINDUP
					timer = t("grunt_windup")
					lunge_direction = to.normalized() if top else Vector2(signf(to.x),0)
				elif not top and is_on_floor() and to.y < -40 and absf(to.x) < 90 and hop_cooldown <= 0:
					velocity.y = -330
					hop_cooldown = 1.4
			else:
				var away: Vector2 = -to.normalized()
				if distance < t("gunner_keep")-25: want = away*t("gunner_speed")
				elif distance > t("gunner_keep")+50: want = -away*t("gunner_speed")
				elif top: want = away.orthogonal()*strafe*t("gunner_speed")*0.6
				if not top: want.y = 0
				fire_timer -= delta
				if fire_timer <= 0:
					phase = Phase.AIM
					timer = t("gunner_aim_time")
		Phase.WINDUP:
			if timer <= 0:
				phase = Phase.LUNGE
				timer = t("grunt_lunge_time")
		Phase.LUNGE:
			want = lunge_direction*t("grunt_lunge_speed")
			if distance < 22: arena.hero_fighter.hurt(global_position,1)
			if timer <= 0:
				phase = Phase.RECOVER
				timer = t("grunt_recover")
		Phase.AIM:
			if timer > 0.25: lunge_direction = to.normalized()
			if timer <= 0:
				arena.spawn_shot(global_position+lunge_direction*10,lunge_direction*t("gunner_shot_speed"),false,1,0)
				phase = Phase.MOVE
				fire_timer = t("gunner_fire_every")
		Phase.RECOVER:
			if timer <= 0 and not arena.over: phase = Phase.MOVE
	if top:
		# Blocked by a prop: slide around it for a moment instead of pushing into it.
		detour = maxf(0,detour-delta)
		if detour > 0 and want != Vector2.ZERO: want = (want.normalized()+want.normalized().orthogonal()*strafe*1.5).normalized()*want.length()
		velocity = want+knock
	else:
		# Don't walk off a ledge on purpose.
		if want.x != 0 and is_on_floor():
			var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position+Vector2(signf(want.x)*(size.x/2+4),0),global_position+Vector2(signf(want.x)*(size.x/2+4),size.y),1)
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty() and phase != Phase.LUNGE: want.x = 0
		velocity.x = want.x+knock.x
		if knock.y < -1: velocity.y = minf(velocity.y,knock.y)
		velocity.y = minf(velocity.y+gravity*delta,450)
	move_and_slide()
	if top and want != Vector2.ZERO and detour <= 0 and get_slide_collision_count() > 0 and get_real_velocity().length() < want.length()*0.5: detour = 0.6
	queue_redraw()

func _draw() -> void:
	var lift: float = 12.0 if top else 0.0
	if top: draw_set_transform(Vector2.ZERO)
	if top: _draw_shadow()
	var center: Vector2 = Vector2(0,-lift)
	var base: Color = Color("6b3fa0") if kind == "grunt" else Color("2f8f8a")
	if phase == Phase.WINDUP: base = Color("e04f5f") if int(timer*16)%2 == 0 else Color("ffd0d0")
	if hurt_flash > 0: base = Color.WHITE
	var box: Rect2 = Rect2(center-size/2,size)
	if kind == "grunt":
		# A hunched lump with a bent signpost stuck in its back.
		draw_rect(Rect2(box.position+Vector2(0,size.y*0.25),Vector2(size.x,size.y*0.75)),base)
		draw_circle(center+Vector2(0,-size.y*0.1),size.x*0.45,base)
		draw_line(center+Vector2(-facing*4,-size.y*0.3),center+Vector2(-facing*9,-size.y*0.9),Color("8a8f99"),2)
		draw_rect(Rect2(center+Vector2(-facing*9-4,-size.y*0.9-5),Vector2(8,5)),Color("e2574c"))
	else:
		# A tall thing whose head is a flickering sign box.
		draw_rect(Rect2(box.position+Vector2(3,size.y*0.35),Vector2(size.x-6,size.y*0.65)),base)
		draw_rect(Rect2(box.position,Vector2(size.x,size.y*0.4)),Color("1b1e2c"))
		draw_rect(Rect2(box.position,Vector2(size.x,size.y*0.4)),Color("4ff0d0"),false,1.5)
	var eye: Vector2 = center+Vector2(facing*size.x*0.2,-size.y*0.15 if kind == "grunt" else -size.y*0.3)
	draw_circle(eye,2,Color("fff3a0"))
	if phase == Phase.AIM:
		var alpha: float = 0.25 if timer > 0.25 else 0.8
		draw_line(center,center+lunge_direction*260,Color(1,0.4,0.4,alpha),1)
	if highlight: draw_arc(center,maxf(size.x,size.y)*0.75,0,TAU,20,Color(1,0.9,0.6,0.8),1.5)
	# Health ticks.
	for i: int in hp: draw_rect(Rect2(center+Vector2(-size.x/2+i*5,-size.y/2-7),Vector2(3,3)),Color(1,1,1,0.7))

func _draw_shadow() -> void:
	draw_set_transform(Vector2(0,1),0,Vector2(1,0.4))
	draw_circle(Vector2.ZERO,size.x*0.6,Color(0,0,0,0.35))
	draw_set_transform(Vector2.ZERO)
