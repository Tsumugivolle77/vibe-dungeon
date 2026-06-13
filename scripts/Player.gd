extends CharacterBody2D

signal health_changed(hp: int, max_hp: int)
signal shield_changed(current: int, maximum: int)
signal weapon_changed(weapon: Dictionary)
signal energy_changed(current: int, maximum: int)
signal skill_activated(duration: float)
signal skill_cooldown(remaining: float, total: float)
signal died
signal weapon_dropped(weapon_id: String, pos: Vector2)

const SPEED            = 180.0
const SKILL_DURATION   = 10.0
const SKILL_COOLDOWN   = 30.0
const SWITCH_DELAY     = 0.1
const IFRAMES_DURATION = 0.5
const MAX_WEAPONS      = 2
const INTERACT_RANGE   = 60.0
const MAX_ENERGY       = 200

var max_hp: int = 100
var hp: int     = 100
var alive: bool = true
var invincible: bool = false

# Shield: absorbs damage before HP; regenerates over time (1 per 0.1s = 10/s).
const MAX_SHIELD            = 15.0
const SHIELD_REGEN          = 5.0   # per second
const SHIELD_RECHARGE_DELAY = 1.2    # seconds after a hit before regen resumes
var shield: float           = MAX_SHIELD
var _shield_delay: float    = 0.0

var energy: int = MAX_ENERGY

var weapon_ids: Array     = ["pistol"]
var weapon_idx: int       = 0
var weapon: Dictionary    = {}
var switch_timer: float   = 0.0
var fire_timer: float     = 0.0
var windup_timer: float   = 0.0
var is_windup_ready: bool = false

var skill_active: bool = false
var skill_timer: float = 0.0
var skill_cd: float    = 0.0

var is_melee_attacking: bool = false
var melee_timer: float       = 0.0

# Emergency slash — activated when energy too low to fire any weapon
const PUNCH_DAMAGE   = 12.0
const PUNCH_RANGE    = 78.0
const PUNCH_ARC      = 100.0   # degrees
const PUNCH_COOLDOWN = 0.4
var _punch_cd: float = 0.0

@onready var weapon_pivot: Node2D     = $WeaponPivot
@onready var weapon_visual: ColorRect = $WeaponPivot/WeaponVisual
@onready var melee_hitbox: Area2D    = $WeaponPivot/MeleeHitbox
@onready var camera: Camera2D        = $Camera2D

var bullet_scene: PackedScene = preload("res://scenes/bullets/Bullet.tscn")
var _anim_sprite: AnimatedSprite2D = null
var _weapon_sprite: Sprite2D = null

func _ready():
	add_to_group("player")
	# Ensure the bullet-receiving hitbox is reliably in its group (a scene-set group
	# can be missed) so enemy bullets register hits on the player body.
	$PlayerHitbox.add_to_group("player_hitbox")
	melee_hitbox.monitoring = false
	GameManager.player_ref = self

	# Held-weapon sprite replaces the plain WeaponVisual rectangle
	weapon_visual.visible = false
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.position = Vector2(22, 0)
	_weapon_sprite.z_index = 2
	weapon_pivot.add_child(_weapon_sprite)

	_equip(weapon_ids[0])

	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.sprite_frames = PixelArt.make_loli_frames()
	_anim_sprite.play("idle")
	_anim_sprite.z_index = 1
	add_child(_anim_sprite)
	$Body.visible = false
	$Head.visible = false

func _physics_process(delta: float):
	if not alive:
		return
	_move()
	_aim()
	_handle_switch(delta)
	_handle_fire(delta)
	_handle_skill(delta)
	_tick_timers(delta)
	_handle_interact()

func _move():
	var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if _anim_sprite:
		if dir.length() > 0.1:
			_anim_sprite.play("walk")
			if dir.x != 0:
				_anim_sprite.flip_h = dir.x < 0
		else:
			_anim_sprite.play("idle")

