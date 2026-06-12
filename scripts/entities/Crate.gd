extends StaticBody2D
class_name Crate

var hp: float = 20.0
var _alive: bool = true

func _ready():
	add_to_group("crate")
	add_to_group("wall")
	var spr = PixelArt.sprite_from(PixelArt.make_crate())
	add_child(spr)

func take_damage(amount: float, _kb: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not _alive:
		return
	hp -= amount
	# shake
	var tw = create_tween()
	tw.tween_property(self, "position", position + Vector2(3, 0), 0.04)
	tw.tween_property(self, "position", position, 0.04)
	if hp <= 0.0:
		_break()

func _break():
	_alive = false
	set_deferred("collision_layer", 0)
	# drops
	if randf() < 0.25:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 15)
	if randf() < 0.35:
		Pickup.spawn(get_parent(), global_position + Vector2(10, 0), Pickup.Type.AMMO_ORB, 10)
	# break particles
	for i in 10:
		var cr = ColorRect.new()
		cr.color = Color(0.60, 0.42, 0.18)
		var sz = randf_range(3, 8)
		cr.size = Vector2(sz, sz)
		cr.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		get_parent().add_child(cr)
		var tw = cr.create_tween()
		tw.tween_property(cr, "global_position",
			cr.global_position + Vector2(randf_range(-30, 30), randf_range(-40, 10)), 0.45)
		tw.parallel().tween_property(cr, "modulate:a", 0.0, 0.45)
		tw.tween_callback(cr.queue_free)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
