extends Area2D

# 冰系龙卷风 — summoned by Frozen Gale. Homes toward the nearest enemy, sweeping
# stray bullets out of its path. On contact it bursts: area damage + 30% freeze /
# 50% frostbite to nearby enemies, then vanishes. Lives at most 5s.

const SPEED    = 230.0
const RADIUS   = 48.0
const LIFETIME = 5.0

var damage: float = 30.0
var dir: Vector2  = Vector2.RIGHT
var _life: float  = LIFETIME

func _ready():
	collision_layer = 0
	collision_mask  = 8   # enemy bodies
	monitoring = true
	z_index = 1
	var col = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = RADIUS
	col.shape = c
	add_child(col)
	_build_visual()

func _build_visual():
	for i in 3:
		var disc = _disc(RADIUS * (1.0 - i * 0.24), Color(0.6, 0.85, 1.0, 0.28 + i * 0.14))
		disc.position.y = -i * 9.0
		add_child(disc)
	var spin = create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 0.5)

func _disc(r: float, col: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	poly.color = col
	return poly

func _process(delta: float):
	_life -= delta
	if _life <= 0.0:
		_fade_out()
		return

	var target := _nearest_enemy()
	if is_instance_valid(target):
		dir = dir.lerp((target.global_position - global_position).normalized(), delta * 3.0).normalized()
	global_position += dir * SPEED * delta

	# Sweep stray bullets out of the path.
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		if is_instance_valid(b) and b.global_position.distance_to(global_position) < RADIUS:
			b.queue_free()

	# Contact with any enemy → burst and vanish.
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body.is_in_group("enemy"):
			_burst()
			return

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _burst():
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(global_position) <= RADIUS * 1.3:
			if e.has_method("take_damage"):
				e.take_damage(damage)
			if e.has_method("apply_status"):
				if randf() < 0.3:
					e.apply_status("freeze")
				if randf() < 0.5:
					e.apply_status("frostbite")
	_fade_out()

func _fade_out():
	set_process(false)
	monitoring = false
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.parallel().tween_property(self, "scale", Vector2(1.4, 1.4), 0.2)
	t.tween_callback(queue_free)
