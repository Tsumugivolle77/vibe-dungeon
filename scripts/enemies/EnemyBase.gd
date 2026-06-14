extends CharacterBody2D
class_name EnemyBase

signal died(position: Vector2, xp: int)
signal boss_armor_changed(armor: float, max_armor: float)

@export var max_hp: float      = 50.0
@export var move_speed: float  = 80.0
@export var damage: float      = 10.0
@export var xp_value: int      = 10
@export var gold_drop_min: int = 1
@export var gold_drop_max: int = 4
@export var body_color: Color  = Color(0.6, 0.8, 0.3)
@export var body_size: Vector2 = Vector2(32, 32)

var is_boss_mode: bool = false
var boss_scale: float  = 1.8
var is_elite: bool     = false   # only elite monsters drop energy orbs ("子弹")

# Overall monster damage was raised across the board (CLAUDE batch). Applied to
# non-boss enemies after their stats are set; bosses tune their own numbers.
const ENEMY_DAMAGE_MULT = 1.6

# Overridden true by boss scripts so the damage multiplier / generic contact code
# don't double-apply to them.
func _is_boss_type() -> bool:
	return false

var hp: float     = 0.0
var alive: bool   = true
var knockback_vel: Vector2 = Vector2.ZERO

# ── Boss armor (护甲) ──────────────────────────────────────────────────────────
# Absorbs damage before HP and regenerates like the player's shield. Stays 0 for
# normal monsters (disabled). Breaking it showers the player with energy; powerful
# boss casts refill it and grant brief golden-aegis invulnerability.
const ARMOR_REGEN          = 2.0    # 1/4 of the old regen speed
const ARMOR_RECHARGE_DELAY = 2.0    # delay before regen after a normal hit
const ARMOR_BREAK_DELAY    = 10.0   # no regen for 10s after the armor is broken
var max_armor: float    = 0.0
var armor: float        = 0.0
var _armor_delay: float = 0.0
var _armor_broken: bool = false
var invuln: bool        = false
var _invuln_timer: float = 0.0
var _enraged: bool      = false   # boss below-half-HP form (swapped enraged sprite)

# Swaps the boss to its enraged below-half-HP sprite (a baked recolor of its art).
func _swap_to_berserk_sprite():
	if _enraged or not (sprite is AnimatedSprite2D):
		return
	var base_tex := _get_pixel_texture()
	if base_tex == null:
		return
	_enraged = true
	var asp := sprite as AnimatedSprite2D
	asp.sprite_frames = PixelArt.make_bob_frames(PixelArt.make_enraged(base_tex))
	asp.play("idle")
	asp.modulate = Color.WHITE   # the baked enraged texture now carries the look

# Resting sprite tint restored when invulnerability ends (bosses override).
func _base_tint() -> Color:
	return Color.WHITE

func _tick_armor(delta: float):
	if max_armor <= 0.0:
		return
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			invuln = false
			if is_instance_valid(sprite):
				sprite.modulate = _base_tint()
	if _armor_delay > 0.0:
		_armor_delay -= delta
	elif armor < max_armor:
		armor = minf(max_armor, armor + ARMOR_REGEN * delta)
		if armor > 0.0:
			_armor_broken = false
		emit_signal("boss_armor_changed", armor, max_armor)

# Runs incoming damage through armor; returns the overflow that reaches HP.
func _absorb_with_armor(amount: float) -> float:
	if max_armor <= 0.0 or armor <= 0.0:
		return amount
	_armor_delay = ARMOR_RECHARGE_DELAY
	var absorbed := minf(armor, amount)
	armor -= absorbed
	emit_signal("boss_armor_changed", armor, max_armor)
	if armor <= 0.0 and not _armor_broken:
		_armor_broken = true
		_on_armor_broken()
	return amount - absorbed

# Breaking the boss's armor showers the player with energy ("子弹") and locks armor
# regen for a long window (10s) so the boss stays vulnerable.
func _on_armor_broken():
	_armor_delay = ARMOR_BREAK_DELAY
	for i in 3:
		var off := Vector2(randf_range(-50, 50), randf_range(-50, 50))
		Pickup.spawn(get_parent(), global_position + off, Pickup.Type.AMMO_ORB, 16)

# Fills the armor bar and grants brief invulnerability (golden 护体) for a powerful
# cast — the boss can't be hurt while the aegis is up. Only actually triggers ~1/3
# of the time so the aegis appears at a third of its old frequency.
func cast_guard(duration: float = 2.5):
	if max_armor <= 0.0:
		return
	if randf() > 0.34:
		return
	armor = max_armor
	_armor_broken = false
	emit_signal("boss_armor_changed", armor, max_armor)
	invuln = true
	_invuln_timer = duration
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.9, 1.6, 0.4)   # golden tint
	_spawn_aegis(duration)

