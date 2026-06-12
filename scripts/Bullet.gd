extends Area2D

var direction: Vector2   = Vector2.RIGHT
var speed: float         = 400.0
var damage: float        = 15.0
var lifetime: float      = 3.0
var weapon_props: Dictionary = {}

var _age: float = 0.0
var _hit: bool  = false
var _homing_target: Node2D = null

func _ready():
	add_to_group("player_bullet")
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	# Visual colour based on element
	var elem = weapon_props.get("element", "")
	var col: Color = Color.YELLOW
	match elem:
		"fire":      col = Color(1.0, 0.4, 0.1)
		"ice":       col = Color(0.4, 0.8, 1.0)
		"lightning": col = Color(0.9, 0.9, 0.2)
		"plasma":    col = Color(0.5, 0.2, 1.0)
		"holy":      col = Color(1.0, 0.95, 0.6)
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
