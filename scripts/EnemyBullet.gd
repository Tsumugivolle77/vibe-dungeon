extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 200.0
var damage: float      = 10.0
var lifetime: float    = 4.0
var is_boss_bullet: bool = false
# For homing boss bullets
var homing_strength: float = 0.0
var kind: String = "normal"   # "normal"/"sniper"/"laser"/"poison"/"homing"
var bounces: int = 0          # wall ricochets remaining (for bouncing barrages)
var _age: float = 0.0

func _ready():
	add_to_group("enemy_bullet")
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	_apply_kind()

func _apply_kind():
	match kind:
		"sniper":
			$Visual.color    = Color(0.45, 0.9, 1.0)
			$Visual.size     = Vector2(26, 6)
			$Visual.position = Vector2(-13, -3)
			rotation = direction.angle()
			$CollisionShape2D.scale = Vector2(1.3, 1.3)
		"laser":
			$Visual.color    = Color(1.0, 0.25, 0.85)
			$Visual.size     = Vector2(40, 7)
			$Visual.position = Vector2(-20, -3.5)
			rotation = direction.angle()
			$CollisionShape2D.scale = Vector2(1.9, 1.9)   # wide laser trajectory
		"poison":
			$Visual.color    = Color(0.45, 0.85, 0.2)
			$Visual.size     = Vector2(18, 18)
			$Visual.position = Vector2(-9, -9)
			$CollisionShape2D.scale = Vector2(1.5, 1.5)
		_:
			if is_boss_bullet:
				$Visual.color    = Color(1.0, 0.2, 0.8)
				$Visual.size     = Vector2(18, 18)
				$Visual.position = Vector2(-9, -9)
				$CollisionShape2D.scale = Vector2(1.6, 1.6)

func _process(delta: float):
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if homing_strength > 0.0 and is_instance_valid(GameManager.player_ref):
		var target = GameManager.player_ref as Node2D
		var to_player = (target.global_position - global_position).normalized()
		direction = direction.lerp(to_player, homing_strength * delta).normalized()

	position += direction * speed * delta

func _on_area(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var p = area.get_parent()
		if p.has_method("take_damage"):
			p.take_damage(damage)
		queue_free()

func _on_body(body: Node2D):
	if body.is_in_group("barrel") and body.has_method("take_damage"):
		body.take_damage()
		queue_free()
		return
	if body is StaticBody2D:
		if bounces > 0:
			# Reflect off the wall (axis-aligned tiles): snap the normal to an axis.
			var n: Vector2 = global_position - body.global_position
			if absf(n.x) >= absf(n.y):
				n = Vector2(signf(n.x), 0.0)
			else:
				n = Vector2(0.0, signf(n.y))
			if n == Vector2.ZERO:
				n = -direction
			direction = direction.bounce(n).normalized()
			rotation = direction.angle()
			bounces -= 1
			position += direction * 6.0   # nudge clear of the wall
			return
		queue_free()
