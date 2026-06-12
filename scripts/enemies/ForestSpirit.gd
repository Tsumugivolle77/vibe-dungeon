extends EnemyBase

@export var phase_cooldown: float  = 3.5
@export var shoot_cooldown: float  = 1.0
@export var bullet_speed: float    = 240.0
@export var orb_count: int         = 3

var phase_timer: float  = 0.0
var shoot_timer: float  = 0.5
var is_phasing: bool    = false

func _get_pixel_texture(): return PixelArt.make_spirit()

func _on_ready_extra():
	max_hp     = 45.0
	hp         = max_hp
	move_speed  = 100.0
	damage     = 12.0
	xp_value   = 14
	body_color  = Color(0.5, 0.3, 0.9, 0.7)
	body_rect.color = body_color

func _tick_ai(delta: float):
	phase_timer -= delta
	shoot_timer -= delta

	if not is_instance_valid(player):
		return

	if phase_timer <= 0.0 and not is_phasing:
		_start_phase()

	navigate_to(player.global_position, delta)

	if shoot_timer <= 0.0:
		_shoot_orbs()

func _start_phase():
	is_phasing = true
	phase_timer = phase_cooldown
	$CollisionShape2D.set_deferred("disabled", true)
	body_rect.modulate = Color(1, 1, 1, 0.3)
	await get_tree().create_timer(1.5).timeout
	$CollisionShape2D.set_deferred("disabled", false)
	body_rect.modulate = Color.WHITE
	is_phasing = false

func _shoot_orbs():
	shoot_timer = shoot_cooldown
	for i in orb_count:
		var angle = (TAU / orb_count) * i
		shoot(Vector2(cos(angle), sin(angle)), bullet_speed)
