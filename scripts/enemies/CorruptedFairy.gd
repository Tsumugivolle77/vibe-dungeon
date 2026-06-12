extends EnemyBase

@export var fly_height: float    = -20.0  # Y offset (visual only)
@export var preferred_dist: float = 200.0
@export var fire_cooldown: float  = 0.6
@export var volley_count: int     = 3

var fire_timer: float  = 0.3
var hover_phase: float = 0.0

func _on_ready_extra():
	max_hp      = 35.0
	hp          = max_hp
	move_speed   = 120.0
	damage      = 9.0
	xp_value    = 14
	body_color   = Color(0.85, 0.3, 0.8, 0.9)
	body_size    = Vector2(24, 24)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = Vector2(-12, -12)
	# Fairies ignore ground physics (no floor snapping)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func _tick_ai(delta: float):
	fire_timer -= delta
	hover_phase += delta * 2.5

	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	var hover_offset = Vector2(0, sin(hover_phase) * 12.0)

	if dist < preferred_dist - 30.0:
		velocity = (-direction_to_player() + hover_offset * 0.05) * move_speed
	elif dist > preferred_dist + 30.0:
		velocity = (direction_to_player() + hover_offset * 0.05) * move_speed
	else:
		var perp = direction_to_player().rotated(PI * 0.5)
		velocity = (perp + hover_offset * 0.05) * move_speed * 0.6

	if fire_timer <= 0.0 and dist < 400.0:
		_shoot_volley()

func _shoot_volley():
	fire_timer = fire_cooldown
	for i in volley_count:
		var delay = i * 0.08
		_shoot_delayed(delay)

func _shoot_delayed(delay: float):
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self) or not alive:
		return
	if is_instance_valid(player):
		var aim = direction_to_player()
		aim = aim.rotated(randf_range(-0.15, 0.15))
		shoot(aim, 260.0)
