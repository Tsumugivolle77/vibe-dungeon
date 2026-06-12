extends EnemyBase

@export var vine_range: float     = 180.0
@export var vine_cooldown: float  = 3.0
@export var root_duration: float  = 2.0
@export var vine_damage: float    = 8.0

var vine_timer: float = 1.5
var is_rooting: bool  = false

func _on_ready_extra():
	max_hp     = 65.0
	hp         = max_hp
	move_speed  = 55.0
	damage     = 10.0
	xp_value   = 16
	body_color  = Color(0.15, 0.5, 0.1)
	body_size   = Vector2(38, 38)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5

func _tick_ai(delta: float):
	vine_timer -= delta
	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	if dist > 80.0:
		navigate_to(player.global_position, delta)
	else:
		velocity = Vector2.ZERO

	if vine_timer <= 0.0 and dist <= vine_range:
		_extend_vine()

func _extend_vine():
	vine_timer = vine_cooldown
	is_rooting = true

	# Spawn vine hitbox segments towards player
	var steps = 4
	var dir   = direction_to_player()
	for i in steps:
		var seg_pos = global_position + dir * (40.0 + i * 35.0)
		_spawn_vine_segment(seg_pos, dir, i * 0.1)

func _spawn_vine_segment(pos: Vector2, _dir: Vector2, delay: float):
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	var seg = ColorRect.new()
	seg.color = Color(0.1, 0.55, 0.05)
	seg.size  = Vector2(20, 20)
	seg.position = pos - Vector2(10, 10)
	get_parent().add_child(seg)

	# Check player overlap each frame for root_duration
	if is_instance_valid(player):
		if player.global_position.distance_to(pos) < 30.0:
			player.take_damage(vine_damage)

	var t = seg.create_tween()
	t.tween_interval(root_duration)
	t.tween_property(seg, "modulate:a", 0.0, 0.3)
	t.tween_callback(seg.queue_free)
