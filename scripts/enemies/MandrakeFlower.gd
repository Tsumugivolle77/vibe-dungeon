extends EnemyBase

signal boss_hp_changed(hp: float, max_hp: float)
signal boss_phase_changed(phase: int)

const GOBLIN_SCENE = "res://scenes/enemies/Goblin.tscn"
const SLIME_SCENE  = "res://scenes/enemies/Slime.tscn"

var phase: int = 1
var action_timer: float = 0.0
var laser_active: bool  = false
var laser_dir: Vector2  = Vector2.RIGHT
var _drop_timer: float  = 6.0
var boss_drop_weapon: String = "mandrake_rod"   # delivered via the golden reward chest

const PHASE2_THRESHOLD = 0.5   # berserk at half HP (CLAUDE.md)
const PHASE3_THRESHOLD = 0.25

var _contact_cd: float = 0.0

func _get_pixel_texture(): return PixelArt.make_mandrake()

func _is_boss_type() -> bool:
	return true

# Touching the giant flower hurts (boss contact damage).
func _mandrake_contact(delta: float):
	if _contact_cd > 0.0:
		_contact_cd -= delta
		return
	var pl = GameManager.player_ref
	if not is_instance_valid(pl) or not pl.has_method("take_damage"):
		return
	if global_position.distance_to(pl.global_position) <= 82.0:
		pl.take_damage(damage * 0.7)
		_contact_cd = 0.7

func _on_ready_extra():
	max_hp      = 1800.0 * 1.5   # +50% boss HP (CLAUDE batch)
	hp          = max_hp
	max_armor    = float(randi_range(50, 100))   # 护甲条 (50–100)
	armor        = max_armor
	move_speed   = 0.0
	damage      = 20.0
	xp_value    = 500
	body_color   = Color(0.8, 0.2, 0.6)
	body_size    = Vector2(80, 80)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	if sprite:
		sprite.scale = Vector2(2.4, 2.4)  # final boss: largest body (~4× a normal monster)
	action_timer = 1.5
	emit_signal("boss_hp_changed", hp, max_hp)
	emit_signal("boss_armor_changed", armor, max_armor)

func _tick_ai(delta: float):
	_mandrake_contact(delta)
	_tick_armor(delta)   # armor regen + invulnerability timer
	# Only spew energy orbs ("子弹") below half HP (CLAUDE.md); none above.
	if hp < max_hp * 0.5:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = 2.5
			_boss_drop()

	action_timer -= delta * 1.5   # 1.5× attack frequency
	_check_phase_transition()

	if action_timer <= 0.0:
		# Point-blank: favour a close-range poison nova (melee-style retaliation).
		if is_instance_valid(player) and distance_to_player() < 95.0 and randf() < 0.6:
			action_timer = 2.0
			_poison_nova()
		else:
			match phase:
				1: _phase1_action()
				2: _phase2_action()
				3: _phase3_action()

	if laser_active:
		_sweep_laser(delta)

func _boss_drop():
	var sides = [Vector2(-80, 0), Vector2(80, 0), Vector2(0, -60), Vector2(0, 60),
		Vector2(-60, -60), Vector2(60, 60)]
	for s in sides:
		Pickup.spawn(get_parent(), global_position + s, Pickup.Type.AMMO_ORB, 14)
	if randf() < 0.5:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 35)

func _check_phase_transition():
	var ratio = hp / max_hp
	if phase == 1 and ratio <= PHASE2_THRESHOLD:
		_enter_phase(2)
	elif phase == 2 and ratio <= PHASE3_THRESHOLD:
		_enter_phase(3)

func _enter_phase(new_phase: int):
	phase = new_phase
	emit_signal("boss_phase_changed", phase)
	# Flash white, then rest on the baked enraged texture (no lingering red tint).
	var flash_target = sprite if sprite else body_rect
	var t = create_tween()
	t.tween_property(flash_target, "modulate", Color(2.5, 2.5, 2.5), 0.1)
	t.tween_property(flash_target, "modulate", Color.WHITE, 0.2)
	match phase:
		2:
			# 狂暴模式 at half HP — swap to the enraged sprite, retaliate, speed up.
			_swap_to_berserk_sprite()
			move_speed = 40.0
			_petal_ring(16)
		3:
			move_speed = 70.0

func _phase1_action():
	action_timer = 2.5
	match randi() % 3:
		0: _petal_ring(8)
		1: _petal_spiral(12)
		2: _aimed_burst(5)

func _petal_ring(count: int):
	for i in count:
		var angle = (TAU / count) * i
		shoot(Vector2(cos(angle), sin(angle)), 180.0)

func _petal_spiral(count: int):
	for i in count:
		var angle = (TAU / count) * i + (action_timer * 0.5)
		shoot(Vector2(cos(angle), sin(angle)), 200.0)

