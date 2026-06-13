extends EnemyBase

func _get_pixel_texture(): return PixelArt.make_tree_monster()

@export var shoot_range: float   = 360.0
@export var shoot_cooldown: float = 2.0
@export var seeds_per_shot: int   = 4

var shoot_timer: float = 1.0

func _on_ready_extra():
	max_hp      = 70.0
	hp          = max_hp
	move_speed   = 35.0
	damage      = 14.0
	xp_value    = 15
	body_color   = Color(0.3, 0.5, 0.15)
	body_size    = Vector2(48, 48)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5

func _tick_ai(delta: float):
	shoot_timer -= delta
	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	# Slowly drift toward player
	if dist > 80.0:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO

	if shoot_timer <= 0.0 and dist <= shoot_range:
		_throw_seeds()

func _throw_seeds():
	shoot_timer = shoot_cooldown
	for i in seeds_per_shot:
		var base_dir = direction_to_player()
		var spread   = deg_to_rad(15.0 * (i - seeds_per_shot / 2.0))
		var dir      = base_dir.rotated(spread)
		shoot(dir, 200.0)
