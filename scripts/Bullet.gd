extends Area2D

var direction: Vector2       = Vector2.RIGHT
var speed: float             = 400.0
var damage: float            = 15.0
var lifetime: float          = 3.0
var weapon_props: Dictionary = {}
var weapon_id: String        = "pistol"
var _bounces: int            = 0

var _age: float = 0.0
var _hit: bool  = false
var _homing_target: Node2D = null
var _fire_trail_acc: float = 0.0   # accumulator for fire_staff's trailing fire pits
var _boomerang_returning: bool = false
var _boomerang_time: float = 0.0
var _visual_done: bool = false     # _setup_visual runs on the first _process (props are set by then)
var _shape_node: Node2D = null     # custom-shaped bullet visual (rocket/orb/star/…)
var _shape_directional: bool = false   # shape rotates to face travel direction
var _shape_spin: bool = false      # shape spins (boomerang)

func _ready():
	add_to_group("player_bullet")
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	# NOTE: _setup_visual() is deferred to the first _process — the spawner sets
	# weapon_id/weapon_props/direction AFTER add_child(), so they aren't available yet.

func _setup_visual():
	var elem: String = weapon_props.get("element", "")
	var col := Color(1.00, 0.92, 0.65)  # default warm yellow

	# Weapon-specific shape scale (collision unaffected — only $Visual is scaled)
	match weapon_id:
		"sniper", "railgun":
			$Visual.scale = Vector2(2.8, 0.35)   # long thin needle
		"void_cannon":
			$Visual.scale = Vector2(2.4, 2.4)    # large void orb
		"laser_gun":
			$Visual.scale = Vector2(3.5, 0.25)   # ultra-thin beam segment
		"thunder_bow":
			$Visual.scale = Vector2(2.6, 0.5)    # large lightning arrow (2×)
		"bow", "crossbow":
			$Visual.scale = Vector2(2.4, 0.38)   # arrow shaft
		"rocket_launcher":
			$Visual.scale = Vector2(2.9, 1.6)    # rocket — long body (2× bigger)
		"cannon":
			$Visual.scale = Vector2(2.6, 2.6)    # cannonball — round (2× bigger)
		"grenade_launcher", "slime_burst", "mandrake_rod":
			$Visual.scale = Vector2(1.8, 1.3)    # shell
		"star_requiem":
			$Visual.scale = Vector2(2.8, 2.8)    # big star (3×)
		"boomerang":
			$Visual.scale = Vector2(3.2, 3.2)    # large spinning disc (3×)
		"dragon_fang":
			$Visual.scale = Vector2(1.9, 1.0)    # dragon bolt
		"smg", "machine_gun", "minigun", "shotgun", "shotgun_m3":
			$Visual.scale = Vector2(0.72, 0.72)  # small pellet
		"shotgun_m2":
			$Visual.scale = Vector2(1.5, 1.5)    # heavier slug
		"fire_staff":
			$Visual.scale = Vector2(2.7, 2.7)    # large flame (2×)
		"ice_staff":
			$Visual.scale = Vector2(2.5, 1.1)    # ice spike (2×, pointed)
		"plasma_gun":
			$Visual.scale = Vector2(2.6, 2.6)    # large plasma orb (3×)
		"lightning_staff", "holy_staff":
			$Visual.scale = Vector2(1.35, 1.35)  # glowing magic orb

	# Weapon-specific color when no element override
	if elem.is_empty():
		match weapon_id:
			"pistol":
				col = Color(1.00, 0.92, 0.65)
			"revolver":
				col = Color(1.00, 0.82, 0.40)
			"smg", "machine_gun", "minigun":
				col = Color(0.82, 0.88, 0.94)
			"shotgun":
				col = Color(0.95, 0.80, 0.40)
			"shotgun_m2":
				col = Color(0.95, 0.62, 0.25)
			"shotgun_m3":
				col = Color(0.55, 0.90, 0.95)
			"sniper":
				col = Color(0.55, 0.88, 1.00)
			"railgun":
				col = Color(0.20, 0.95, 1.00)
			"void_cannon":
				col = Color(0.42, 0.10, 0.72)
			"laser_gun":
				col = Color(0.15, 0.95, 0.90)
			"bow", "crossbow":
				col = Color(0.62, 0.40, 0.12)
			"thunder_bow":
				col = Color(0.88, 0.88, 0.20)
			"rocket_launcher":
				col = Color(0.90, 0.48, 0.18)
			"cannon":
				col = Color(0.28, 0.30, 0.34)   # dark iron cannonball
			"grenade_launcher":
				col = Color(0.55, 0.72, 0.20)
			"boomerang":
				col = Color(0.72, 0.52, 0.18)
			"star_requiem":
				col = Color(0.85, 0.60, 1.00)
			"void_cannon":
				col = Color(0.42, 0.10, 0.72)
	else:
		match elem:
			"fire":      col = Color(1.00, 0.42, 0.10)
			"ice":       col = Color(0.38, 0.78, 1.00)
			"lightning": col = Color(0.92, 0.92, 0.22)
			"plasma":    col = Color(0.50, 0.18, 1.00)
			"holy":      col = Color(1.00, 0.95, 0.62)

	$Visual.color = col

	# Shaped bullets (rocket / cannonball / star / flame / ice-spike / …) replace the
	# plain square with a matching polygon. Non-shaped weapons keep the scaled square.
	var shape := _shape_for(weapon_id)
	if shape != "":
		$Visual.visible = false
		_shape_node = _build_shape(shape, col)
		add_child(_shape_node)

	# Collision footprint scales with the projectile class: heavy ordnance (shells,
	# rockets, void/boss orbs) gets a much larger hitbox; magic orbs a moderate one.
	var col_scale := 1.0
	match weapon_id:
		"cannon", "rocket_launcher", "void_cannon", "star_requiem", "plasma_gun":
			col_scale = 2.4
		"grenade_launcher", "slime_burst", "mandrake_rod", "boomerang":
			col_scale = 2.2
		"fire_staff", "ice_staff":
			col_scale = 2.0
		"lightning_staff", "dragon_fang":
			col_scale = 1.5
		"sniper", "railgun", "laser_gun", "thunder_bow", "shotgun_m2":
			col_scale = 1.3
	$CollisionShape2D.scale = Vector2(col_scale, col_scale)

