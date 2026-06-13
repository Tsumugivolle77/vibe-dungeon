extends Area2D

var direction: Vector2       = Vector2.RIGHT
var speed: float             = 400.0
var damage: float            = 15.0
var lifetime: float          = 3.0
var weapon_props: Dictionary = {}
var weapon_id: String        = "pistol"

var _age: float = 0.0
var _hit: bool  = false
var _homing_target: Node2D = null

func _ready():
	add_to_group("player_bullet")
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	_setup_visual()

func _setup_visual():
	var elem: String = weapon_props.get("element", "")
	var col := Color(1.00, 0.92, 0.65)  # default warm yellow

	# Weapon-specific shape scale (collision unaffected — only $Visual is scaled)
	match weapon_id:
		"sniper", "railgun":
			$Visual.scale = Vector2(2.8, 0.35)   # long thin needle
		"void_cannon":
			$Visual.scale = Vector2(2.0, 2.0)    # large orb
		"laser_gun":
			$Visual.scale = Vector2(3.5, 0.25)   # ultra-thin beam segment
		"bow", "crossbow", "thunder_bow":
			$Visual.scale = Vector2(2.4, 0.38)   # arrow shaft
		"rocket_launcher", "grenade_launcher":
			$Visual.scale = Vector2(1.8, 1.3)    # rocket
		"boomerang":
			$Visual.scale = Vector2(1.6, 1.6)    # chunky disc
		"smg", "machine_gun", "minigun", "shotgun":
			$Visual.scale = Vector2(0.72, 0.72)  # small pellet
		"fire_staff", "ice_staff", "lightning_staff", "holy_staff":
			$Visual.scale = Vector2(1.35, 1.35)  # glowing magic orb

	# Weapon-specific color when no element override
	if elem.is_empty():
		match weapon_id:
			"pistol":
				col = Color(1.00, 0.92, 0.65)
			"revolver":
				col = Color(1.00, 0.82, 0.40)
			"smg", "machine_gun", "minigun":
				col = Color(0.82, 0.88, 0.94)
			"shotgun":
				col = Color(0.95, 0.80, 0.40)
			"sniper":
				col = Color(0.55, 0.88, 1.00)
			"railgun":
				col = Color(0.20, 0.95, 1.00)
			"void_cannon":
				col = Color(0.42, 0.10, 0.72)
			"laser_gun":
				col = Color(0.15, 0.95, 0.90)
			"bow", "crossbow":
				col = Color(0.62, 0.40, 0.12)
			"thunder_bow":
				col = Color(0.88, 0.88, 0.20)
			"rocket_launcher":
				col = Color(0.90, 0.48, 0.18)
			"grenade_launcher":
				col = Color(0.55, 0.72, 0.20)
			"boomerang":
				col = Color(0.72, 0.52, 0.18)
	else:
		match elem:
			"fire":      col = Color(1.00, 0.42, 0.10)
			"ice":       col = Color(0.38, 0.78, 1.00)
			"lightning": col = Color(0.92, 0.92, 0.22)
			"plasma":    col = Color(0.50, 0.18, 1.00)
			"holy":      col = Color(1.00, 0.95, 0.62)

	$Visual.color = col

func _process(delta: float):
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if weapon_props.get("homing") and is_instance_valid(_homing_target):
		var to_target = (_homing_target.global_position - global_position).normalized()
		direction = direction.lerp(to_target, delta * 4.0).normalized()
	elif weapon_props.get("homing") and not is_instance_valid(_homing_target):
		_find_homing_target()

	position += direction * speed * delta

	if weapon_props.get("trail") and Engine.get_frames_drawn() % 2 == 0:
		_spawn_trail()

func _spawn_trail():
	if not is_inside_tree():
		return
	var dot := ColorRect.new()
	var c: Color = $Visual.color
	c.a = 0.55
	dot.color = c
	var sz := randf_range(3.0, 6.0)
	dot.size = Vector2(sz, sz)
	dot.global_position = global_position - dot.size * 0.5
	get_parent().add_child(dot)
	var tw := dot.create_tween()
	tw.tween_property(dot, "scale", Vector2(0.2, 0.2), 0.3)
	tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.3)
	tw.tween_callback(dot.queue_free)

func _find_homing_target():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_dist = INF
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			_homing_target = e

func _on_area(area: Area2D):
	if _hit:
		return
	if area.is_in_group("enemy_hitbox"):
		var e = area.get_parent()
		if e.has_method("take_damage"):
			e.take_damage(damage, Vector2.ZERO, weapon_props)
			_apply_special_effects(e)
		if not weapon_props.get("piercing", false):
			_destroy()
		else:
			_hit = false

func _on_body(body: Node2D):
	if body.is_in_group("crate") and body.has_method("take_damage"):
		body.take_damage(damage)
		if not weapon_props.get("piercing", false):
			_destroy()
		return
	if body is StaticBody2D:
		if weapon_props.get("bouncing"):
			direction = direction.bounce(Vector2.RIGHT)
		elif weapon_props.get("explosive"):
			_explode()
		else:
			_destroy()

func _apply_special_effects(enemy: Node2D):
	var props = weapon_props
	if props.get("fire_dot"):
		if enemy.has_method("apply_dot"):
			enemy.apply_dot(5.0, 3.0)
	if props.get("slow"):
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(props.get("slow_factor", 0.5), 2.0)
	if props.get("chain"):
		_chain_lightning(enemy)
	if props.get("explosive"):
		_explode()

func _chain_lightning(origin: Node2D):
	var range_val: float = weapon_props.get("chain_range", 150.0)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == origin:
			continue
		if e.global_position.distance_to(origin.global_position) <= range_val:
			if e.has_method("take_damage"):
				e.take_damage(damage * 0.6, Vector2.ZERO)

func _explode():
	if not is_inside_tree():
		return
	var radius: float = weapon_props.get("explosion_radius", 80.0)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		var d = e.global_position.distance_to(global_position)
		if d <= radius and e.has_method("take_damage"):
			e.take_damage(damage * (1.0 - d / radius), (e.global_position - global_position).normalized() * 200.0)
	# Visual flash (simple)
	var flash = ColorRect.new()
	flash.color = Color(1, 0.8, 0.2, 0.6)
	flash.size = Vector2(radius * 2, radius * 2)
	flash.position = global_position - Vector2(radius, radius)
	get_parent().add_child(flash)
	var t = flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)
	_destroy()

func _destroy():
	if _hit:
		return
	_hit = true
	queue_free()
