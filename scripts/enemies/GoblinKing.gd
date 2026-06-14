extends "res://scripts/enemies/BossBase.gd"

# Sublevel 1 boss — 巨型哥布林王. Aggressive bruiser: chases, throws axe spreads,
# charges in phase 2+, and summons goblin minions in phase 3.

const GOBLIN_SCENE = "res://scenes/enemies/Goblin.tscn"
const ARCHER_SCENE = "res://scenes/enemies/GoblinArcher.tscn"

var _charging: bool   = false
var _charge_dir: Vector2 = Vector2.RIGHT
var _casting: bool    = false   # frozen meteor-cast windup

func _get_pixel_texture(): return PixelArt.make_goblin_king()

func _on_ready_extra():
	max_hp     = 900.0
	hp         = max_hp
	move_speed = 60.0
	damage     = 18.0
	xp_value   = 300
	boss_drop_weapon = "kings_greataxe"
	body_color = Color(0.26, 0.55, 0.20)
	body_size  = Vector2(64, 64)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	super()  # scale sprite + init boss bar

func _boss_ai(delta: float):
	if _casting:
		velocity = Vector2.ZERO   # rooted during the 2s meteor cast
		return
	if _charging:
		velocity = _charge_dir * 320.0
		return

	# Always close on the player (so a still player gets body-slammed for contact dmg).
	if is_instance_valid(player):
		navigate_to(player.global_position, delta)

	if action_timer > 0.0:
		return

	# Point-blank OR the player is standing still → strongly favour a melee leap-smash.
	var still := _player_stationary()
	if (distance_to_player() < 95.0 or still) and randf() < (0.8 if still else 0.65):
		action_timer = 2.0
		_leap_smash()
		return

	match phase:
		1:
			action_timer = 2.4
			match randi() % 3:
				0: _meteor_cast(3)                            # cast → fall + lava
				1: aimed_spread(3, 14.0, 240.0)              # axe throw
				2: _summon_corner_archers()                  # call archers to the corners
		2:
			action_timer = 2.6
			match randi() % 4:
				0: _charge()
				1: aimed_spread(5, 12.0, 260.0)
				2: _meteor_cast(6)                           # berserk: bigger meteor cast
				3: _summon_corner_archers()
		3:
			action_timer = 2.8
			match randi() % 6:
				0: _charge()
				1: ring(10, 220.0)
				2: summon(GOBLIN_SCENE, 3)
				3: _meteor_cast(12)                          # ultimate: mass meteors + lava
				4: _leap_smash()                              # jump onto the player, slam
				5: _summon_corner_archers()

# Phased meteor (天降陨石): GoblinKing roots in place for a 2s cast (shadows appear),
# then it's free to move/act while the rocks finish falling 1s later — they explode
# and leave hostile lava pools (3s). cast_guard still only shields ~1/3 of casts.
func _meteor_cast(count: int):
	if _casting:
		return
	_casting = true
	velocity = Vector2.ZERO
	cast_guard(2.5)
	# Casting tell: a bright pulse while channelling.
	if is_instance_valid(sprite):
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1.7, 1.7, 0.7), 0.3)
		tw.tween_property(sprite, "modulate", _tint(), 0.3)
	meteor_storm(count, 300.0, 200.0, true)   # 3s shadow→fall, leaves lava pools
	await get_tree().create_timer(2.0).timeout   # rooted casting window
	_casting = false
	action_timer = 1.0   # brief recovery; free to act before the rocks land

# Summons 2–3 GoblinArchers, one per random room corner.
func _summon_corner_archers():
	var scene = load(ARCHER_SCENE)
	if not scene:
		return
	var corners := _room_corners()
	corners.shuffle()
	var n: int = min(randi_range(2, 3), corners.size())
	for i in n:
		var a = scene.instantiate()
		get_parent().add_child(a)
		a.global_position = clamp_to_room(corners[i])

func _room_corners() -> Array:
	var p = get_parent()
	if p and p.has_method("interior_world_rect"):
		var r: Rect2 = p.interior_world_rect()
		var m := 56.0
		return [
			r.position + Vector2(m, m),
			Vector2(r.end.x - m, r.position.y + m),
			Vector2(r.position.x + m, r.end.y - m),
			r.end - Vector2(m, m),
		]
	return [global_position]

# Leaps directly onto the player and slams the ground (distinct from the dash).
func _leap_smash():
	if not is_instance_valid(player):
		return
	leap_to(player.global_position, 12, 230.0, damage * 1.2)

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
