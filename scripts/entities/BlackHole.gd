extends Node2D

# 黑洞 — left by the Void Cannon's explosion. Pulls nearby enemies toward its centre
# and inflicts the dark (黑暗) DoT. Bosses are only pulled at 1/3 strength.

const RADIUS   = 190.0
const PULL     = 130.0
const LIFETIME = 2.5

var _life: float = LIFETIME
var _dot: float  = 0.0

func _ready():
	z_index = 2
	_build_visual()
	scale = Vector2(0.3, 0.3)
	var pop = create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)
	var spin = create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 1.1)

func _build_visual():
	add_child(_disc(RADIUS, Color(0.40, 0.15, 0.62, 0.10)))   # faint pull halo
	add_child(_disc(40.0, Color(0.30, 0.10, 0.50, 0.55)))     # purple rim
	add_child(_disc(26.0, Color(0.06, 0.02, 0.12, 0.98)))     # dark core

func _disc(r: float, col: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var seg := 22
	for i in seg:
		var a := TAU * i / seg
		pts.append(Vector2(cos(a), sin(a)) * r)
	poly.polygon = pts
	poly.color = col
	return poly

func _process(delta: float):
	_life -= delta
	if _life <= 0.0:
		set_process(false)
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(0.05, 0.05), 0.3)
		t.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)
		return

	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d > RADIUS or d < 6.0:
			continue
		var bossish: bool = e.has_method("_is_boss_type") and e._is_boss_type()
		var pull := PULL * (0.33 if bossish else 1.0)
		var dir: Vector2 = (global_position - e.global_position).normalized()
		e.global_position += dir * pull * delta

	# Apply the dark DoT in pulses (apply_status grants its own 3s tick).
	_dot -= delta
	if _dot <= 0.0:
		_dot = 0.6
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.has_method("apply_status") \
					and e.global_position.distance_to(global_position) <= RADIUS:
				e.apply_status("dark")
