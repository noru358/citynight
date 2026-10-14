# The hero's combat, shared by both views: slash (J / left click), shoot (L / right
# click), ammo that only melee hits refill, health and hurt. Aim follows the mouse
# while it is being used, otherwise the held direction, otherwise where the hero faces.
# Hit tests use the body's position: the body centre in the side view, the feet in
# the top view (`lift` only moves the drawing up to the chest).
extends Node2D
var arena: Node2D
var body: CharacterBody2D
var top: bool = false
var tuning: Dictionary = {}
var hp: int = 0
var ammo: float = 0
var slash_cooldown: float = 0
var shot_cooldown: float = 0
var invuln: float = 0
var aim: Vector2 = Vector2.RIGHT
var bot_aim: Vector2 = Vector2.ZERO
var mouse_at: int = -100000
var slash_flash: float = 0
var slash_direction: Vector2 = Vector2.RIGHT
var empty_flash: float = 0
var lift: float = 0
var stats: Dictionary = {"slashes":0,"slash_hits":0,"shots":0,"shot_hits":0,"hurt":0,"deflects":0,"pogos":0}

func t(key: String) -> float:
	return float(tuning[key])

func setup() -> void:
	hp = int(t("hero_hp"))
	ammo = t("ammo_start")
	lift = 14.0 if top else 0.0
	z_index = 5

func at() -> Vector2:
	return body.global_position

func dashing() -> bool:
	if top: return body.dashing
	return body.state == Mover.State.DASH

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton: mouse_at = Time.get_ticks_msec()

func _update_aim() -> void:
	if Controls.scripted:
		if bot_aim != Vector2.ZERO: aim = bot_aim.normalized()
		return
	if Time.get_ticks_msec()-mouse_at < 2000:
		var to: Vector2 = get_global_mouse_position()-(at()-Vector2(0,lift))
		if to.length() > 2: aim = to.normalized()
		return
	var held: Vector2 = Controls.dir8()
	if top:
		aim = held if held != Vector2.ZERO else body.face
	elif held != Vector2.ZERO and not (body.is_on_floor() and held.x == 0 and held.y > 0):
		aim = held
	else:
		aim = Vector2(body.facing,0)

func _physics_process(delta: float) -> void:
	slash_cooldown = maxf(0,slash_cooldown-delta)
	shot_cooldown = maxf(0,shot_cooldown-delta)
	invuln = maxf(0,invuln-delta)
	slash_flash = maxf(0,slash_flash-delta)
	empty_flash = maxf(0,empty_flash-delta)
	if hp <= 0 or arena.over: return
	_update_aim()
	if Controls.just(&"slash") and slash_cooldown <= 0: _slash()
	if Controls.just(&"shoot") and shot_cooldown <= 0:
		if ammo >= 1: _shoot()
		else: empty_flash = 0.3
	queue_redraw()
	var look: Node2D = body.get_node_or_null("Look")
	if look: look.modulate.a = 0.35 if invuln > 0 and int(invuln*20)%2 == 0 else 1.0

func _slash() -> void:
	slash_cooldown = t("slash_cooldown")
	slash_flash = 0.12
	slash_direction = aim
	stats.slashes += 1
	var hits: int = arena.melee(at(),aim,t("slash_radius"),deg_to_rad(t("slash_arc_deg"))/2,int(t("slash_damage")),t("slash_knockback"))
	if hits <= 0: return
	stats.slash_hits += hits
	ammo = minf(t("ammo_max"),ammo+t("slash_charge")*hits)
	arena.hitstop()
	# Side view: a down slash in the air that lands bounces the hero up (pogo).
	if not top and aim.y > 0.5 and not body.is_on_floor():
		body.velocity.y = -t("pogo_speed")
		body.dash_uses = 0
		stats.pogos += 1

func _shoot() -> void:
	ammo -= 1
	shot_cooldown = t("shot_cooldown")
	stats.shots += 1
	arena.spawn_shot(at()+aim*12,aim*t("shot_speed"),true,int(t("shot_damage")),t("shot_knockback"))
	if top: body.push = -aim*t("shot_recoil")*3
	elif not body.is_on_floor(): body.velocity -= aim*t("shot_recoil")
	arena.shake(1.5)

func hurt(from: Vector2, damage: int) -> void:
	if invuln > 0 or dashing() or hp <= 0 or arena.over: return
	hp -= damage
	invuln = t("hurt_invuln")
	stats.hurt += 1
	var away: Vector2 = (at()-from).normalized()
	if away == Vector2.ZERO: away = Vector2(-body.facing,0)
	if top: body.push = away*t("hurt_knockback")*2
	else: body.velocity = Vector2(away.x*t("hurt_knockback"),-t("hurt_knockback")*0.8)
	arena.shake(5)
	if hp <= 0: arena.hero_down()

func _draw() -> void:
	var chest: Vector2 = Vector2(0,-lift)
	# Ammo cartridges over the head.
	var head: Vector2 = chest+Vector2(0,-30 if top else -26)
	var count: int = int(t("ammo_max"))
	for i: int in count:
		var box: Rect2 = Rect2(head+Vector2((i-count/2.0)*8,0),Vector2(6,4))
		draw_rect(box,Color(0.1,0.1,0.15,0.8))
		var fill: float = clampf(ammo-i,0,1)
		var color: Color = Color("ffd166") if fill >= 1 else Color("7f6a3a")
		if empty_flash > 0: color = Color("ff5050")
		draw_rect(Rect2(box.position,Vector2(box.size.x*fill,box.size.y)),color)
	# Aim tick.
	draw_line(chest+aim*14,chest+aim*20,Color(1,1,1,0.55),1.5)
	# Slash arc.
	if slash_flash > 0:
		var strength: float = slash_flash/0.12
		var half: float = deg_to_rad(t("slash_arc_deg"))/2
		var base: float = slash_direction.angle()
		draw_arc(chest,t("slash_radius")*0.8,base-half,base+half,14,Color(0.85,0.95,1,strength),5*strength+1)
		draw_arc(chest,t("slash_radius")*0.55,base-half*0.7,base+half*0.7,10,Color(0.6,0.8,1,strength*0.6),2)
