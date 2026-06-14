extends EnemyBase
class_name BossBase

# Shared boss framework: HP-bar signalling, 3-phase progression, a berserk mode
# at 50% HP, knockback immunity, and a sprite flash on hit. Subclasses override
# _boss_ai() (attack logic) and optionally _on_phase() (phase-entry effects).

signal boss_hp_changed(hp: float, max_hp: float)
signal boss_phase_changed(phase: int)

# CLAUDE.md: boss enters berserk mode below half HP. Phase 2 == berserk.
const PHASE2_THRESHOLD = 0.5   # berserk
const PHASE3_THRESHOLD = 0.25

# Bosses act 1.5× as often (CLAUDE batch) — the action cooldown counts down faster.
const ATTACK_RATE       = 1.5
# Displacement skills (leap/teleport) telegraph first and pause after, so the
# player always gets a reaction window despite the higher attack rate.
const DISPLACE_WINDUP   = 0.5   # telegraph time before the boss moves
const DISPLACE_RECOVERY = 1.4   # cooldown injected after landing (counts at ATTACK_RATE)

# CLAUDE.md: boss body should be ~4× a normal monster. A normal enemy sprite is
# ~9 cols × SCALE(3) ≈ 27px; a boss sprite (~13 cols ≈ 39px) × 2.8 ≈ 109px ≈ 4×.
@export var boss_sprite_scale: float = 2.4

var phase: int          = 1
var berserk: bool       = false
var action_timer: float = 1.5
var _drop_timer: float  = 3.0
var boss_drop_weapon: String = ""   # boss-exclusive rare dropped on death
var _displacing: bool   = false     # true during a leap/teleport (suppresses normal AI movement)
var _contact_cd: float  = 0.0       # cooldown between boss contact-damage hits

# Bosses count as boss-type (skips the generic non-boss damage multiplier).
func _is_boss_type() -> bool:
	return true

# Touching the boss's body hurts (CLAUDE batch). Reach covers the large boss body
# plus the player's radius; throttled so it doesn't drain HP every frame.
func _tick_contact(delta: float):
	if _contact_cd > 0.0:
		_contact_cd -= delta
		return
	var pl = GameManager.player_ref
	if not is_instance_valid(pl) or not pl.has_method("take_damage"):
		return
	var reach := body_size.x * boss_sprite_scale * 0.45 + 22.0
	if global_position.distance_to(pl.global_position) <= reach:
		pl.take_damage(damage * 0.7)
		_contact_cd = 0.7

func _on_ready_extra():
	# Subclass should call super() AFTER setting stats so the sprite scales correctly.
	max_hp *= 1.5   # +50% boss HP (CLAUDE batch)
	hp = max_hp
	max_armor = float(randi_range(50, 100))   # 护甲条 (50–100)
	armor = max_armor
	if sprite:
		sprite.scale = Vector2(boss_sprite_scale, boss_sprite_scale)
	# Emit once so the HUD boss bars initialise to full.
	emit_signal("boss_hp_changed", hp, max_hp)
	emit_signal("boss_armor_changed", armor, max_armor)

# Bosses keep the berserk tint as their resting colour after invulnerability ends.
func _base_tint() -> Color:
	return _tint()

func _tick_ai(delta: float):
	_tick_contact(delta)   # body contact damage runs even mid-leap (slam)
	_tick_armor(delta)     # armor regen + invulnerability timer (runs even mid-leap)
	# While leaping/teleporting, a tween drives position — hold velocity at zero and
	# skip the normal attack/movement AI so it doesn't fight the displacement.
	if _displacing:
		velocity = Vector2.ZERO
		return
	# CLAUDE.md: only drop ammo ("子弹") while berserk (below half HP); none above.
	if berserk:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = 2.5
			_boss_drop()

	action_timer -= delta * ATTACK_RATE   # 1.5× attack frequency

	var ratio := hp / max_hp
	if phase == 1 and ratio <= PHASE2_THRESHOLD:
		_set_phase(2)
	elif phase == 2 and ratio <= PHASE3_THRESHOLD:
		_set_phase(3)

	_boss_ai(delta)

# Override in subclasses for attack patterns.
func _boss_ai(_delta: float):
	pass

func _set_phase(p: int):
	phase = p
	emit_signal("boss_phase_changed", p)
	if p >= 2 and not berserk:
		_enter_berserk()
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.1)
		t.tween_property(sprite, "modulate", _tint(), 0.2)
	_on_phase(p)

# Berserk (below half HP): swap to the enraged sprite, then a retaliatory nova.
func _enter_berserk():
	berserk = true
	_swap_to_berserk_sprite()   # new below-half-HP texture
	if sprite:
		sprite.modulate = _tint()
	ring(16, 220.0)