func _aim():
	var aim = (get_global_mouse_position() - global_position)
	weapon_pivot.rotation = aim.angle()
	# Flip the held weapon vertically when aiming left so it never appears upside-down
	if _weapon_sprite:
		_weapon_sprite.flip_v = abs(weapon_pivot.rotation) > PI * 0.5

func _handle_switch(delta: float):
	if switch_timer > 0.0:
		switch_timer -= delta
		return
	if Input.is_action_just_released("weapon_next"):
		_cycle(1)
	elif Input.is_action_just_released("weapon_prev"):
		_cycle(-1)

func _cycle(dir: int):
	if weapon_ids.size() <= 1:
		return
	weapon_idx = posmod(weapon_idx + dir, weapon_ids.size())
	_equip(weapon_ids[weapon_idx])
	switch_timer = SWITCH_DELAY

func _equip(id: String):
	weapon = WeaponDatabase.get_weapon(id)
	fire_timer      = 0.0
	windup_timer    = 0.0
	is_windup_ready = false
	is_melee_attacking = false
	melee_hitbox.monitoring = false
	weapon_visual.color = weapon.get("color", Color.WHITE)
	if _weapon_sprite:
		_weapon_sprite.texture = PixelArt.make_weapon_icon(id)
	emit_signal("weapon_changed", weapon)
	emit_signal("energy_changed", energy, MAX_ENERGY)

func _handle_fire(delta: float):
	if fire_timer > 0.0:
		fire_timer -= delta
		return
	if is_melee_attacking:
		return
	if not Input.is_action_pressed("fire"):
		if weapon.get("props", {}).get("windup"):
			windup_timer    = 0.0
			is_windup_ready = false
		return

	var cost: int = weapon.get("energy_cost", 0)
	# When weapon costs energy and player is dry, offer the emergency punch instead
	if cost > 0 and energy < cost:
		if Input.is_action_just_pressed("fire") and _punch_cd <= 0.0:
			_emergency_punch()
		return

	if weapon.get("type") == "melee":
		_melee_attack()
	else:
		_fire_ranged(delta)

func _melee_attack():
	var cost: int = weapon.get("energy_cost", 0)
	if energy < cost:
		return
	_spend_energy(cost)
	is_melee_attacking = true
	melee_timer = 0.25
	fire_timer  = 1.0 / weapon.fire_rate
	_melee_sector_hit()
	_melee_slash_visual()

# True fan-shaped (扇形) hit: everything inside the weapon's range AND within the
# arc half-angle of the aim direction is struck at once — reliable, no sweep gaps.
func _melee_sector_hit():
	var arc: float  = deg_to_rad(weapon.get("arc", 90.0))
	var rng: float  = weapon.get("range", 80.0)
	var half: float = arc * 0.5
	var aim: float  = weapon_pivot.rotation
	var dmg: float  = weapon.damage * (2.0 if skill_active else 1.0)
	var kb: float   = weapon.get("props", {}).get("knockback", 150.0)

	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() > rng + 16.0:
			continue
		if absf(angle_difference(aim, to_e.angle())) > half:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg, to_e.normalized() * kb)

	for c in get_tree().get_nodes_in_group("crate"):
		if not is_instance_valid(c):
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() > rng + 16.0 or absf(angle_difference(aim, to_c.angle())) > half:
			continue
		if c.has_method("take_damage"):
			c.take_damage(dmg)

	if weapon.get("can_cancel_bullets", false):
		for b in get_tree().get_nodes_in_group("enemy_bullet"):
			if not is_instance_valid(b):
				continue
			var to_b: Vector2 = b.global_position - global_position
			if to_b.length() <= rng + 8.0 and absf(angle_difference(aim, to_b.angle())) <= half:
				b.queue_free()

