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

var hp: float     = 0.0
var alive: bool   = true
var knockback_vel: Vector2 = Vector2.ZERO

var slow_factor: float = 1.0
var slow_timer:  float = 0.0
var dot_damage:  float = 0.0
var dot_timer:   float = 0.0

var player: Node2D = null

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
		var spr = PixelArt.sprite_from(tex)
		spr.z_index = 1
		add_child(spr)
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

func shoot(dir: Vector2, spd: float = 200.0, dmg: float = -1.0):
	var b: Node = enemy_bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position
	b.direction       = dir.normalized()
	b.speed           = spd
	b.damage          = dmg if dmg >= 0 else damage
	b.is_boss_bullet  = is_boss_mode

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	hp -= amount
	knockback_vel = knockback
	# Also damage any crate we might be (not applicable – but pass-through for bullets hitting crates)
	body_rect.modulate = Color.RED
	var t = create_tween()
	t.tween_property(body_rect, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_die()

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

	# Drop gold
	var gold_amount = randi_range(gold_drop_min, gold_drop_max)
	if is_boss_mode:
		gold_amount *= 3
	for i in min(gold_amount, 5):
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		Pickup.spawn(get_parent(), global_position + offset, Pickup.Type.GOLD, ceil(float(gold_amount) / 5.0))

	# Small chance to drop health or ammo orb
	if randf() < 0.25:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 12)
	if randf() < 0.30:
		Pickup.spawn(get_parent(), global_position + Vector2(8, 0), Pickup.Type.AMMO_ORB, 8)

	$CollisionShape2D.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
	_on_die_extra()

func _on_die_extra():
	pass
