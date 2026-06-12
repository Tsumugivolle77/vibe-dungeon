extends EnemyBase

@export var is_mini: bool = false
@export var split_count: int = 2

func _get_pixel_texture(): return PixelArt.make_slime()

func _on_ready_extra():
	if is_mini:
		max_hp     = 15.0
		hp         = max_hp
		move_speed  = 60.0
		damage     = 6.0
		xp_value   = 4
		body_color  = Color(0.4, 0.9, 0.4, 0.85)
		body_size   = Vector2(18, 18)
		split_count = 0
	else:
		max_hp     = 55.0
		hp         = max_hp
		move_speed  = 55.0
		damage     = 8.0
		xp_value   = 12
		body_color  = Color(0.3, 0.85, 0.3, 0.9)
		body_size   = Vector2(36, 36)
	body_rect.color = body_color
	body_rect.size  = body_size
	body_rect.position = -body_size * 0.5

func _tick_ai(delta: float):
	if is_instance_valid(player):
		navigate_to(player.global_position, delta)

func _on_die_extra():
	if split_count <= 0:
		return
	var slime_scene = load("res://scenes/enemies/Slime.tscn")
	for i in split_count:
		var mini = slime_scene.instantiate()
		mini.is_mini = true
		mini.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_parent().add_child(mini)
