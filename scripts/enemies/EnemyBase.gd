extends CharacterBody2D
class_name EnemyBase

signal died(position: Vector2, xp: int)

@export var max_hp: float      = 50.0
@export var move_speed: float  = 80.0
@export var damage: float      = 10.0
@export var xp_value: int      = 10
@export var gold_drop_min: int = 1
@export var gold_drop_max: int = 4
@export var body_color: Color  = Color(0.6, 0.8, 0.3)
@export var body_size: Vector2 = Vector2(32, 32)

var is_boss_mode: bool = false
var boss_scale: float  = 1.8
var is_elite: bool     = false   # only elite monsters drop energy orbs ("子弹")

var hp: float     = 0.0
var alive: bool   = true
var knockback_vel: Vector2 = Vector2.ZERO

# Floating health bar (created lazily on first hit)
const HP_BAR_W = 32.0
const HP_BAR_H = 4.0
var _hp_bar_bg: ColorRect   = null
var _hp_bar_fill: ColorRect = null

var slow_factor: float = 1.0
var slow_timer:  float = 0.0
var dot_damage:  float = 0.0
var dot_timer:   float = 0.0

var player: Node2D = null
var sprite: Sprite2D = null  # pixel-art overlay (set when _get_pixel_texture returns a texture)

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hitbox: Area2D               = $Hitbox
@onready var body_rect: ColorRect         = $Body

var enemy_bullet_scene: PackedScene = preload("res://scenes/bullets/EnemyBullet.tscn")

func _ready():
	hp = max_hp
	add_to_group("enemy")
	hitbox.add_to_group("enemy_hitbox")
	body_rect.color   = body_color
	body_rect.size    = body_size
	body_rect.position = -body_size * 0.5

	# Pixel sprite overlay (sits above the ColorRect fallback)
	var tex = _get_pixel_texture()
	if tex:
		sprite = PixelArt.sprite_from(tex)
		sprite.z_index = 1
		add_child(sprite)
		body_rect.visible = false  # hide plain rect when we have art

	if is_boss_mode:
		_apply_boss_mode()
	_find_player()
	_on_ready_extra()

func _get_pixel_texture() -> ImageTexture:
	return null  # override in subclass

func _apply_boss_mode():
	max_hp  *= 3.0
	hp       = max_hp
	damage  *= 1.5
	scale    = Vector2(boss_scale, boss_scale)
	body_rect.color = body_color.darkened(0.35)

func _find_player():
	var arr = get_tree().get_nodes_in_group("player")
	player  = arr[0] if arr.size() > 0 else null

func _on_ready_extra():
	pass

func _physics_process(delta: float):
	if not alive:
		return
	if not is_instance_valid(player):
		_find_player()
	_tick_status(delta)
	_tick_ai(delta)
	if knockback_vel.length() > 1.0:
		knockback_vel = knockback_vel.lerp(Vector2.ZERO, delta * 8.0)
		velocity = knockback_vel
	move_and_slide()

func _tick_status(delta: float):
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	if dot_timer > 0.0:
		dot_timer -= delta
		hp -= dot_damage * delta
		if hp <= 0.0:
			_die()

func _tick_ai(_delta: float):
	pass

func navigate_to(target_pos: Vector2, _delta: float):
	if not is_instance_valid(nav_agent):
		return
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		return
	var next = nav_agent.get_next_path_position()
	var dir  = (next - global_position).normalized()
	velocity = dir * move_speed * slow_factor
	if knockback_vel.length() > 10.0:
		velocity = knockback_vel

func distance_to_player() -> float:
	return global_position.distance_to(player.global_position) if is_instance_valid(player) else INF

