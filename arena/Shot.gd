# A straight projectile. Hero shots hit monsters, monster shots hit the hero; both
# stop at walls and solid props (physics layer 1). Positions are hit-test positions
# (body centre in the side view, feet in the top view); `lift` only moves the drawing.
extends Node2D
var arena: Node2D
var velocity: Vector2 = Vector2.ZERO
var from_hero: bool = true
var damage: int = 1
var force: float = 0
var life: float = 2.5
var lift: float = 0
var hit: Dictionary = {}

func _physics_process(delta: float) -> void:
	life -= delta
	var steps: int = 3
	for i: int in steps:
		position += velocity*delta/steps
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = global_position
		query.collision_mask = 1
		if life <= 0 or not get_world_2d().direct_space_state.intersect_point(query).is_empty():
			arena.remove_shot(self)
			return
		if from_hero:
			for foe: Node2D in arena.foes:
				if hit.has(foe) or foe.global_position.distance_to(global_position) > 13: continue
				hit[foe] = true
				arena.hero_fighter.stats.shot_hits += 1
				foe.take_hit(damage,velocity,force)
				arena.remove_shot(self)
				return
		elif arena.hero.global_position.distance_to(global_position) < 10:
			arena.hero_fighter.hurt(global_position-velocity,damage)
			arena.remove_shot(self)
			return
	queue_redraw()

func _draw() -> void:
	var at: Vector2 = Vector2(0,-lift)
	if from_hero:
		draw_line(at-velocity.normalized()*12,at,Color(1,0.85,0.4,0.6),3)
		draw_circle(at,3.5,Color("fff1b0"))
	else:
		draw_circle(at,5,Color(1,0.3,0.4,0.35))
		draw_circle(at,3,Color("ff6b7a"))
