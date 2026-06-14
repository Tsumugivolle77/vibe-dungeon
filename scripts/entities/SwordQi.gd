extends Area2D

# 剑气 — a large yellow crescent of sword energy summoned by the Holy Sword. Flies
# forward, sweeps stray bullets out of its path, and damages + knocks back enemies
# it passes through WITHOUT vanishing (it persists for 5s). 50% chance of holy DoT.

const SPEED    = 280.0
const LIFETIME = 5.0
const REHIT_CD = 0.4

var damage: float = 30.0
var dir: Vector2  = Vector2.RIGHT
var _life: float  = LIFETIME
var _hit_cd: Dictionary = {}   # enemy instance -> remaining re-hit cooldown

func _ready():
	collision_layer = 0
	collision_mask  = 8   # enemy bodies
	monitoring = true
	z_index = 1
	rotation = dir.angle()
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(46, 96)
	col.shape = rect
	add_child(col)
	_build_visual()

func _build_visual():
	var arc := Polygon2D.new()
	var pts := PackedVector2Array()
	var half := deg_to_rad(74.0) * 0.5
	var r_out := 62.0
	var r_in := 32.0
	var steps := 12
	for i in steps + 1:
		var a: float = lerp(-half, half, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * r_out)
	for i in steps + 1:
		var a: float = lerp(half, -half, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * r_in)
	arc.polygon = pts
	arc.color = Color(1.0, 0.9, 0.3, 0.7)
	add_child(arc)
	var edge := Line2D.new()
	edge.width = 4.0
	edge.default_color = Color(1.0, 1.0, 0.7, 0.9)
	for i in steps + 1:
		var a: float = lerp(-half, half, float(i) / steps)
		edge.add_point(Vector2(cos(a), sin(a)) * r_out)
	add_child(edge)

func _process(delta: float):
	_life -= delta
	if _life <= 0.0:
		set_process(false)
		var t = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)
		return

	global_position += dir * SPEED * delta
	rotation = dir.angle()

	for k in _hit_cd.keys():
		_hit_cd[k] = float(_hit_cd[k]) - delta

	# Sweep stray bullets.
	for b in get_tree().get_nodes_in_group("enemy_bullet"):
		if is_instance_valid(b) and b.global_position.distance_to(global_position) < 60.0:
			b.queue_free()

	# Damage + knock back overlapping enemies (persistent, with a per-enemy cooldown).
	for body in get_overlapping_bodies():
		if not (is_instance_valid(body) and body.is_in_group("enemy")):
			continue
		if _hit_cd.has(body) and float(_hit_cd[body]) > 0.0:
			continue
		if body.has_method("take_damage"):
			body.take_damage(damage, dir * 320.0)
		if body.has_method("apply_status") and randf() < 0.5:
			body.apply_status("holy")
		_hit_cd[body] = REHIT_CD
