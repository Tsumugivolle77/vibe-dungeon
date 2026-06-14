extends Area2D

# A scorching lava pool (岩浆坑) left by certain boss weapons. Damages any ENEMY
# standing in it on a timer, then fades. Harmless to the player.

const DAMAGE   = 14.0
const INTERVAL = 0.5
const LIFETIME = 4.5
const RADIUS   = 40.0

# When true this is a HOSTILE pool (left by boss meteors) that burns the PLAYER;
# otherwise it's a friendly pool (boss weapons) that burns enemies.
var target_player: bool    = false
var lifetime_override: float = -1.0
var radius_override: float  = -1.0
var tint: Color            = Color(0, 0, 0, 0)   # if alpha>0, recolors the pool (e.g. acid)

var _tick: float = 0.0
var _life: float = LIFETIME
var _radius: float = RADIUS

func _ready():
	if lifetime_override > 0.0:
		_life = lifetime_override
	if radius_override > 0.0:
		_radius = radius_override
	collision_layer = 0
	collision_mask  = 2 if target_player else 8   # player (layer 2) vs enemy (layer 4)
	monitoring = true
	z_index = -1          # under units, above floor
	var col = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = _radius
	col.shape = c
	add_child(col)
	_build_visual()
	# Spawn pop-in.
	scale = Vector2(0.3, 0.3)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)

func _build_visual():
	var outer_c := Color(0.85, 0.28, 0.06, 0.7)
	var inner_c := Color(1.0, 0.62, 0.12, 0.85)
	if tint.a > 0.0:
		outer_c = Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, 0.7)
		inner_c = Color(tint.r, tint.g, tint.b, 0.85)
	add_child(_blob(_radius, outer_c))
	add_child(_blob(_radius * 0.6, inner_c))

func _blob(radius: float, col: Color) -> Polygon2D:
	var poly = Polygon2D.new()
	var pts = PackedVector2Array()
	var seg = 16
	for i in seg:
		var a = TAU * i / seg
		pts.append(Vector2(cos(a), sin(a)) * radius * randf_range(0.82, 1.0))
	poly.polygon = pts
	poly.color = col
	return poly

func _process(delta: float):
	_life -= delta
	if _life <= 0.0:
		set_process(false)
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = INTERVAL
		var grp := "player" if target_player else "enemy"
		for b in get_overlapping_bodies():
			if is_instance_valid(b) and b.is_in_group(grp) and b.has_method("take_damage"):
				b.take_damage(DAMAGE)
