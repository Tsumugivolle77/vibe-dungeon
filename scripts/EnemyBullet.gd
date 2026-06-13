extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 200.0
var damage: float      = 10.0
var lifetime: float    = 4.0
var is_boss_bullet: bool = false
# For homing boss bullets
var homing_strength: float = 0.0
var kind: String = "normal"   # "normal"/"sniper"/"laser"/"poison"/"homing"
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
			$Visual.size     = Vector2(20, 5)
			$Visual.position = Vector2(-10, -2.5)
			rotation = direction.angle()
		"laser":
			$Visual.color    = Color(1.0, 0.25, 0.85)
			$Visual.size     = Vector2(30, 4)
			$Visual.position = Vector2(-15, -2)
			rotation = direction.angle()
		"poison":
			$Visual.color    = Color(0.45, 0.85, 0.2)
			$Visual.size     = Vector2(14, 14)
			$Visual.position = Vector2(-7, -7)
		_:
			if is_boss_bullet:
				$Visual.color    = Color(1.0, 0.2, 0.8)
				$Visual.size     = Vector2(14, 14)
				$Visual.position = Vector2(-7, -7)

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
		queue_free()
