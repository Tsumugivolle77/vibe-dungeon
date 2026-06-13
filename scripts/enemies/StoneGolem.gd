extends EnemyBase

@export var charge_speed: float    = 280.0
@export var charge_range: float    = 300.0
@export var charge_cooldown: float = 4.0
@export var charge_duration: float = 0.6

var charge_timer: float  = charge_cooldown * 0.5
var is_charging: bool    = false
var charge_dir: Vector2  = Vector2.ZERO
var charge_active_timer: float = 0.0

func _get_pixel_texture(): return PixelArt.make_golem()

const RARE_DROPS = ["void_cannon", "dragon_fang"]
func _on_die_extra():
	if randf() < 0.20:  # 20% rare drop
		var wid = RARE_DROPS[randi() % RARE_DROPS.size()]
		_drop_rare_weapon(wid)

func _drop_rare_weapon(wid: String):
	var area = Area2D.new()
	area.add_to_group("weapon_pickup")
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = global_position
	area.set_meta("weapon_id", wid)
	var lbl = Label.new()
	lbl.text = "★ " + WeaponDatabase.get_weapon(wid).get("name", "?")
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.position = Vector2(-28, -22)
	area.add_child(lbl)
	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 9)
	hint.position = Vector2(-14, -34)
	area.add_child(hint)
	var col = CollisionShape2D.new()
	var c   = CircleShape2D.new()
	c.radius = 20.0
	col.shape = c
	area.add_child(col)
	get_parent().add_child(area)

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
		velocity = Vector2.ZERO
		if is_instance_valid(player) and dist <= 60.0:
			player.take_damage(damage * delta)

func _begin_charge():
	is_charging        = true
	charge_active_timer = charge_duration
	charge_dir         = direction_to_player()
	body_rect.color    = Color(0.7, 0.3, 0.1)

func _tick_charge(delta: float):
	charge_active_timer -= delta
	velocity = charge_dir * charge_speed
	# Stomp damage to nearby enemies
	if is_instance_valid(player):
		if distance_to_player() < 40.0:
			player.take_damage(damage)
	if charge_active_timer <= 0.0:
		is_charging    = false
		charge_timer   = charge_cooldown
		body_rect.color = body_color
