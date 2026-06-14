extends "res://scripts/enemies/BossBase.gd"

# Sublevel 2 boss — 史莱姆之母. Slow-moving; lobs expanding bullet rings and
# spawns slime minions. Rings get denser with each phase.

const SLIME_SCENE = "res://scenes/enemies/Slime.tscn"

func _get_pixel_texture(): return PixelArt.make_slime_mother()

func _on_ready_extra():
	max_hp     = 1050.0
	hp         = max_hp
	move_speed = 45.0
	damage     = 14.0
	xp_value   = 350
	boss_drop_weapon = "slime_burst"
	body_color = Color(0.30, 0.80, 0.34)
	body_size  = Vector2(64, 64)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	super()

func _boss_ai(delta: float):
	# Gentle drift toward the player
	if is_instance_valid(player) and distance_to_player() > 120.0:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO

	if action_timer > 0.0:
		return

	# Point-blank: favour a melee leap-slam over lobbing rings.
	if distance_to_player() < 95.0 and randf() < 0.6:
		action_timer = 2.6
		_slam_leap()
		return

	match phase:
		1:
			action_timer = 2.4
			ring(8, 160.0, -1.0, randf() * TAU)
		2:
			action_timer = 2.8
			match randi() % 3:
				0: _double_ring()
				1: summon(SLIME_SCENE, 3)
				2: _slam_leap()
		3:
			action_timer = 2.4
			match randi() % 4:
				0: _double_ring()
				1:
					cast_guard(2.5)                           # powerful skill: aegis up
					ring(16, 180.0, -1.0, randf() * TAU)
				2: summon(SLIME_SCENE, 4)
				3: _slam_leap()

# Berserk displacement: heave the whole gelatinous body onto the player and slam,
# bursting a dense bullet ring outward on landing.
func _slam_leap():
	if not is_instance_valid(player):
		return
	leap_to(player.global_position, 14, 200.0)

func _double_ring():
	ring(10, 150.0, -1.0, 0.0)
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree() and alive:
		ring(10, 190.0, -1.0, deg_to_rad(18.0))
