extends CharacterBody2D

signal health_changed(hp: int, max_hp: int)
signal weapon_changed(weapon: Dictionary)
signal ammo_changed(current: int, maximum: int)
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

var max_hp: int = 100
var hp: int     = 100
var alive: bool = true
var invincible: bool = false

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

@onready var weapon_pivot: Node2D  = $WeaponPivot
@onready var weapon_visual: ColorRect = $WeaponPivot/WeaponVisual
@onready var melee_hitbox: Area2D  = $WeaponPivot/MeleeHitbox
@onready var camera: Camera2D      = $Camera2D

var bullet_scene: PackedScene = preload("res://scenes/bullets/Bullet.tscn")
var _pixel_sprite: Sprite2D = null

func _ready():
	add_to_group("player")
	melee_hitbox.monitoring = false
	melee_hitbox.area_entered.connect(_on_melee_area)
	melee_hitbox.body_entered.connect(_on_melee_body)
	GameManager.player_ref = self
	_equip(weapon_ids[0])

	# Pixel art sprite
	_pixel_sprite = PixelArt.sprite_from(PixelArt.make_knight())
	_pixel_sprite.z_index = 1
	add_child(_pixel_sprite)
	$Body.visible   = false
	$Head.visible   = false

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
	# Flip sprite
	if _pixel_sprite and dir.x != 0:
		_pixel_sprite.flip_h = dir.x < 0

func _aim():
	var aim = (get_global_mouse_position() - global_position)
	weapon_pivot.rotation = aim.angle()

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
	fire_timer     = 0.0
	windup_timer   = 0.0
	is_windup_ready = false
	is_melee_attacking = false
	melee_hitbox.monitoring = false
	weapon_visual.color = weapon.get("color", Color.WHITE)
	emit_signal("weapon_changed", weapon)
	if weapon.get("type") == "ranged":
		emit_signal("ammo_changed", weapon.ammo, weapon.ammo_max)

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
	if weapon.get("type") == "melee":
		_melee_attack()
	else:
		_fire_ranged(delta)

func _melee_attack():
	is_melee_attacking = true
	melee_hitbox.monitoring = true
	melee_timer = 0.3
	fire_timer  = 1.0 / weapon.fire_rate

func _fire_ranged(delta: float):
	var props: Dictionary = weapon.get("props", {})
	if props.get("windup"):
		windup_timer += delta
		if not is_windup_ready and windup_timer >= props.get("windup_time", 1.0):
			is_windup_ready = true
		if not is_windup_ready:
			return

	var ammo_val: int = weapon.get("ammo", 0)
	if ammo_val <= 0:
		return

	var count: int   = weapon.get("bullet_count", 1)
	var spread: float = deg_to_rad(weapon.get("spread", 0.0))
	var aim_ang: float = weapon_pivot.rotation
	var spd: float   = weapon.get("bullet_speed", 400.0)
	var dmg: float   = weapon.get("damage", 10.0) * (2.0 if skill_active else 1.0)

	for i in count:
		var angle = aim_ang
		if count > 1:
			angle += lerp(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		elif spread > 0.0:
			angle += randf_range(-spread * 0.5, spread * 0.5)
		var b: Node = bullet_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(cos(aim_ang), sin(aim_ang)) * 32.0
		b.direction = Vector2(cos(angle), sin(angle))
		b.speed     = spd
		b.damage    = dmg
		b.weapon_props = props.duplicate()

	weapon.ammo -= 1
	WeaponDatabase.weapons[weapon.get("id", "")].ammo = weapon.ammo
	fire_timer = 1.0 / weapon.fire_rate
	emit_signal("ammo_changed", weapon.ammo, weapon.ammo_max)

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
		WeaponDatabase.restore_ammo(id)
		return
	if weapon_ids.size() < MAX_WEAPONS:
		weapon_ids.append(id)
		WeaponDatabase.restore_ammo(id)
		# Switch to new weapon
		weapon_idx = weapon_ids.size() - 1
		_equip(id)
	else:
		# Drop current, pick up new
		var dropped_id = weapon_ids[weapon_idx]
		emit_signal("weapon_dropped", dropped_id, global_position)
		weapon_ids[weapon_idx] = id
		WeaponDatabase.restore_ammo(id)
		_equip(id)

func pick_up_weapon(id: String):
	_do_pick_up_weapon(id)

func _tick_timers(delta: float):
	if melee_timer > 0.0:
		melee_timer -= delta
		if melee_timer <= 0.0:
			is_melee_attacking = false
			melee_hitbox.monitoring = false

func _on_melee_area(area: Area2D):
	if area.is_in_group("enemy_bullet") and weapon.get("can_cancel_bullets", false):
		area.queue_free()
		return
	if area.is_in_group("enemy_hitbox"):
		var e = area.get_parent()
		if e.has_method("take_damage"):
			var dmg: float = weapon.damage * (2.0 if skill_active else 1.0)
			var kb: float  = weapon.get("props", {}).get("knockback", 150.0)
			e.take_damage(dmg, (e.global_position - global_position).normalized() * kb)

func _on_melee_body(body: Node2D):
	if body.is_in_group("crate") and body.has_method("take_damage"):
		body.take_damage(weapon.damage * (2.0 if skill_active else 1.0))
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(weapon.damage * (2.0 if skill_active else 1.0),
			(body.global_position - global_position).normalized() * 150.0)

func take_damage(amount: float):
	if invincible or not alive:
		return
	hp = max(0, hp - int(amount))
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