# Maps a weapon to a custom bullet silhouette (or "" to keep the square pellet).
func _shape_for(id: String) -> String:
	match id:
		"cannon", "void_cannon", "grenade_launcher", "plasma_gun": return "orb"
		"rocket_launcher": return "rocket"
		"star_requiem":    return "star"
		"fire_staff":      return "flame"
		"ice_staff":       return "spike"
		"dragon_fang":     return "fang"
		"boomerang":       return "boomerang"
	return ""

func _shape_scale(id: String) -> float:
	match id:
		"cannon", "plasma_gun": return 1.8
		"void_cannon":          return 1.7
		"grenade_launcher":     return 1.2
		"rocket_launcher", "fire_staff", "boomerang": return 1.7
		"star_requiem", "ice_staff": return 1.6
		"dragon_fang":          return 1.5
	return 1.0

func _build_shape(shape: String, col: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = col
	match shape:
		"orb":
			poly.polygon = _circle_pts(7.0)
		"rocket":
			# Pointed nose (+x), body, twin tail fins.
			poly.polygon = PackedVector2Array([
				Vector2(12, 0), Vector2(4, -4), Vector2(-6, -4), Vector2(-10, -8),
				Vector2(-8, -2), Vector2(-11, 0), Vector2(-8, 2), Vector2(-10, 8),
				Vector2(-6, 4), Vector2(4, 4)])
			_shape_directional = true
		"star":
			poly.polygon = _star_pts(10.0, 4.4, 5)
		"flame":
			poly.polygon = PackedVector2Array([
				Vector2(11, 0), Vector2(3, -5), Vector2(-5, -4),
				Vector2(-9, 0), Vector2(-5, 4), Vector2(3, 5)])
			_shape_directional = true
		"spike":
			poly.polygon = PackedVector2Array([
				Vector2(13, 0), Vector2(0, -5), Vector2(-9, 0), Vector2(0, 5)])
			_shape_directional = true
		"fang":
			poly.polygon = PackedVector2Array([
				Vector2(10, 0), Vector2(-1, -4), Vector2(-7, 0), Vector2(-1, 4)])
			_shape_directional = true
		"boomerang":
			poly.polygon = PackedVector2Array([
				Vector2(-10, -2), Vector2(0, -11), Vector2(10, -2),
				Vector2(5, 2), Vector2(0, -3), Vector2(-5, 2)])
			_shape_spin = true
	var f := _shape_scale(weapon_id)
	poly.scale = Vector2(f, f)
	if _shape_directional:
		poly.rotation = direction.angle()
	return poly

func _circle_pts(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _star_pts(r_out: float, r_in: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := -PI * 0.5 + TAU * i / float(points * 2)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _process(delta: float):
	if not _visual_done:
		_visual_done = true
		_setup_visual()
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if weapon_props.get("homing") and is_instance_valid(_homing_target):
		var to_target = (_homing_target.global_position - global_position).normalized()
		direction = direction.lerp(to_target, delta * 4.0).normalized()
	elif weapon_props.get("homing") and not is_instance_valid(_homing_target):
		_find_homing_target()

	# Keep directional shapes (rocket/spike/fang/flame) pointing along travel.
	if _shape_directional and is_instance_valid(_shape_node):
		_shape_node.rotation = direction.angle()
	# Spin shapes (boomerang).
	if _shape_spin and is_instance_valid(_shape_node):
		_shape_node.rotation += delta * 14.0

	# Boomerang: fly out, spin, then curve back to the player; clears bullets it passes.
	if weapon_props.get("returns"):
		_boomerang_time += delta
		_clear_nearby_bullets(30.0)
		if not _boomerang_returning and _boomerang_time > 0.45:
			_boomerang_returning = true
		if _boomerang_returning and is_instance_valid(GameManager.player_ref):
			var to_pl: Vector2 = GameManager.player_ref.global_position - global_position
			if to_pl.length() < 26.0:
				queue_free()
				return
			direction = direction.lerp(to_pl.normalized(), delta * 6.0).normalized()

	# Homing dragon bolts (and similar) sweep stray bullets out of their path.
	if weapon_props.get("clear_path"):
		_clear_nearby_bullets(24.0)

	position += direction * speed * delta

	if weapon_props.get("trail") and Engine.get_frames_drawn() % 2 == 0:
		_spawn_trail()

	# Fire staff leaves burning pits along its path (every 0.1s, 20% chance).
	if weapon_props.get("fire_trail"):
		_fire_trail_acc += delta
		while _fire_trail_acc >= 0.1:
			_fire_trail_acc -= 0.1
			if randf() < 0.2:
				_spawn_fire_pit(global_position)

func _clear_nearby_bullets(r: float):
	for eb in get_tree().get_nodes_in_group("enemy_bullet"):
		if is_instance_valid(eb) and eb.global_position.distance_to(global_position) < r:
			eb.queue_free()

func _spawn_fire_pit(pos: Vector2):
	if not is_inside_tree():
		return
	var pit = load("res://scripts/entities/LavaPool.gd").new()
	pit.lifetime_override = 1.0
	pit.radius_override   = 26.0
	get_parent().add_child(pit)
	pit.global_position = pos

func _spawn_trail():
	if not is_inside_tree():
		return
	var dot := ColorRect.new()
	var c: Color = $Visual.color
	c.a = 0.55
	dot.color = c
	var sz := randf_range(3.0, 6.0)
	dot.size = Vector2(sz, sz)
	dot.global_position = global_position - dot.size * 0.5
	get_parent().add_child(dot)
	var tw := dot.create_tween()
	tw.tween_property(dot, "scale", Vector2(0.2, 0.2), 0.3)
	tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.3)
	tw.tween_callback(dot.queue_free)

func _find_homing_target():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_dist = INF
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			_homing_target = e

func _on_area(area: Area2D):
	if _hit:
		return
	if area.is_in_group("enemy_hitbox"):
		var e = area.get_parent()
		if e.has_method("take_damage"):
			e.take_damage(damage, Vector2.ZERO, weapon_props)
			_apply_special_effects(e)
		# Piercing, boomerangs and returning bolts pass through and keep flying.
		if not weapon_props.get("piercing", false) and not weapon_props.get("returns", false):
			_destroy()
		else:
			_hit = false

func _on_body(body: Node2D):
	if body.is_in_group("crate") and body.has_method("take_damage"):
		body.take_damage(damage)
		# Explosive weapons also detonate their own blast on obstacles, not just enemies.
		if weapon_props.get("explosive"):
			_explode()
			return
		if not weapon_props.get("piercing", false):
			_destroy()
		return
	if body is StaticBody2D:
		if weapon_props.get("bouncing") and _bounces < int(weapon_props.get("max_bounces", 2)):
			# Approximate the wall normal from the bullet's offset to the tile centre,
			# snapped to the nearest axis (tiles are axis-aligned squares).
			var n: Vector2 = global_position - body.global_position
			if absf(n.x) >= absf(n.y):
				n = Vector2(signf(n.x), 0.0)
			else:
				n = Vector2(0.0, signf(n.y))
			if n == Vector2.ZERO:
				n = -direction
			direction = direction.bounce(n).normalized()
			_bounces += 1
			global_position += direction * 6.0   # nudge clear of the wall
		elif weapon_props.get("explosive"):
			_explode()
		else:
			_destroy()

func _apply_special_effects(enemy: Node2D):
	var props = weapon_props
	var elem: String = props.get("element", "")
	# Elemental status afflictions (new 异常状态 system).
	if enemy.has_method("apply_status"):
		if props.get("fire_dot") or elem == "fire":
			enemy.apply_status("burn")
		if props.get("slow") or elem == "ice":
			if randf() < 0.5:
				enemy.apply_status("frostbite")
			if randf() < 0.3:
				enemy.apply_status("freeze")
		if elem == "holy" and randf() < 0.5:
			enemy.apply_status("holy")
		if (props.get("chain") or elem == "lightning") and randf() < 0.4:
			enemy.apply_status("paralysis")
		# Generic paralysis chance (plasma gun etc.).
		if randf() < float(props.get("paralyze_chance", 0.0)):
			enemy.apply_status("paralysis")
	if props.get("chain"):
		_chain_lightning(enemy)
	# Thunder bow: a sky-thunder bolt strikes the hit point — AoE + guaranteed stun.
	if props.get("thunder_strike"):
		_thunder_strike(enemy.global_position)
	# Summon a friendly unit on hit (boss weapons): fairy / vine / slime.
	var ally: String = props.get("summon_ally", "")
	if ally != "" and randf() < float(props.get("summon_chance", 0.2)):
		_spawn_ally(ally, enemy.global_position)
	# Lava pools for non-explosive lava weapons (explosive ones drop it in _explode).
	if props.get("lava_pool") and not props.get("explosive"):
		_spawn_lava(global_position)
	if props.get("explosive"):
		_explode()

func _spawn_lava(pos: Vector2):
	if not is_inside_tree():
		return
	var lava = load("res://scripts/entities/LavaPool.gd").new()
	get_parent().add_child(lava)
	lava.global_position = pos

func _spawn_ally(kind: String, pos: Vector2):
	if not is_inside_tree():
		return
	var ally = load("res://scripts/entities/AllyMinion.gd").new()
	ally.kind = kind
	get_parent().add_child(ally)
	ally.global_position = pos + Vector2(randf_range(-24, 24), randf_range(-24, 24))

func _spawn_black_hole(pos: Vector2):
	if not is_inside_tree():
		return
	var bh = load("res://scripts/entities/BlackHole.gd").new()
	get_parent().add_child(bh)
	bh.global_position = pos

# A sky-thunder strike: circular AoE damage + 100% paralysis at the hit point.
func _thunder_strike(pos: Vector2):
	if not is_inside_tree():
		return
	var radius := 95.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(pos) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(damage * 0.8)
			if e.has_method("apply_status"):
				e.apply_status("paralysis")
	_thunder_visual(pos, radius)

func _thunder_visual(pos: Vector2, radius: float):
	var p = get_parent()
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 0.5, 0.55)
	flash.size  = Vector2(radius * 2, radius * 2)
	flash.global_position = pos - flash.size * 0.5
	p.add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.3)
	ft.tween_callback(flash.queue_free)
	var bolt := Line2D.new()
	bolt.width = 5.0
	bolt.default_color = Color(1.0, 1.0, 0.45)
	bolt.add_point(Vector2(pos.x, pos.y - 360.0))
	bolt.add_point(Vector2(pos.x - 12.0, pos.y - 210.0))
	bolt.add_point(Vector2(pos.x + 9.0, pos.y - 110.0))
	bolt.add_point(pos)
	p.add_child(bolt)
	var bt := bolt.create_tween()
	bt.tween_property(bolt, "modulate:a", 0.0, 0.25)
	bt.tween_callback(bolt.queue_free)

