extends EnemyBase

func _get_pixel_texture(): return PixelArt.make_elite_goblin()

@export var shield_arc: float     = 90.0  # degrees, front-facing shield
@export var attack_range: float   = 55.0
@export var attack_cooldown: float = 1.0

var attack_timer: float  = 0.0
var shield_facing: float = 0.0  # Radians, updated each frame

const RARE_DROPS = ["thunder_bow", "holy_sword", "frozen_gale"]
func _on_die_extra():
	if randf() < 0.25:
		# Use the shared helper so the rare drop lands inside the room, not off-map.
		spawn_weapon_pickup(RARE_DROPS[randi() % RARE_DROPS.size()])

func _on_ready_extra():
	max_hp      = 90.0
	hp          = max_hp
	is_elite    = true
	move_speed   = 75.0
	damage      = 18.0
	xp_value    = 20
	body_color   = Color(0.15, 0.45, 0.15)
	body_size    = Vector2(36, 40)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5

func _tick_ai(delta: float):
	attack_timer -= delta
	if not is_instance_valid(player):
		return

	shield_facing = direction_to_player().angle()

	var dist = distance_to_player()
	if dist > attack_range:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			_shield_bash()

func _shield_bash():
	attack_timer = attack_cooldown
	if is_instance_valid(player) and distance_to_player() <= attack_range:
		player.take_damage(damage)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	# Block damage from front half
	if is_instance_valid(player):
		var attack_dir = (global_position - player.global_position).angle()
		var diff = abs(angle_difference(attack_dir, shield_facing))
		if diff <= deg_to_rad(shield_arc * 0.5):
			amount *= 0.1  # 90% block
	super.take_damage(amount, knockback, _props)

func angle_difference(a: float, b: float) -> float:
	var d = fmod(b - a + PI, TAU) - PI
	return d
