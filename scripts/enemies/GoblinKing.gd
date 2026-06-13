extends "res://scripts/enemies/BossBase.gd"

# Sublevel 1 boss — 巨型哥布林王. Aggressive bruiser: chases, throws axe spreads,
# charges in phase 2+, and summons goblin minions in phase 3.

const GOBLIN_SCENE = "res://scenes/enemies/Goblin.tscn"

var _charging: bool   = false
var _charge_dir: Vector2 = Vector2.RIGHT

func _get_pixel_texture(): return PixelArt.make_goblin_king()

func _on_ready_extra():
	max_hp     = 520.0
	hp         = max_hp
	move_speed = 60.0
	damage     = 18.0
	xp_value   = 300
	body_color = Color(0.26, 0.55, 0.20)
	body_size  = Vector2(64, 64)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	super()  # scale sprite + init boss bar

func _boss_ai(delta: float):
	if _charging:
		velocity = _charge_dir * 320.0
		return

	if is_instance_valid(player):
		navigate_to(player.global_position, delta)

	if action_timer > 0.0:
		return

	match phase:
		1:
			action_timer = 2.2
			aimed_spread(3, 14.0, 240.0)          # axe throw
		2:
			action_timer = 2.6
			if randi() % 2 == 0:
				_charge()
			else:
				aimed_spread(5, 12.0, 260.0)
		3:
			action_timer = 2.4
			match randi() % 3:
				0: _charge()
				1: ring(10, 220.0)
				2: summon(GOBLIN_SCENE, 3)

func _on_phase(p: int):
	if p == 2:
		move_speed = 80.0
	elif p == 3:
		move_speed = 100.0

func _charge():
	if not is_instance_valid(player):
		return
	_charge_dir = direction_to_player()
	_charging   = true
	await get_tree().create_timer(0.7).timeout
	_charging = false
