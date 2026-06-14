extends Node2D

# A friendly unit (己方单位) summoned by certain boss weapons — a fairy, vine, or
# slimelet that fights for the player: it seeks the nearest enemy and fires
# player-side bullets at it, then expires after a while.

var kind: String = "fairy"   # "fairy" / "vine" / "slime"
var damage: float = 14.0

var _life: float    = 11.0
var _fire_cd: float = 0.4
var _speed: float   = 70.0

var _bullet_scene: PackedScene = preload("res://scenes/bullets/Bullet.tscn")

func _ready():
	add_to_group("ally")
	z_index = 1
	match kind:
		"vine":  _speed = 0.0     # rooted turret
		"slime": _speed = 55.0
		_:       _speed = 80.0    # fairy: nimble
	_build_visual()
	scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_visual():
	var tex: ImageTexture
	match kind:
		"vine":  tex = PixelArt.make_vine_creature()
		"slime": tex = PixelArt.make_slime()
		_:       tex = PixelArt.make_fairy()
	var spr = PixelArt.sprite_from(tex)
	spr.modulate = Color(0.55, 0.85, 1.0)   # blue ally tint
	add_child(spr)
	# A soft allied aura.
	var aura = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 12:
		var a = TAU * i / 12
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	aura.polygon = pts
	aura.color = Color(0.4, 0.8, 1.0, 0.18)
	aura.z_index = -1
	add_child(aura)

func _process(delta: float):
	_life -= delta
	if _life <= 0.0:
		set_process(false)
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		return

	var target = _nearest_enemy()
	if target == null:
		return
	var to: Vector2 = target.global_position - global_position
	var dist := to.length()
	if _speed > 0.0 and dist > 150.0:
		global_position += to.normalized() * _speed * delta

	_fire_cd -= delta
	if _fire_cd <= 0.0 and dist < 480.0:
		_fire_cd = 0.85
		_shoot_at(target)

func _nearest_enemy():
	var best: Node2D = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best

func _shoot_at(target: Node2D):
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var b = _bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position
	b.direction    = dir
	b.speed        = 380.0
	b.damage       = damage
	b.weapon_id    = "pistol"
	b.weapon_props = {}