func _spawn_aegis(duration: float):
	var aegis := Line2D.new()
	aegis.width = 4.0
	aegis.default_color = Color(1.0, 0.85, 0.2, 0.9)
	aegis.closed = true
	var rad := body_size.x * 0.9
	if is_instance_valid(sprite):
		rad = body_size.x * sprite.scale.x * 0.55
	var seg := 24
	for i in seg:
		var a := TAU * i / seg
		aegis.add_point(Vector2(cos(a), sin(a)) * rad)
	aegis.z_index = 3
	add_child(aegis)
	var tw := aegis.create_tween().set_loops()
	tw.tween_property(aegis, "modulate:a", 0.35, 0.2)
	tw.tween_property(aegis, "modulate:a", 1.0, 0.2)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func(): if is_instance_valid(aegis): aegis.queue_free())

# Floating health bar (created lazily on first hit)
const HP_BAR_W = 32.0
const HP_BAR_H = 4.0
var _hp_bar_bg: ColorRect   = null
var _hp_bar_fill: ColorRect = null

var slow_factor: float = 1.0
var slow_timer:  float = 0.0
var dot_damage:  float = 0.0
var dot_timer:   float = 0.0

var player: Node2D = null
var sprite: Node2D = null  # animated pixel-art overlay (AnimatedSprite2D when art exists)

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hitbox: Area2D               = $Hitbox
@onready var body_rect: ColorRect         = $Body

var enemy_bullet_scene: PackedScene = preload("res://scenes/bullets/EnemyBullet.tscn")

func _ready():
	hp = max_hp
	add_to_group("enemy")
	hitbox.add_to_group("enemy_hitbox")
	body_rect.color   = body_color
	body_rect.size    = body_size
	body_rect.position = -body_size * 0.5

	# Animated pixel sprite overlay (2-frame idle bob) above the ColorRect fallback.
	var tex = _get_pixel_texture()
	if tex:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = PixelArt.make_bob_frames(tex)
		anim.play("idle")
		# Desync each monster's bob so a group doesn't pulse in lockstep.
		anim.frame = randi() % 2
		sprite = anim
		sprite.z_index = 1
		add_child(sprite)
		body_rect.visible = false  # hide plain rect when we have art

	if is_boss_mode:
		_apply_boss_mode()
	_find_player()
	_on_ready_extra()
	# Raise overall monster damage (non-bosses only; bosses set their own values).
	if not _is_boss_type() and not is_boss_mode:
		damage *= ENEMY_DAMAGE_MULT

func _get_pixel_texture() -> ImageTexture:
	return null  # override in subclass

func _apply_boss_mode():
	max_hp  *= 3.0
	hp       = max_hp
	damage  *= 1.5
	scale    = Vector2(boss_scale, boss_scale)
	body_rect.color = body_color.darkened(0.35)

func _find_player():
	var arr = get_tree().get_nodes_in_group("player")
	player  = arr[0] if arr.size() > 0 else null

func _on_ready_extra():
	pass

func _physics_process(delta: float):
	if not alive:
		return
	if not is_instance_valid(player):
		_find_player()
	_tick_status(delta)
	_tick_ai(delta)
	if knockback_vel.length() > 1.0:
		knockback_vel = knockback_vel.lerp(Vector2.ZERO, delta * 8.0)
		velocity = knockback_vel
	move_and_slide()

func _tick_status(delta: float):
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	if dot_timer > 0.0:
		dot_timer -= delta
		take_dot_damage(dot_damage * delta)

# DoT is "true damage": it ignores armor AND boss invulnerability (so damage-over-
# time keeps ticking through a golden aegis) and still updates the boss HP bar.
func take_dot_damage(amount: float):
	if not alive:
		return
	hp -= amount
	_on_hp_changed_external()
	if hp <= 0.0:
		_die()

# Hook so bosses refresh their HP bar when HP changes outside take_damage().
func _on_hp_changed_external():
	pass

func _tick_ai(_delta: float):
	pass

func navigate_to(target_pos: Vector2, _delta: float):
	if not is_instance_valid(nav_agent):
		return
	nav_agent.target_position = target_pos
	if nav_agent.is_navigation_finished():
		return
	var next = nav_agent.get_next_path_position()
	var dir  = (next - global_position).normalized()
	velocity = dir * move_speed * slow_factor
	if knockback_vel.length() > 10.0:
		velocity = knockback_vel

func distance_to_player() -> float:
	return global_position.distance_to(player.global_position) if is_instance_valid(player) else INF

func direction_to_player() -> Vector2:
	return (player.global_position - global_position).normalized() if is_instance_valid(player) else Vector2.ZERO

func shoot(dir: Vector2, spd: float = 200.0, dmg: float = -1.0, props: Dictionary = {}):
	var b: Node = enemy_bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position
	b.direction       = dir.normalized()
	# Small monsters fire slower projectiles (0.8×); bosses keep full speed.
	b.speed           = spd if _is_boss_type() else spd * 0.8
	b.damage          = dmg if dmg >= 0 else damage
	b.is_boss_bullet  = is_boss_mode
	if props.has("kind"):     b.kind = props["kind"]
	if props.has("homing"):   b.homing_strength = props["homing"]
	if props.has("lifetime"): b.lifetime = props["lifetime"]
	if props.has("bounce"):   b.bounces = props["bounce"]

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, _props: Dictionary = {}):
	if not alive:
		return
	hp -= amount
	knockback_vel = knockback
	_flash_hit()
	_update_hp_bar()
	if hp <= 0.0:
		_die()

