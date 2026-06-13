extends "res://scripts/enemies/BossBase.gd"

# Sublevel 4 boss — 精灵女王. Fast, evasive flyer: rotating spiral volleys,
# aimed bursts, and short teleport-blinks to reposition in later phases.

const FAIRY_SCENE = "res://scenes/enemies/CorruptedFairy.tscn"

@export var preferred_dist: float = 240.0

var _spiral_angle: float = 0.0
var _hover: float        = 0.0

func _get_pixel_texture(): return PixelArt.make_fairy_queen()

func _on_ready_extra():
	max_hp     = 760.0
	hp         = max_hp
	move_speed = 130.0
	damage     = 13.0
	xp_value   = 450
	body_color = Color(0.90, 0.30, 0.84)
	body_size  = Vector2(56, 56)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	# Flyer: no floor snapping
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	super()

func _boss_ai(delta: float):
	_hover += delta * 2.5
	_kite(delta)

	if action_timer > 0.0:
		return

	match phase:
		1:
			action_timer = 2.0
			aimed_spread(5, 12.0, 250.0)
		2:
			action_timer = 1.8
			if randi() % 2 == 0:
				_spiral_volley()
			else:
				ring(10, 200.0, -1.0, randf() * TAU)
		3:
			action_timer = 1.6
			match randi() % 3:
				0: _spiral_volley()
				1: _blink()
				2: summon(FAIRY_SCENE, 2)

func _kite(_delta: float):
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	var dist := distance_to_player()
	var hover_off := Vector2(0, sin(_hover) * 10.0)
	if dist < preferred_dist - 40.0:
		velocity = (-direction_to_player()) * move_speed + hover_off
	elif dist > preferred_dist + 40.0:
		velocity = direction_to_player() * move_speed + hover_off
	else:
		velocity = direction_to_player().rotated(PI * 0.5) * move_speed * 0.7 + hover_off

func _spiral_volley():
	for i in 10:
		await get_tree().create_timer(0.06).timeout
		if not is_inside_tree() or not alive:
			return
		_spiral_angle += deg_to_rad(28.0)
		shoot(Vector2(cos(_spiral_angle), sin(_spiral_angle)), 230.0)

func _blink():
	if not is_instance_valid(player):
		return
	# Teleport to a point offset from the player, then fan a burst
	var ang := randf() * TAU
	var dest := player.global_position + Vector2(cos(ang), sin(ang)) * preferred_dist
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "modulate:a", 0.1, 0.12)
		t.tween_callback(func(): global_position = dest)
		t.tween_property(sprite, "modulate:a", 1.0, 0.12)
	else:
		global_position = dest
	await get_tree().create_timer(0.28).timeout
	if is_inside_tree() and alive:
		ring(8, 220.0)
