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

# CLAUDE.md: boss body should be ~4× a normal monster. A normal enemy sprite is
# ~9 cols × SCALE(3) ≈ 27px; a boss sprite (~13 cols ≈ 39px) × 2.8 ≈ 109px ≈ 4×.
@export var boss_sprite_scale: float = 2.8

var phase: int          = 1
var berserk: bool       = false
var action_timer: float = 1.5
var _drop_timer: float  = 3.0
var boss_drop_weapon: String = ""   # boss-exclusive rare dropped on death

func _on_ready_extra():
	# Subclass should call super() AFTER setting stats so the sprite scales correctly.
	if sprite:
		sprite.scale = Vector2(boss_sprite_scale, boss_sprite_scale)
	# Emit once so the HUD boss bar initialises to full.
	emit_signal("boss_hp_changed", hp, max_hp)

func _tick_ai(delta: float):
	# CLAUDE.md: only drop ammo ("子弹") while berserk (below half HP); none above.
	if berserk:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			_drop_timer = 2.5
			_boss_drop()

	action_timer -= delta

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

# Berserk: permanent angry-red tint + an immediate retaliatory bullet nova.
func _enter_berserk():
	berserk = true
	if sprite:
		sprite.modulate = _tint()
	ring(16, 220.0)

func _tint() -> Color:
	return Color(1.5, 0.7, 0.7) if berserk else Color.WHITE

func _on_phase(_p: int):
	pass

# Below half HP the boss spews a few energy orbs ("子弹") for the player.
func _boss_drop():
	for s in [Vector2(-70, 0), Vector2(70, 0), Vector2(0, 70), Vector2(0, -70)]:
		Pickup.spawn(get_parent(), global_position + s, Pickup.Type.AMMO_ORB, 16)
	if randf() < 0.4:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 10)

# Drop the boss-exclusive rare weapon on death.
func _on_die_extra():
	if boss_drop_weapon != "":
		spawn_weapon_pickup(boss_drop_weapon)

# Bosses ignore knockback and report HP changes to the boss bar.
func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	hp -= amount
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
		m.global_position = global_position + Vector2(
			randf_range(-spread, spread), randf_range(-spread * 0.6, spread * 0.6))

# A telegraphed meteor: a warning circle grows at `target`, then after `delay`
# it impacts, damaging the player if still inside the blast radius.
func meteor(target: Vector2, delay: float, radius: float = 58.0, dmg: float = 20.0):
	var warn := ColorRect.new()
	warn.color    = Color(0.95, 0.25, 0.10, 0.22)
	warn.size     = Vector2(radius * 2, radius * 2)
	warn.global_position = target - Vector2(radius, radius)
	get_parent().add_child(warn)
	var grow := warn.create_tween()
	grow.tween_property(warn, "modulate:a", 2.2, delay)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(warn):
		return
	var pl = GameManager.player_ref
	if is_instance_valid(pl) and pl.has_method("take_damage") \
			and pl.global_position.distance_to(target) <= radius:
		pl.take_damage(dmg)
	warn.color = Color(1.0, 0.7, 0.2, 0.9)
	var t := warn.create_tween()
	t.tween_property(warn, "modulate:a", 0.0, 0.3)
	t.tween_callback(warn.queue_free)

# Rains meteors across a wide area around the player, leaving a few safe gaps.
func meteor_storm(count: int, spread_x: float = 280.0, spread_y: float = 190.0):
	if not is_instance_valid(player):
		return
	var base: Vector2 = player.global_position
	for i in count:
		var off := Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y))
		meteor(base + off, randf_range(0.6, 1.3), 54.0, 18.0)
