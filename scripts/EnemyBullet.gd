extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float       = 200.0
var damage: float      = 10.0
var lifetime: float    = 4.0
var is_boss_bullet: bool = false
# For homing boss bullets
var homing_strength: float = 0.0
var _age: float = 0.0

func _ready():
	add_to_group("enemy_bullet")
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	if is_boss_bullet:
		$Visual.color = Color(1.0, 0.2, 0.8)
		$Visual.size  = Vector2(14, 14)
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
	if body is StaticBody2D:
		queue_free()
