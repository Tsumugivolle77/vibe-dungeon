extends EnemyBase

@export var charge_speed: float    = 280.0
@export var charge_range: float    = 300.0
@export var charge_cooldown: float = 4.0
@export var charge_duration: float = 0.6

var charge_timer: float  = charge_cooldown * 0.5
var is_charging: bool    = false
var charge_dir: Vector2  = Vector2.ZERO
var charge_active_timer: float = 0.0
var _charge_hit: bool    = false   # charge deals damage once per charge

func _get_pixel_texture(): return PixelArt.make_golem()

const RARE_DROPS = ["void_cannon", "dragon_fang"]
func _on_die_extra():
	if randf() < 0.20:  # 20% rare drop
		# Shared helper keeps the drop inside the room bounds (no off-map loot).
		spawn_weapon_pickup(RARE_DROPS[randi() % RARE_DROPS.size()])

func _on_ready_extra():
	max_hp      = 160.0
	hp          = max_hp
	is_elite    = true
	move_speed   = 40.0
	damage      = 30.0
	xp_value    = 25
	body_color   = Color(0.45, 0.45, 0.45)
	body_size    = Vector2(52, 52)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5

func _tick_ai(delta: float):
	if is_charging:
		_tick_charge(delta)
		return

	charge_timer -= delta
	if not is_instance_valid(player):
		return

	var dist = distance_to_player()
	if charge_timer <= 0.0 and dist <= charge_range:
		_begin_charge()
	elif dist > 60.0:
		navigate_to(player.global_position, delta)
	else:
		# No passive contact damage — the golem only hurts via its charge attack.
		velocity = Vector2.ZERO

func _begin_charge():
	is_charging        = true
	_charge_hit        = false
	charge_active_timer = charge_duration
	charge_dir         = direction_to_player()
	body_rect.color    = Color(0.7, 0.3, 0.1)

func _tick_charge(delta: float):
	charge_active_timer -= delta
	velocity = charge_dir * charge_speed
	# Charge connects once per charge (a melee attack, not continuous contact).
	if not _charge_hit and is_instance_valid(player) and distance_to_player() < 44.0:
		player.take_damage(damage)
		_charge_hit = true
	if charge_active_timer <= 0.0:
		is_charging    = false
		charge_timer   = charge_cooldown
		body_rect.color = body_color
