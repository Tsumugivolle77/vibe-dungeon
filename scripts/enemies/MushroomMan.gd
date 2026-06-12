extends EnemyBase

@export var poison_radius: float    = 60.0
@export var poison_dps: float       = 4.0
@export var poison_duration: float  = 3.0
@export var attack_range: float     = 50.0
@export var attack_cooldown: float  = 1.5

var attack_timer: float = 0.0

func _get_pixel_texture(): return PixelArt.make_mushroom()

func _on_ready_extra():
	max_hp     = 55.0
	hp         = max_hp
	move_speed  = 65.0
	damage     = 10.0
	xp_value   = 13
	body_color  = Color(0.65, 0.4, 0.15)
	body_rect.color = body_color

func _tick_ai(delta: float):
	attack_timer -= delta
	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	if dist > attack_range:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			_poison_attack()

func _poison_attack():
	attack_timer = attack_cooldown
	if is_instance_valid(player) and player.has_method("take_damage"):
		if distance_to_player() <= attack_range:
			player.take_damage(damage)

func _on_die_extra():
	# Leave a poison cloud
	_spawn_poison_cloud()

func _spawn_poison_cloud():
	var cloud = ColorRect.new()
	cloud.color     = Color(0.5, 0.8, 0.1, 0.4)
	cloud.size      = Vector2(poison_radius * 2, poison_radius * 2)
	cloud.position  = global_position - Vector2(poison_radius, poison_radius)
	get_parent().add_child(cloud)

	var elapsed = 0.0
	var interval = 0.5
	var ticks    = int(poison_duration / interval)
	for _i in ticks:
		await get_tree().create_timer(interval).timeout
		if not is_instance_valid(cloud):
			return
		elapsed += interval
		if is_instance_valid(GameManager.player_ref):
			var p = GameManager.player_ref as Node2D
			if p.global_position.distance_to(global_position) <= poison_radius:
				if p.has_method("take_damage"):
					p.take_damage(poison_dps * interval)

	if is_instance_valid(cloud):
		var t = cloud.create_tween()
		t.tween_property(cloud, "modulate:a", 0.0, 0.5)
		t.tween_callback(cloud.queue_free)
