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
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.65, 0.15, 0.7)
	flash.size = Vector2(RADIUS * 2, RADIUS * 2)
	flash.global_position = global_position - Vector2(RADIUS, RADIUS)
	get_parent().add_child(flash)
	var t = flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)
	for i in 10:
		var cr = ColorRect.new()
		cr.color = Color(1.0, 0.8, 0.2, 0.9) if i % 2 == 0 else Color(0.9, 0.3, 0.1, 0.9)
		var s = randf_range(5.0, 11.0)
		cr.size = Vector2(s, s)
		cr.global_position = global_position - cr.size * 0.5
		get_parent().add_child(cr)
		var ang = (TAU / 10.0) * i + randf_range(-0.3, 0.3)
		var tw = cr.create_tween()
		tw.tween_property(cr, "global_position",
			cr.global_position + Vector2(cos(ang), sin(ang)) * randf_range(40, RADIUS), 0.3)
		tw.parallel().tween_property(cr, "modulate:a", 0.0, 0.3)
		tw.tween_callback(cr.queue_free)