func _chain_lightning(origin: Node2D):
	var range_val: float = weapon_props.get("chain_range", 150.0)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e == origin:
			continue
		if e.global_position.distance_to(origin.global_position) <= range_val:
			if e.has_method("take_damage"):
				e.take_damage(damage * 0.6, Vector2.ZERO)

func _explode():
	if not is_inside_tree():
		return
	var radius: float = weapon_props.get("explosion_radius", 80.0)
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		var d = e.global_position.distance_to(global_position)
		if d <= radius and e.has_method("take_damage"):
			e.take_damage(damage * (1.0 - d / radius), (e.global_position - global_position).normalized() * 200.0)
			# All shell/explosive blasts have a 50% chance to set the target alight.
			if e.has_method("apply_status") and randf() < 0.5:
				e.apply_status("burn")
	# Visual flash (simple)
	var flash = ColorRect.new()
	flash.color = Color(1, 0.8, 0.2, 0.6)
	flash.size = Vector2(radius * 2, radius * 2)
	flash.position = global_position - Vector2(radius, radius)
	get_parent().add_child(flash)
	var t = flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)
	# Lava weapons leave a burning pool at the blast site.
	if weapon_props.get("lava_pool"):
		_spawn_lava(global_position)
	# Void cannon collapses the blast into a black hole.
	if weapon_props.get("black_hole"):
		_spawn_black_hole(global_position)
	_destroy()

func _destroy():
	if _hit:
		return
	_hit = true
	queue_free()