# A crescent "blade sweep" that fills the arc, with a bright cutting edge, a small
# swing motion and a quick fade — reads as a slash (砍击) rather than a thin line.
func _melee_slash_visual():
	var arc: float  = deg_to_rad(weapon.get("arc", 90.0))
	var rng: float  = weapon.get("range", 80.0)
	var half: float = arc * 0.5
	var col: Color  = weapon.get("color", Color.WHITE)
	var r_in: float = rng * 0.5
	var steps := 16

	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in steps + 1:                                   # outer arc, +half → -half
		var a: float = lerp(half, -half, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * rng)
	for i in steps + 1:                                   # inner arc back, -half → +half
		var a: float = lerp(-half, half, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * r_in)
	poly.polygon = pts
	poly.color   = Color(col.r, col.g, col.b, 0.5)
	weapon_pivot.add_child(poly)

	var edge := Line2D.new()                              # bright cutting edge
	edge.width = 5.0
	edge.default_color = Color(1, 1, 1, 0.95)
	edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	edge.end_cap_mode   = Line2D.LINE_CAP_ROUND
	for i in steps + 1:
		var a: float = lerp(-half, half, float(i) / steps)
		edge.add_point(Vector2(cos(a), sin(a)) * rng)
	weapon_pivot.add_child(edge)

	for node: CanvasItem in [poly, edge]:
		node.rotation = -arc * 0.1
		node.scale    = Vector2(0.92, 0.92)
		var tw: Tween = node.create_tween()
		tw.tween_property(node, "rotation", arc * 0.1, 0.16)
		tw.parallel().tween_property(node, "scale", Vector2(1.05, 1.05), 0.16)
		tw.parallel().tween_property(node, "modulate:a", 0.0, 0.22)
		tw.tween_callback(node.queue_free)

func _fire_ranged(delta: float):
	var props: Dictionary = weapon.get("props", {})
	if props.get("windup"):
		windup_timer += delta
		if not is_windup_ready and windup_timer >= props.get("windup_time", 1.0):
			is_windup_ready = true
		if not is_windup_ready:
			return

	var cost: int = weapon.get("energy_cost", 0)
	if energy < cost:
		return

	var dmg: float = weapon.get("damage", 10.0) * (2.0 if skill_active else 1.0)

	# Laser weapons fire an instant hitscan ray instead of a projectile.
	if props.get("laser"):
		_fire_laser(props, dmg)
		_spend_energy(cost)
		fire_timer = 1.0 / weapon.fire_rate
		return

	var base_count: int = weapon.get("bullet_count", 1)
	var spread: float = deg_to_rad(weapon.get("spread", 0.0))
	var aim_ang: float = weapon_pivot.rotation
	var spd: float    = weapon.get("bullet_speed", 400.0)
	var is_ring: bool = props.get("ring", false)

	# Skill: fire double the bullets, fanned out with spacing between them.
	var count := base_count
	if skill_active and not is_ring:
		count = base_count * 2
		spread = max(spread, deg_to_rad(16.0))
	elif skill_active and is_ring:
		count = base_count * 2   # denser ring

	for i in count:
		var angle = aim_ang
		if is_ring:
			angle = aim_ang + TAU * float(i) / float(count)   # even 360° ring
		elif count > 1:
			angle += lerp(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		elif spread > 0.0:
			angle += randf_range(-spread * 0.5, spread * 0.5)
		var b: Node = bullet_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(cos(angle), sin(angle)) * 28.0
		b.direction    = Vector2(cos(angle), sin(angle))
		b.speed        = spd
		b.damage       = dmg
		b.weapon_props = props.duplicate()
		b.weapon_id    = weapon.get("id", "pistol")

	_spend_energy(cost)
	fire_timer = 1.0 / weapon.fire_rate

# Hitscan laser: damages every enemy along a ray to the first wall, draws a beam.
func _fire_laser(props: Dictionary, dmg: float):
	var aim: float   = weapon_pivot.rotation
	var dir: Vector2 = Vector2(cos(aim), sin(aim))
	var origin: Vector2 = global_position + dir * 26.0
	var max_len := 720.0
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(origin, origin + dir * max_len, 1)
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	var endp: Vector2 = hit.position if hit else origin + dir * max_len
	var beam_len := origin.distance_to(endp)

	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - origin
		var proj := to_e.dot(dir)
		if proj < 0.0 or proj > beam_len:
			continue
		if (to_e - dir * proj).length() <= 16.0 and e.has_method("take_damage"):
			e.take_damage(dmg, dir * 50.0, props)

	_laser_beam_visual(origin, endp, props.get("element", ""))

func _laser_beam_visual(from: Vector2, to: Vector2, elem: String):
	var col := Color(0.2, 0.95, 1.0)
	match elem:
		"plasma": col = Color(0.6, 0.3, 1.0)
		"fire":   col = Color(1.0, 0.4, 0.1)
	var beam := Line2D.new()
	beam.add_point(from)
	beam.add_point(to)
	beam.width = 6.0
	beam.default_color = col
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode   = Line2D.LINE_CAP_ROUND
	get_parent().add_child(beam)
	var core := Line2D.new()
	core.add_point(from)
	core.add_point(to)
	core.width = 2.0
	core.default_color = Color(1, 1, 1, 0.95)
	get_parent().add_child(core)
	for n: Line2D in [beam, core]:
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.14)
		tw.tween_callback(n.queue_free)

