extends StaticBody2D

# An explosive barrel: any hit detonates it, dealing area damage with center
# falloff to BOTH enemies and the player. Chain-reacts with nearby barrels.
# In the "crate" group so player bullets/melee trigger it; in "barrel" group so
# enemy bullets (and other explosions) can trigger it too.

const RADIUS = 96.0
const DAMAGE = 50.0

var _exploded: bool = false

func _ready():
	add_to_group("crate")
	add_to_group("barrel")
	collision_layer = 1   # world — blocks movement and stops bullets
	var spr = PixelArt.sprite_from(PixelArt.make_barrel())
	add_child(spr)
	var col = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 12.0
	col.shape = c
	add_child(col)

func take_damage(_amount: float = 0.0):
	explode()

func explode():
	if _exploded:
		return
	_exploded = true
	collision_layer = 0

	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d <= RADIUS and e.has_method("take_damage"):
			e.take_damage(DAMAGE * (1.0 - d / RADIUS),
				(e.global_position - global_position).normalized() * 220.0)

	var pl = GameManager.player_ref
	if is_instance_valid(pl):
		var pd: float = pl.global_position.distance_to(global_position)
		if pd <= RADIUS and pl.has_method("take_damage"):
			pl.take_damage(DAMAGE * (1.0 - pd / RADIUS))

	# Chain-react nearby barrels (deferred to avoid re-entrancy).
	for b in get_tree().get_nodes_in_group("barrel"):
		if b != self and is_instance_valid(b) and not b._exploded:
			if b.global_position.distance_to(global_position) <= RADIUS:
				b.call_deferred("explode")

	_spawn_blast()
	queue_free()

func _spawn_blast():
	var parent = get_parent()

	# Bright filled fireball core that flashes white-hot then fades.
	var core := _circle_poly(RADIUS * 0.7, Color(1.0, 0.95, 0.6, 0.95))
	core.global_position = global_position
	core.scale = Vector2(0.3, 0.3)
	parent.add_child(core)
	var ct := core.create_tween()
	ct.tween_property(core, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT)
	ct.parallel().tween_property(core, "color", Color(1.0, 0.45, 0.1, 0.0), 0.32)
	ct.tween_callback(core.queue_free)

	# Expanding shockwave ring (bright outline that grows past the blast radius).
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.85, 0.4, 0.9)
	ring.closed = true
	var seg := 22
	for i in seg:
		var a := (TAU / seg) * i
		ring.add_point(Vector2(cos(a), sin(a)) * RADIUS)
	ring.global_position = global_position
	ring.scale = Vector2(0.2, 0.2)
	parent.add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale", Vector2(1.35, 1.35), 0.35).set_ease(Tween.EASE_OUT)
	rt.parallel().tween_property(ring, "width", 1.0, 0.35)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	rt.tween_callback(ring.queue_free)

	# Hot debris flung outward.
	for i in 16:
		var cr = ColorRect.new()
		cr.color = Color(1.0, 0.8, 0.2, 0.95) if i % 2 == 0 else Color(0.95, 0.3, 0.1, 0.95)
		var s = randf_range(5.0, 12.0)
		cr.size = Vector2(s, s)
		cr.global_position = global_position - cr.size * 0.5
		parent.add_child(cr)
		var ang = (TAU / 16.0) * i + randf_range(-0.3, 0.3)
		var tw = cr.create_tween()
		tw.tween_property(cr, "global_position",
			cr.global_position + Vector2(cos(ang), sin(ang)) * randf_range(50, RADIUS * 1.1), 0.34)
		tw.parallel().tween_property(cr, "rotation", randf_range(-PI, PI), 0.34)
		tw.parallel().tween_property(cr, "modulate:a", 0.0, 0.34)
		tw.tween_callback(cr.queue_free)

	# Lingering dark smoke puffs that drift up and fade slowly.
	for i in 5:
		var smoke = _circle_poly(randf_range(12.0, 20.0), Color(0.18, 0.16, 0.15, 0.6))
		smoke.global_position = global_position + Vector2(randf_range(-26, 26), randf_range(-26, 26))
		parent.add_child(smoke)
		var st := smoke.create_tween()
		st.tween_property(smoke, "global_position:y", smoke.global_position.y - 34.0, 0.7)
		st.parallel().tween_property(smoke, "scale", Vector2(1.7, 1.7), 0.7)
		st.parallel().tween_property(smoke, "modulate:a", 0.0, 0.7)
		st.tween_callback(smoke.queue_free)

# Builds a filled circle polygon of the given radius and colour, centred on origin.
func _circle_poly(radius: float, col: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var seg := 18
	for i in seg:
		var a := (TAU / seg) * i
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color = col
	return poly