func _aimed_burst(count: int):
	if not is_instance_valid(player):
		return
	var base_angle = direction_to_player().angle()
	for i in count:
		var spread = deg_to_rad(12.0) * (i - count / 2.0)
		var a = base_angle + spread
		shoot(Vector2(cos(a), sin(a)), 230.0)

func _phase2_action():
	action_timer = 3.6
	match randi() % 3:
		0: _summon_minions()
		1: _vine_sweep()
		2: _poison_nova()
	if is_instance_valid(player):
		navigate_to(player.global_position, 0.016)

# Releases a ring of toxic bolts (毒系子弹).
func _poison_nova():
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		shoot(Vector2(cos(a), sin(a)), 175.0, damage * 0.8, {"kind": "poison"})

func _summon_minions():
	var count = 2 if phase == 2 else 3
	for i in count:
		var offset = Vector2(randf_range(-120, 120), randf_range(-80, 80))
		_spawn_minion(global_position + offset)

func _spawn_minion(pos: Vector2):
	var scene_path = GOBLIN_SCENE if randf() > 0.4 else SLIME_SCENE
	var scene = load(scene_path)
	if scene:
		var m = scene.instantiate()
		# Add to the tree BEFORE positioning, then clamp inside the room — otherwise
		# the room's transform re-offsets it and the minion lands off the map.
		get_parent().add_child(m)
		m.global_position = clamp_to_room(pos)

func _vine_sweep():
	if not is_instance_valid(player):
		return
	var base = direction_to_player().angle()
	for i in 7:
		await get_tree().create_timer(i * 0.12).timeout
		if not is_inside_tree():
			return
		var a = base + deg_to_rad(lerp(-30.0, 30.0, float(i) / 6.0))
		shoot(Vector2(cos(a), sin(a)), 240.0, damage * 1.2)

func _phase3_action():
	action_timer = 2.7
	match randi() % 5:
		0: _start_laser_sweep()
		1: _rapid_petal_storm()
		2: _poison_nova()
		3:
			_petal_ring(12)
			_summon_minions()
		4: _teleport_strike()

# Displacement: the flower sinks into the soil and re-emerges beside the player,
# immediately spitting a poison ring outward.
func _teleport_strike():
	if not is_instance_valid(player):
		return
	velocity = Vector2.ZERO
	var ang := randf() * TAU
	var dest := player.global_position + Vector2(cos(ang), sin(ang)) * 210.0
	var vis: CanvasItem = sprite if sprite else body_rect

	# Reaction window: telegraph where the flower will re-emerge before it sinks.
	var warn := ColorRect.new()
	warn.color = Color(0.80, 0.20, 0.70, 0.0)
	warn.size  = Vector2(72, 72)
	warn.global_position = dest - warn.size * 0.5
	get_parent().add_child(warn)
	var pre := warn.create_tween()
	pre.tween_property(warn, "color:a", 0.55, 0.5)
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		if is_instance_valid(warn): warn.queue_free()
		return

	var t := create_tween()
	t.tween_property(vis, "modulate:a", 0.12, 0.14)
	t.tween_callback(func(): global_position = dest)
	t.tween_property(vis, "modulate:a", 1.0, 0.14)
	await t.finished
	if is_instance_valid(warn):
		warn.queue_free()
	if not is_inside_tree():
		return
	action_timer = maxf(action_timer, 1.4)   # post-teleport reaction window
	for i in 12:
		var a := TAU * float(i) / 12.0
		shoot(Vector2(cos(a), sin(a)), 185.0, damage * 0.8, {"kind": "poison"})

func _start_laser_sweep():
	if not is_instance_valid(player):
		return
	cast_guard(2.3)   # powerful skill: full armor + golden aegis
	laser_active = true
	laser_dir    = direction_to_player()
	await get_tree().create_timer(2.0).timeout
	laser_active = false

func _sweep_laser(delta: float):
	laser_dir = laser_dir.rotated(delta * 1.2)
	if Engine.get_frames_drawn() % 4 == 0:
		shoot(laser_dir, 420.0, damage * 0.4)
		shoot(laser_dir.rotated(PI), 420.0, damage * 0.4)

func _rapid_petal_storm():
	cast_guard(2.0)   # powerful skill: full armor + golden aegis
	var waves = 8
	for i in waves:
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
		_petal_ring(6 + i)

func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	if invuln:
		return   # golden aegis blocks all damage during powerful casts
	var dmg := _absorb_with_armor(amount)
	if dmg <= 0.0:
		return   # fully soaked by armor
	hp -= dmg
	emit_signal("boss_hp_changed", hp, max_hp)
	var flash_target: CanvasItem = sprite if sprite else body_rect
	flash_target.modulate = Color(1.8, 0.35, 0.35)
	var t = create_tween()
	t.tween_property(flash_target, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_die()

func _on_die_extra():
	pass   # the 曼陀罗魔杖 is delivered via the golden reward chest (Room)