func _spend_energy(amount: int):
	energy = max(0, energy - amount)
	emit_signal("energy_changed", energy, MAX_ENERGY)

func restore_energy(amount: int):
	energy = min(MAX_ENERGY, energy + amount)
	emit_signal("energy_changed", energy, MAX_ENERGY)

func _handle_skill(delta: float):
	if skill_cd > 0.0:
		skill_cd -= delta
		emit_signal("skill_cooldown", max(skill_cd, 0.0), SKILL_COOLDOWN)
	if skill_active:
		skill_timer -= delta
		if skill_timer <= 0.0:
			skill_active = false
	if Input.is_action_just_pressed("use_skill") and skill_cd <= 0.0 and not skill_active:
		skill_active = true
		skill_timer  = SKILL_DURATION
		skill_cd     = SKILL_COOLDOWN
		emit_signal("skill_activated", SKILL_DURATION)

func _handle_interact():
	if not Input.is_action_just_pressed("ui_accept"):
		return
	_try_pickup_weapon()
	_try_collect_manual_pickup()
	_try_open_chest()
	_try_shop_interact()

func _try_pickup_weapon():
	var pickups = get_tree().get_nodes_in_group("weapon_pickup")
	for p in pickups:
		if not is_instance_valid(p):
			continue
		if global_position.distance_to(p.global_position) > INTERACT_RANGE:
			continue
		var wid: String = p.get_meta("weapon_id", "")
		if wid.is_empty():
			continue
		_do_pick_up_weapon(wid)
		p.queue_free()
		break

func _try_collect_manual_pickup():
	var pickups = get_tree().get_nodes_in_group("pickup")
	for p in pickups:
		if not is_instance_valid(p):
			continue
		if global_position.distance_to(p.global_position) > INTERACT_RANGE:
			continue
		if p.has_method("try_collect"):
			p.try_collect(self)
		break

func _try_open_chest():
	var chests = get_tree().get_nodes_in_group("interactable")
	for c in chests:
		if not is_instance_valid(c):
			continue
		if global_position.distance_to(c.global_position) > INTERACT_RANGE:
			continue
		if c.has_method("interact"):
			c.interact(self)
		break

func _try_shop_interact():
	var items = get_tree().get_nodes_in_group("shop_item")
	for item in items:
		if not is_instance_valid(item):
			continue
		if global_position.distance_to(item.global_position) > INTERACT_RANGE:
			continue
		if item.has_method("buy"):
			item.buy(self)
		break

func _do_pick_up_weapon(id: String):
	if weapon_ids.has(id):
		return
	if weapon_ids.size() < MAX_WEAPONS:
		weapon_ids.append(id)
		weapon_idx = weapon_ids.size() - 1
		_equip(id)
	else:
		var dropped_id = weapon_ids[weapon_idx]
		emit_signal("weapon_dropped", dropped_id, global_position)
		weapon_ids[weapon_idx] = id
		_equip(id)

