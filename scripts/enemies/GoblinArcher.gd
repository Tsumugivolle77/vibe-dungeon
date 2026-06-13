extends EnemyBase

func _get_pixel_texture(): return PixelArt.make_goblin_archer()

@export var preferred_distance: float = 220.0
@export var fire_cooldown: float      = 1.8
@export var bullet_speed: float       = 220.0

var fire_timer: float = 0.8

func _on_ready_extra():
	max_hp     = 30.0
	hp         = max_hp
	move_speed  = 70.0
	damage     = 10.0
	xp_value   = 10
	body_color  = Color(0.3, 0.55, 0.15)
	body_rect.color = body_color
	body_size   = Vector2(28, 28)
	body_rect.size = body_size
	body_rect.position = -body_size * 0.5

func _tick_ai(delta: float):
	if fire_timer > 0.0:
		fire_timer -= delta

	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	# Maintain preferred distance
	if dist < preferred_distance - 40.0:
		var away = -direction_to_player()
		velocity = away * move_speed * slow_factor
	elif dist > preferred_distance + 40.0:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO

	if fire_timer <= 0.0 and dist < 400.0:
		_shoot_at_player()

func _shoot_at_player():
	fire_timer = fire_cooldown
	# Fast "sniper" arrow.
	shoot(direction_to_player(), bullet_speed * 2.2, -1.0, {"kind": "sniper"})