func _tint() -> Color:
	if _enraged:
		return Color.WHITE   # the baked enraged texture carries the colour now
	return Color(1.5, 0.7, 0.7) if berserk else Color.WHITE

func _on_phase(_p: int):
	pass

# Below half HP the boss spews a few energy orbs ("子弹") for the player.
func _boss_drop():
	for s in [Vector2(-70, 0), Vector2(70, 0), Vector2(0, 70), Vector2(0, -70)]:
		Pickup.spawn(get_parent(), global_position + s, Pickup.Type.AMMO_ORB, 16)
	if randf() < 0.4:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 30)

# The boss's signature weapon is delivered via the golden reward chest spawned by
# the Room (below the portal), not as a loose pickup — nothing extra to drop here.
func _on_die_extra():
	pass

# Bosses ignore knockback and report HP changes to the boss bar. Armor soaks damage
# first; a golden aegis (during powerful casts) blocks everything.
func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	if invuln:
		return
	var dmg := _absorb_with_armor(amount)
	if dmg <= 0.0:
		return
	hp -= dmg
	emit_signal("boss_hp_changed", hp, max_hp)
	var flash_target = sprite if sprite else body_rect
	flash_target.modulate = Color(1.6, 0.4, 0.4)
	var t := create_tween()
	t.tween_property(flash_target, "modulate", _tint(), 0.15)
	if hp <= 0.0:
		_die()

# ── Shared attack helpers ─────────────────────────────────────────────────────

func ring(count: int, spd: float, dmg: float = -1.0, offset: float = 0.0):
	for i in count:
		var a := (TAU / count) * i + offset
		shoot(Vector2(cos(a), sin(a)), spd, dmg)

func aimed_spread(count: int, spread_deg: float, spd: float, dmg: float = -1.0):
	if not is_instance_valid(player):
		return
	var base := direction_to_player().angle()
	for i in count:
		var off := deg_to_rad(spread_deg) * (i - (count - 1) * 0.5)
		var a := base + off
		shoot(Vector2(cos(a), sin(a)), spd, dmg)

func summon(scene_path: String, count: int, spread: float = 120.0):
	var scene = load(scene_path)
	if not scene:
		return
	for i in count:
		var m = scene.instantiate()
		get_parent().add_child(m)
		m.global_position = clamp_to_room(global_position + Vector2(
			randf_range(-spread, spread), randf_range(-spread * 0.6, spread * 0.6)))

# A telegraphed meteor (天降陨石): the impact point is snapped to a grid tile, a dark
# ground shadow grows there as a flaming rock plummets from the sky, and after
# `delay` seconds it lands — damaging the player if still inside the blast radius.
func meteor(target: Vector2, delay: float, radius: float = 58.0, dmg: float = 20.0):
	var parent = get_parent()
	target = _snap_to_tile(target)   # meteors only land on grid cells ("格子")

	# Ground shadow telegraph: a flattened dark disc that grows as the rock falls in.
	# Self-cleans via its own tween so it never lingers even if the boss dies first.
	var shadow := _filled_circle(radius, Color(0.0, 0.0, 0.0, 0.55))
	shadow.global_position = target
	shadow.scale    = Vector2(0.18, 0.10)
	shadow.modulate.a = 0.0
	parent.add_child(shadow)
	var sgrow := shadow.create_tween()
	sgrow.tween_property(shadow, "scale", Vector2(1.0, 0.55), delay)
	sgrow.parallel().tween_property(shadow, "modulate:a", 1.0, delay)
	sgrow.tween_callback(shadow.queue_free)

	# The rock falls in from high above the impact point over the telegraph window.
	var rock := _make_meteor_rock(radius * 0.5)
	rock.global_position = target + Vector2(randf_range(-30, 30), -560)
	parent.add_child(rock)
	var fall := rock.create_tween()
	fall.tween_property(rock, "global_position", target, delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(rock, "rotation", randf_range(2.0, 4.0), delay)
	fall.tween_callback(rock.queue_free)

	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return   # boss gone; shadow/rock already self-cleaned via their tweens
	var pl = GameManager.player_ref
	if is_instance_valid(pl) and pl.has_method("take_damage") \
			and pl.global_position.distance_to(target) <= radius:
		pl.take_damage(dmg)
	# Impact flash + fiery debris.
	var flash := _filled_circle(radius, Color(1.0, 0.7, 0.2, 0.9))
	flash.global_position = target
	parent.add_child(flash)
	var t := flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)
	_meteor_impact_debris(target, radius)