func pick_up_weapon(id: String):
	_do_pick_up_weapon(id)

func _emergency_punch():
	_punch_cd = PUNCH_COOLDOWN
	var aim: float  = weapon_pivot.rotation
	var half: float = deg_to_rad(PUNCH_ARC) * 0.5

	# Wide energy-blade slash in the aim cone (a true 扇形 sweep).
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() > PUNCH_RANGE + 14.0:
			continue
		if absf(angle_difference(aim, to_e.angle())) > half:
			continue
		if e.has_method("take_damage"):
			e.take_damage(PUNCH_DAMAGE, to_e.normalized() * 120.0)

	_punch_slash_visual(aim, half)

func _punch_slash_visual(aim: float, half: float):
	var r_in := PUNCH_RANGE * 0.45
	var steps := 16
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a: float = lerp(half, -half, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * PUNCH_RANGE)
	for i in steps + 1:
		var a: float = lerp(-half, half, float(i) / steps)
		pts.append(Vector2(cos(a), sin(a)) * r_in)
	poly.polygon = pts
	poly.color   = Color(0.55, 0.85, 1.0, 0.5)
	poly.rotation = aim
	weapon_pivot.add_child(poly)
	var edge := Line2D.new()
	edge.width = 5.0
	edge.default_color = Color(0.9, 0.98, 1.0, 0.95)
	edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	edge.end_cap_mode   = Line2D.LINE_CAP_ROUND
	for i in steps + 1:
		var a: float = lerp(-half, half, float(i) / steps)
		edge.add_point(Vector2(cos(a), sin(a)) * PUNCH_RANGE)
	edge.rotation = aim
	weapon_pivot.add_child(edge)
	for node: CanvasItem in [poly, edge]:
		node.rotation -= deg_to_rad(PUNCH_ARC) * 0.12
		var tw: Tween = node.create_tween()
		tw.tween_property(node, "rotation", aim + deg_to_rad(PUNCH_ARC) * 0.12, 0.16)
		tw.parallel().tween_property(node, "modulate:a", 0.0, 0.24)
		tw.tween_callback(node.queue_free)

func _tick_timers(delta: float):
	if _punch_cd > 0.0:
		_punch_cd -= delta
	if melee_timer > 0.0:
		melee_timer -= delta
		if melee_timer <= 0.0:
			is_melee_attacking = false
	# Shield regen after a short delay since the last hit.
	if _shield_delay > 0.0:
		_shield_delay -= delta
	elif shield < MAX_SHIELD:
		shield = min(MAX_SHIELD, shield + SHIELD_REGEN * delta)
		emit_signal("shield_changed", int(shield), int(MAX_SHIELD))

func take_damage(amount: float):
	if invincible or not alive:
		return
	_shield_delay = SHIELD_RECHARGE_DELAY
	var dmg := float(amount)
	# Shield soaks damage first; only the overflow reaches HP.
	if shield > 0.0:
		var absorbed := minf(shield, dmg)
		shield -= absorbed
		dmg    -= absorbed
		emit_signal("shield_changed", int(shield), int(MAX_SHIELD))
	if dmg > 0.0:
		hp = max(0, hp - int(ceil(dmg)))
		emit_signal("health_changed", hp, max_hp)
	invincible = true
	_flash_invincible()
	if hp <= 0:
		_die()

func _flash_invincible():
	var tween = create_tween().set_loops(int(IFRAMES_DURATION / 0.1))
	tween.tween_property(self, "modulate:a", 0.2, 0.05)
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	await get_tree().create_timer(IFRAMES_DURATION).timeout
	modulate.a = 1.0
	invincible = false

func heal(amount: int):
	hp = min(max_hp, hp + amount)
	emit_signal("health_changed", hp, max_hp)

func _die():
	alive = false
	$CollisionShape2D.set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): emit_signal("died"))
	tween.tween_callback(func(): GameManager.on_player_died())
