extends "res://scripts/enemies/EnemyBase.gd"

# 巨型藤蔓 — summoned by the Ancient Treant. Rooted in place; deals contact damage
# to anyone who touches it and periodically fires a ring of wall-bouncing bullets
# centred on itself. Despawns after a while so they don't pile up.

var _shoot_timer: float = 1.0
var _contact_cd: float  = 0.0
var _life: float        = 5.0   # auto-dies after 5s

func _get_pixel_texture(): return PixelArt.make_giant_vine()

func _is_boss_type() -> bool:
	return true   # summoned hazard: skip the generic non-boss damage multiplier

func _on_ready_extra():
	add_to_group("giant_vine")   # so the Treant can cap how many are on the field
	max_hp        = 130.0
	hp            = max_hp
	move_speed    = 0.0
	damage        = 16.0
	xp_value      = 30
	gold_drop_min = 0
	gold_drop_max = 0
	body_color    = Color(0.20, 0.55, 0.16)
	body_size     = Vector2(40, 60)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	if sprite:
		sprite.scale = Vector2(1.7, 1.7)
	# Rise-up entrance.
	scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _tick_ai(delta: float):
	velocity = Vector2.ZERO
	_life -= delta
	if _life <= 0.0:
		_die()
		return
	_contact_tick(delta)
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = 1.7
		_radial_burst()

func _contact_tick(delta: float):
	if _contact_cd > 0.0:
		_contact_cd -= delta
		return
	var pl = GameManager.player_ref
	if is_instance_valid(pl) and pl.has_method("take_damage") \
			and global_position.distance_to(pl.global_position) <= 50.0:
		pl.take_damage(damage)
		_contact_cd = 0.6

# A ring of bouncing bolts radiating out from the vine.
func _radial_burst():
	var n := 12
	for i in n:
		var a := TAU * float(i) / float(n)
		shoot(Vector2(cos(a), sin(a)), 205.0, damage * 0.7, {"bounce": 3, "lifetime": 5.0})