# Brief red flash on the visible sprite (falls back to the plain rect).
func _flash_hit():
	var target: CanvasItem = sprite if sprite else body_rect
	if not is_instance_valid(target):
		return
	target.modulate = Color(1.8, 0.35, 0.35)
	var t = create_tween()
	t.tween_property(target, "modulate", Color.WHITE, 0.18)

func _ensure_hp_bar():
	if _hp_bar_bg != null:
		return
	var y := -(body_size.y * 0.5 + 10.0)
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color    = Color(0, 0, 0, 0.55)
	_hp_bar_bg.size     = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_bar_bg.position = Vector2(-HP_BAR_W * 0.5, y)
	_hp_bar_bg.z_index  = 5
	add_child(_hp_bar_bg)
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color    = Color(0.3, 0.9, 0.3)
	_hp_bar_fill.size     = Vector2(HP_BAR_W, HP_BAR_H)
	_hp_bar_fill.position = Vector2(-HP_BAR_W * 0.5, y)
	_hp_bar_fill.z_index  = 6
	add_child(_hp_bar_fill)

func _update_hp_bar():
	_ensure_hp_bar()
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar_fill.size  = Vector2(HP_BAR_W * ratio, HP_BAR_H)
	_hp_bar_fill.color = Color(0.95, 0.25, 0.2).lerp(Color(0.3, 0.9, 0.3), ratio)
	_hp_bar_bg.visible   = true
	_hp_bar_fill.visible = true

func apply_dot(dmg_per_sec: float, duration: float):
	dot_damage = dmg_per_sec
	dot_timer  = duration

func apply_slow(factor: float, duration: float):
	slow_factor = factor
	slow_timer  = duration

func _die():
	if not alive:
		return
	alive = false
	emit_signal("died", global_position, xp_value)
	GameManager.add_score(xp_value * 10)

	# Drop gold (reduced) — not every kill drops, and amounts are small.
	var gold_amount = int(randi_range(gold_drop_min, gold_drop_max) * 0.5)
	if is_boss_mode:
		gold_amount *= 2
	if gold_amount > 0:
		for i in min(gold_amount, 3):
			var offset = Vector2(randf_range(-18, 18), randf_range(-18, 18))
			Pickup.spawn(get_parent(), global_position + offset, Pickup.Type.GOLD, ceil(float(gold_amount) / 3.0))

	# Health orbs can drop from anyone (rarer, smaller).
	if randf() < 0.16:
		Pickup.spawn(get_parent(), global_position, Pickup.Type.HEALTH_ORB, 18)
	# Energy orbs ("子弹") drop ONLY from elite monsters (and boss-mode variants),
	# but generously so the player can afford their powerful weapons.
	if (is_elite or is_boss_mode) and randf() < 0.9:
		for i in 2:
			Pickup.spawn(get_parent(), global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14)),
				Pickup.Type.AMMO_ORB, 14)

	$CollisionShape2D.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
	_on_die_extra()

# Clamps a world position to inside the room walls. Used for ALL spawns/drops so
# nothing (loot, summoned minions, split slimes, vines) ever lands off the map.
func clamp_to_room(pos: Vector2) -> Vector2:
	var p := get_parent()
	if p and p.has_method("interior_world_rect"):
		var r: Rect2 = p.interior_world_rect()
		return Vector2(
			clampf(pos.x, r.position.x + 24.0, r.end.x - 24.0),
			clampf(pos.y, r.position.y + 24.0, r.end.y - 24.0))
	return pos

func safe_drop_pos() -> Vector2:
	return clamp_to_room(global_position)

# Spawns an [Enter]-collectable weapon pickup at this enemy's position.
func spawn_weapon_pickup(wid: String):
	var area = Area2D.new()
	area.add_to_group("weapon_pickup")
	area.add_to_group("weapon_display")
	area.collision_layer = 0
	area.collision_mask  = 2
	area.set_meta("weapon_id", wid)
	area.add_child(PixelArt.sprite_from(PixelArt.make_weapon_icon(wid)))
	var lbl = Label.new()
	lbl.text = "★ " + WeaponDatabase.get_weapon(wid).get("name", "?")
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.position = Vector2(-30, -26)
	area.add_child(lbl)
	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 9)
	hint.position = Vector2(-14, 18)
	area.add_child(hint)
	var col = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 20.0
	col.shape = c
	area.add_child(col)
	# Add to the tree BEFORE positioning so global_position isn't re-offset by the
	# room's transform (which previously flung loot far outside the map).
	get_parent().add_child(area)
	area.global_position = safe_drop_pos()

func _on_die_extra():
	pass