func direction_to_player() -> Vector2:
	return (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.ZERO

func shoot(dir: Vector2, spd: float = 200.0, dmg: float = -1.0, props: Dictionary = {}):
	var b: Node = enemy_bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position
	b.direction       = dir.normalized()
	b.speed           = spd
	b.damage          = dmg if dmg >= 0 else damage
	b.is_boss_bullet  = is_boss_mode
	if props.has("kind"):     b.kind = props["kind"]
	if props.has("homing"):   b.homing_strength = props["homing"]
	if props.has("lifetime"): b.lifetime = props["lifetime"]

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	hp -= amount
	knockback_vel = knockback
	_flash_hit()
	_update_hp_bar()
	if hp <= 0.0:
		_die()

# Brief red flash on the visible sprite (falls back to the plain rect).
func _flash_hit():
	var target: CanvasItem = sprite if sprite else body_rect
	if not is_instance_valid(target):
		return
	target.modulate = Color(1.8, 0.35, 0.35)
	var t = create_tween()
	t.tween_property(target, "modulate", Color.WHITE, 0.18)

func _ensure_hp_bar():
	if _hp_bar_bg != null:
		return
	var y := -(body_size.y * 0.5 + 10.0)
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color    = Color(0, 0, 0, 0.55)
	_hp_bar_bg.size     = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_bar_bg.position = Vector2(-HP_BAR_W * 0.5, y)
	_hp_bar_bg.z_index  = 5
	add_child(_hp_bar_bg)
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color    = Color(0.3, 0.9, 0.3)
	_hp_bar_fill.size     = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_bar_fill.position = Vector2(-HP_BAR_W * 0.5, y)
	_hp_bar_fill.z_index  = 6
	add_child(_hp_bar_fill)

func _update_hp_bar():
	_ensure_hp_bar()
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar_fill.size  = Vector2(HP_BAR_W * ratio, HP_BAR_H)
	_hp_bar_fill.color = Color(0.95, 0.25, 0.2).lerp(Color(0.3, 0.9, 0.3), ratio)
	_hp_bar_bg.visible   = true
	_hp_bar_fill.visible = true

func apply_dot(dmg_per_sec: float, duration: float):
	dot_damage = dmg_per_sec
	dot_timer  = duration

func apply_slow(factor: float, duration: float):
	slow_factor = factor
	slow_timer  = duration

func _die():
	if not alive:
		return
	alive = false
	emit_signal("died", global_position, xp_value)
	GameManager.add_score(xp_value * 10)

	# Drop gold (reduced) — not every kill drops, and amounts are small.
	var gold_amount = int(randi_range(gold_drop_min, gold_drop_max) * 0.5)
	if is_boss_mode:
		gold_amount *= 2
	if gold_amount > 0:
		for i in min(gold_amount, 3):
			var offset = Vector2(randf_range(-18, 18), randf_range(-18, 18))
			Pickup.spawn(get_parent(), global_position + offset, Pickup.Type.GOLD, ceil(float(gold_amount) / 3.0))

	# Health orbs can drop from anyone (rarer, smaller).
	if randf() < 0.16:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 18)
	# Energy orbs ("子弹") drop ONLY from elite monsters (and boss-mode variants),
	# but generously so the player can afford their powerful weapons.
	if (is_elite or is_boss_mode) and randf() < 0.9:
		for i in 2:
			Pickup.spawn(get_parent(), global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14)),
				Pickup.Type.AMMO_ORB, 14)

	$CollisionShape2D.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
	_on_die_extra()

# Spawns an [Enter]-collectable weapon pickup at this enemy's position.
func spawn_weapon_pickup(wid: String):
	var area = Area2D.new()
	area.add_to_group("weapon_pickup")
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = global_position
	area.set_meta("weapon_id", wid)
	area.add_child(PixelArt.sprite_from(PixelArt.make_weapon_icon(wid)))
	var lbl = Label.new()
	lbl.text = "★ " + WeaponDatabase.get_weapon(wid).get("name", "?")
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.position = Vector2(-30, -26)
	area.add_child(lbl)
	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 9)
	hint.position = Vector2(-14, 18)
	area.add_child(hint)
	var col = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 20.0
	col.shape = c
	area.add_child(col)
	get_parent().add_child(area)

func _on_die_extra():
	pass
