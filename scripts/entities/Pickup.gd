extends Area2D
class_name Pickup

signal collected

enum Type { HEALTH_ORB, AMMO_ORB, HEALTH_PACK, AMMO_PACK, GOLD }

var pickup_type: Type = Type.HEALTH_ORB
var value: float      = 10.0

const MAGNET_RADIUS = 70.0
const MAGNET_SPEED  = 240.0
const LIFETIME      = 22.0
const AUTO_TYPES    = [Type.HEALTH_ORB, Type.AMMO_ORB, Type.GOLD]

var _age: float         = 0.0
var _bob: float         = 0.0
var _attracted: bool    = false
var _pull_time: float   = 0.0
var _player: Node2D     = null
var _base_y: float      = 0.0
var _base_y_set: bool   = false  # capture position on first _process after spawn()

func setup(t: Type, val: float = 1.0):
	pickup_type = t
	value       = val
	add_to_group("pickup")

	var tex: ImageTexture
	match t:
		Type.HEALTH_ORB:  tex = PixelArt.make_health_orb()
		Type.AMMO_ORB:    tex = PixelArt.make_ammo_orb()
		Type.HEALTH_PACK: tex = PixelArt.make_health_pack()
		Type.AMMO_PACK:   tex = PixelArt.make_ammo_pack()
		Type.GOLD:        tex = PixelArt.make_gold_coin()

	var spr = PixelArt.sprite_from(tex)
	add_child(spr)

	if _is_auto():
		# small circle collider
		var col = CollisionShape2D.new()
		var c   = CircleShape2D.new()
		c.radius = 10.0
		col.shape = c
		add_child(col)
		body_entered.connect(_on_auto_body)
	else:
		# slightly larger collider + prompt label
		var col = CollisionShape2D.new()
		var c   = CircleShape2D.new()
		c.radius = 14.0
		col.shape = c
		add_child(col)
		var lbl = Label.new()
		lbl.text = "[Enter]"
		lbl.position = Vector2(-18, -28)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		add_child(lbl)

	# pop-in tween
	scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)

func _ready():
	_find_player()
	# _base_y is captured on the first _process frame, after spawn() sets global_position

func _find_player():
	var arr = get_tree().get_nodes_in_group("player")
	_player = arr[0] if arr.size() > 0 else null

func _process(delta: float):
	_age += delta
	_bob += delta * 3.2
	# Capture base y on the first frame — after spawn() has set global_position.
	# Doing this in _ready() is too early (position not yet set at that point).
	if not _base_y_set:
		_base_y = position.y
		_base_y_set = true
	# gentle bob
	position.y = _base_y + sin(_bob) * 2.5

	if _age > LIFETIME:
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
		tw.tween_callback(queue_free)
		set_process(false)
		return

	if not is_instance_valid(_player):
		_find_player()
		return

	if not _is_auto():
		return

	var dist = global_position.distance_to(_player.global_position)
	if dist < MAGNET_RADIUS:
		_attracted = true

	if _attracted:
		_pull_time += delta
		var spd = MAGNET_SPEED * (1.0 + _pull_time * 3.0)
		var dir = (_player.global_position - global_position).normalized()
		global_position += dir * spd * delta
		_base_y = position.y
		if Engine.get_frames_drawn() % 3 == 0:
			_trail()

func _trail():
	var cr = ColorRect.new()
	var col = _orb_color()
	col.a   = 0.45
	cr.color = col
	var sz  = randf_range(2.5, 5.0)
	cr.size  = Vector2(sz, sz)
	cr.global_position = global_position - cr.size * 0.5
	get_parent().add_child(cr)
	var tw = cr.create_tween()
	tw.tween_property(cr, "modulate:a", 0.0, 0.22)
	tw.tween_callback(cr.queue_free)

func _orb_color() -> Color:
	match pickup_type:
		Type.HEALTH_ORB, Type.HEALTH_PACK: return Color(0.95, 0.15, 0.15)
		Type.AMMO_ORB,   Type.AMMO_PACK:   return Color(0.10, 0.42, 0.92)
		Type.GOLD:                          return Color(0.92, 0.72, 0.05)
	return Color.WHITE

func _is_auto() -> bool:
	return pickup_type in AUTO_TYPES

func _on_auto_body(body: Node2D):
	if body.is_in_group("player"):
		_apply(body)

func try_collect(player: Node2D):
	if not _is_auto():
		_apply(player)

func _apply(player: Node2D):
	match pickup_type:
		Type.HEALTH_ORB, Type.HEALTH_PACK:
			if player.has_method("heal"):
				player.heal(int(value))
		Type.AMMO_ORB:
			if player.has_method("restore_energy"):
				player.restore_energy(10)
		Type.AMMO_PACK:
			if player.has_method("restore_energy"):
				player.restore_energy(35)
		Type.GOLD:
			GameManager.add_gold(int(value))
	emit_signal("collected")
	_burst()
	queue_free()

func _burst():
	for i in 8:
		var cr = ColorRect.new()
		cr.color = _orb_color()
		var sz = randf_range(3.0, 7.0)
		cr.size = Vector2(sz, sz)
		cr.global_position = global_position - cr.size * 0.5
		get_parent().add_child(cr)
		var angle = (TAU / 8.0) * i + randf_range(-0.3, 0.3)
		var d     = randf_range(16.0, 36.0)
		var tw    = cr.create_tween()
		tw.tween_property(cr, "global_position",
			cr.global_position + Vector2(cos(angle), sin(angle)) * d, 0.35)
		tw.parallel().tween_property(cr, "modulate:a", 0.0, 0.35)
		tw.tween_callback(cr.queue_free)

# ── Static factory ──────────────────────────────────────────────────────────
static func spawn(parent: Node2D, pos: Vector2, type: Type, val: float = 1.0) -> Pickup:
	var p: Pickup = load("res://scenes/entities/Pickup.tscn").instantiate()
	parent.add_child(p)
	p.global_position = pos
	p.setup(type, val)
	return p