# Snaps a world position to the centre of its grid tile within the parent room.
func _snap_to_tile(world_pos: Vector2) -> Vector2:
	var p = get_parent()
	if p == null or not p.has_method("to_local"):
		return world_pos
	var ts := float(RoomGenerator.TILE_SIZE)
	var local: Vector2 = p.to_local(world_pos)
	var center_local := Vector2(floor(local.x / ts) * ts + ts * 0.5,
							   floor(local.y / ts) * ts + ts * 0.5)
	return p.to_global(center_local)

# World-space centres of every walkable floor tile in the parent room.
func _room_tile_centers() -> Array:
	var p = get_parent()
	if p == null or not ("data" in p):
		return []
	var floors: Array = p.data.get("floors", [])
	var out: Array = []
	for t in floors:
		out.append(p.to_global(RoomGenerator.tile_to_world(t)))
	return out

# Builds a small flaming-rock visual: a fiery halo, a dark rocky core, a hot spot.
func _make_meteor_rock(r: float) -> Node2D:
	var holder := Node2D.new()
	holder.add_child(_filled_circle(r * 1.7, Color(1.0, 0.5, 0.1, 0.45)))
	holder.add_child(_filled_circle(r, Color(0.26, 0.15, 0.09, 1.0)))
	var hot := _filled_circle(r * 0.5, Color(1.0, 0.82, 0.32, 0.9))
	hot.position = Vector2(-r * 0.2, -r * 0.2)
	holder.add_child(hot)
	return holder

func _filled_circle(radius: float, col: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var seg := 16
	for i in seg:
		var a := (TAU / seg) * i
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color = col
	return poly

func _meteor_impact_debris(pos: Vector2, radius: float):
	var parent = get_parent()
	for i in 8:
		var cr := ColorRect.new()
		cr.color = Color(1.0, 0.6, 0.15, 0.9) if i % 2 == 0 else Color(0.5, 0.3, 0.15, 0.9)
		var s := randf_range(5.0, 10.0)
		cr.size = Vector2(s, s)
		cr.global_position = pos - cr.size * 0.5
		parent.add_child(cr)
		var ang := (TAU / 8.0) * i + randf_range(-0.3, 0.3)
		var tw := cr.create_tween()
		tw.tween_property(cr, "global_position", pos + Vector2(cos(ang), sin(ang)) * radius, 0.3)
		tw.parallel().tween_property(cr, "modulate:a", 0.0, 0.3)
		tw.tween_callback(cr.queue_free)

# Rains meteors onto random distinct grid tiles, each with a 3s shadow telegraph,
# leaving only a few safe gaps. Tiles near the player are preferred when available.
func meteor_storm(count: int, spread_x: float = 280.0, spread_y: float = 190.0):
	var tiles: Array = _room_tile_centers()
	if tiles.is_empty():
		# Fallback (no room data): snap random offsets around the player to the grid.
		if not is_instance_valid(player):
			return
		for i in count:
			var off := Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y))
			meteor(player.global_position + off, 3.0, 54.0, 18.0)
		return
	# Prefer tiles within the spread box around the player so the rain stays a threat.
	if is_instance_valid(player):
		var pp: Vector2 = player.global_position
		var near: Array = tiles.filter(func(c):
			return absf(c.x - pp.x) <= spread_x and absf(c.y - pp.y) <= spread_y)
		if near.size() >= count:
			tiles = near
	tiles.shuffle()
	for i in min(count, tiles.size()):
		meteor(tiles[i], 3.0, 54.0, 18.0)

# ── Displacement ───────────────────────────────────────────────────────────────

