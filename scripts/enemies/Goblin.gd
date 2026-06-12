extends EnemyBase

@export var attack_range: float  = 48.0
@export var attack_cooldown: float = 1.2

var attack_timer: float = 0.0

func _get_pixel_texture(): return PixelArt.make_goblin()

func _on_ready_extra():
	max_hp    = 40.0
	hp        = max_hp
	move_speed = 90.0
	damage    = 12.0
	xp_value  = 8
	body_color = Color(0.25, 0.6, 0.2)
	body_rect.color = body_color

func _tick_ai(delta: float):
	if attack_timer > 0.0:
		attack_timer -= delta

	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			_melee_attack()
	else:
		navigate_to(player.global_position, delta)

func _melee_attack():
	attack_timer = attack_cooldown
	if is_instance_valid(player) and player.has_method("take_damage"):
		if distance_to_player() <= attack_range:
			player.take_damage(damage)
