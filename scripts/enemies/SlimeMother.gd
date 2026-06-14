extends "res://scripts/enemies/BossBase.gd"

# Sublevel 2 boss — 史莱姆之母. Slow-moving; lobs expanding bullet rings and
# spawns slime minions. Rings get denser with each phase.

const SLIME_SCENE = "res://scenes/enemies/Slime.tscn"
const SELF_SCENE  = "res://scenes/enemies/SlimeMother.tscn"

# A mini is one of the two halves produced when the mother splits at half HP. Minis
# are 60% size, have half the pre-split HP, deal 0.7× damage, and never re-split.
var is_mini: bool   = false
var _has_split: bool = false

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
	super()   # ×1.5 HP, armor, sprite scale
	if is_mini:
		max_hp *= 0.5
		hp      = max_hp
		damage *= 0.7
		_has_split = true        # minis don't split again
		scale   = Vector2(0.6, 0.6)
		emit_signal("boss_hp_changed", hp, max_hp)

# Split at half HP (phase 2 entry): shrink to a 60% half-HP mother and spawn a twin.
func _on_phase(p: int):
	if p == 2 and not is_mini and not _has_split:
		_do_split()

func _do_split():
	_has_split = true
	max_hp *= 0.5
	hp      = minf(hp, max_hp)
	damage *= 0.7
	scale   = Vector2(0.6, 0.6)
	emit_signal("boss_hp_changed", hp, max_hp)
	var scene = load(SELF_SCENE)
	if scene:
		var twin = scene.instantiate()
		twin.is_mini = true
		twin.add_to_group("slime_twin")
		get_parent().add_child(twin)
		twin.global_position = clamp_to_room(
			global_position + Vector2(randf_range(-90, 90), randf_range(-60, 60)))

# When the tracked mother dies the room clears, so clean up any surviving twin.
func _on_die_extra():
	super._on_die_extra()
	for t in get_tree().get_nodes_in_group("slime_twin"):
		if is_instance_valid(t) and t != self and t.has_method("_die"):
			t._die()

func _boss_ai(delta: float):
	var still := _player_stationary()
	# Drift toward the player; if they're standing still, close all the way in to
	# body-slam them for contact damage instead of stopping at range.
	var stop_dist := 40.0 if still else 120.0
	if is_instance_valid(player) and distance_to_player() > stop_dist:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO

	if action_timer > 0.0:
		return

	# Point-blank OR the player is standing still → favour a melee leap-slam.
	if (distance_to_player() < 95.0 or still) and randf() < (0.7 if still else 0.6):
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