# A telegraphed leap: the boss hops to `dest` in an arc (with a landing shadow),
# then slams down — a bullet shockwave ring plus melee damage to anyone too close.
func leap_to(dest: Vector2, ring_count: int = 12, ring_spd: float = 210.0, slam_dmg: float = -1.0):
	_displacing = true
	velocity = Vector2.ZERO
	var vis: Node2D = sprite if sprite else body_rect
	var base_scale: Vector2 = vis.scale if is_instance_valid(vis) else Vector2.ONE

	# Reaction window: a landing-zone shadow grows where the boss WILL land, before
	# it leaves the ground, so the player has time to clear out.
	var warn := _filled_circle(60.0, Color(0.95, 0.25, 0.10, 0.0))
	warn.global_position = dest
	warn.scale = Vector2(0.2, 0.12)
	get_parent().add_child(warn)
	var pre := warn.create_tween()
	pre.tween_property(warn, "scale", Vector2(1.0, 0.55), DISPLACE_WINDUP)
	pre.parallel().tween_property(warn, "modulate:a", 0.75, DISPLACE_WINDUP)
	await get_tree().create_timer(DISPLACE_WINDUP).timeout
	if not alive or not is_inside_tree():
		if is_instance_valid(warn): warn.queue_free()
		_displacing = false
		return

	# Leap to the telegraphed spot.
	var t := create_tween()
	t.tween_property(self, "global_position", dest, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(vis):
		t.parallel().tween_property(vis, "scale", base_scale * 1.3, 0.2)
		t.chain().tween_property(vis, "scale", base_scale, 0.18)
	await t.finished
	if is_instance_valid(warn):
		warn.queue_free()
	if not alive or not is_inside_tree():
		_displacing = false
		return
	ring(ring_count, ring_spd)
	var pl = GameManager.player_ref
	var dmg := slam_dmg if slam_dmg >= 0.0 else damage
	if is_instance_valid(pl) and pl.has_method("take_damage") \
			and pl.global_position.distance_to(global_position) <= 95.0:
		pl.take_damage(dmg)
	action_timer = maxf(action_timer, DISPLACE_RECOVERY)   # post-landing window
	_displacing = false

# A blink-teleport to a point offset from the player. Telegraphs the destination
# first (reaction window), fades out, jumps, fades back in, then pauses briefly.
func teleport_to(dest: Vector2):
	_displacing = true
	velocity = Vector2.ZERO
	var vis: Node2D = sprite if sprite else body_rect

	# Reaction window: mark where the boss will reappear before it vanishes.
	var warn := _filled_circle(48.0, Color(0.6, 0.3, 1.0, 0.0))
	warn.global_position = dest
	warn.scale = Vector2(0.3, 0.3)
	get_parent().add_child(warn)
	var pre := warn.create_tween()
	pre.tween_property(warn, "scale", Vector2(1.0, 1.0), DISPLACE_WINDUP)
	pre.parallel().tween_property(warn, "modulate:a", 0.7, DISPLACE_WINDUP)
	await get_tree().create_timer(DISPLACE_WINDUP).timeout
	if not is_inside_tree():
		if is_instance_valid(warn): warn.queue_free()
		_displacing = false
		return

	if is_instance_valid(vis):
		var t := create_tween()
		t.tween_property(vis, "modulate:a", 0.1, 0.14)
		t.tween_callback(func(): global_position = dest)
		t.tween_property(vis, "modulate:a", 1.0, 0.14)
		await t.finished
	else:
		global_position = dest
	if is_instance_valid(warn):
		warn.queue_free()
	action_timer = maxf(action_timer, DISPLACE_RECOVERY)   # post-blink window
	_displacing = false

# ── Vines (from-the-ground hazards) ───────────────────────────────────────────

# A telegraphed patch of disturbed earth that erupts into green vines, damaging the
# player if they're standing over it when the vines burst up.
func vine_erupt(pos: Vector2, delay: float = 0.7, radius: float = 44.0, dmg: float = 16.0):
	var parent = get_parent()
	var warn := ColorRect.new()
	warn.color = Color(0.20, 0.12, 0.05, 0.0)
	warn.size  = Vector2(radius * 2.0, radius * 1.4)
	warn.global_position = pos - warn.size * 0.5
	parent.add_child(warn)
	var wt := warn.create_tween()
	wt.tween_property(warn, "color:a", 0.5, delay)
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		if is_instance_valid(warn):
			warn.queue_free()
		return
	if is_instance_valid(warn):
		warn.queue_free()
	# Vines shoot up out of the ground.
	for i in 5:
		var vine := ColorRect.new()
		vine.color = Color(0.18, 0.55, 0.18, 0.95)
		var vw := randf_range(6.0, 11.0)
		vine.size = Vector2(vw, 4.0)
		var vx := pos.x + randf_range(-radius, radius)
		vine.global_position = Vector2(vx - vw * 0.5, pos.y)
		parent.add_child(vine)
		var h := randf_range(40.0, 72.0)
		var vt := vine.create_tween()
		vt.tween_property(vine, "size:y", h, 0.12).set_ease(Tween.EASE_OUT)
		vt.parallel().tween_property(vine, "global_position:y", pos.y - h, 0.12)
		vt.tween_interval(0.25)
		vt.tween_property(vine, "modulate:a", 0.0, 0.25)
		vt.tween_callback(vine.queue_free)
	var pl = GameManager.player_ref
	if is_instance_valid(pl) and pl.has_method("take_damage") \
			and pl.global_position.distance_to(pos) <= radius:
		pl.take_damage(dmg)

# Erupts a field of vines around the player, leaving small safe gaps to dodge into.
func vine_field(count: int, spread_x: float = 240.0, spread_y: float = 170.0):
	if not is_instance_valid(player):
		return
	var base: Vector2 = player.global_position
	for i in count:
		var off := Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y))
		vine_erupt(base + off, randf_range(0.5, 1.0), 42.0, 15.0)
