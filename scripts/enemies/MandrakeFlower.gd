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

const PHASE2_THRESHOLD = 0.5   # berserk at half HP (CLAUDE.md)
const PHASE3_THRESHOLD = 0.25

func _get_pixel_texture(): return PixelArt.make_mandrake()

func _on_ready_extra():
	max_hp      = 1200.0
	hp          = max_hp
	move_speed   = 0.0
	damage      = 20.0
	xp_value    = 500
	body_color   = Color(0.8, 0.2, 0.6)
	body_size    = Vector2(80, 80)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	if sprite:
		sprite.scale = Vector2(3.0, 3.0)  # final boss: largest body (~4× a normal monster)
	action_timer = 1.5

func _tick_ai(delta: float):
	# Only spew energy orbs ("子弹") below half HP (CLAUDE.md); none above.
	if hp < max_hp * 0.5:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = 2.5
			_boss_drop()

	action_timer -= delta
	_check_phase_transition()

	if action_timer <= 0.0:
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
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 15)

func _check_phase_transition():
	var ratio = hp / max_hp
	if phase == 1 and ratio <= PHASE2_THRESHOLD:
		_enter_phase(2)
	elif phase == 2 and ratio <= PHASE3_THRESHOLD:
		_enter_phase(3)

func _enter_phase(new_phase: int):
	phase = new_phase
	emit_signal("boss_phase_changed", phase)
	# Flash the visible sprite, then keep an angry red berserk tint.
	var flash_target = sprite if sprite else body_rect
	var berserk_tint = Color(1.5, 0.6, 0.6)
	var t = create_tween()
	t.tween_property(flash_target, "modulate", Color(2.5, 2.5, 2.5), 0.1)
	t.tween_property(flash_target, "modulate", berserk_tint, 0.2)
	match phase:
		2:
			# 狂暴模式 at half HP — spew a retaliatory bullet ring and speed up.
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
	action_timer = 4.0
	if randi() % 2 == 0:
		_summon_minions()
	else:
		_vine_sweep()
	if is_instance_valid(player):
		navigate_to(player.global_position, 0.016)

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
		m.global_position = pos
		get_parent().add_child(m)

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
	action_timer = 3.0
	match randi() % 3:
		0: _start_laser_sweep()
		1: _rapid_petal_storm()
		2:
			_petal_ring(12)
			_summon_minions()

func _start_laser_sweep():
	if not is_instance_valid(player):
		return
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
	var waves = 8
	for i in waves:
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return
		_petal_ring(6 + i)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	hp -= amount
	emit_signal("boss_hp_changed", hp, max_hp)
	body_rect.modulate = Color.RED
	var t = create_tween()
	t.tween_property(body_rect, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_die()
