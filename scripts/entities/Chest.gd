extends StaticBody2D
class_name Chest

signal opened

var _interactable: bool = true
var _opened: bool       = false
var _prompt: Label
var _sprite: Sprite2D

func _ready():
	add_to_group("interactable")
	_sprite = PixelArt.sprite_from(PixelArt.make_chest())
	add_child(_sprite)

	_prompt = Label.new()
	_prompt.text = "[Enter] 打开宝箱"
	_prompt.add_theme_font_size_override("font_size", 11)
	_prompt.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_prompt.position = Vector2(-45, -36)
	_prompt.visible  = false
	add_child(_prompt)

	# bounce in
	scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE,       0.08)

func activate():
	_interactable = true

func _process(_delta: float):
	if _opened or not _interactable:
		return
	var player = GameManager.player_ref
	if is_instance_valid(player):
		var near = global_position.distance_to(player.global_position) < 55.0
		_prompt.visible = near

func interact(player: Node2D):
	if _opened or not _interactable:
		return
	_open(player)

func _open(player: Node2D):
	_opened = true
	_prompt.queue_free()
	emit_signal("opened")

	# Flash + shrink lid animation
	var tw = create_tween()
	tw.tween_property(_sprite, "modulate", Color(2, 2, 1, 1), 0.08)
	tw.tween_property(_sprite, "modulate", Color.WHITE,       0.12)

	_scatter_contents(player)

func _scatter_contents(_player: Node2D):
	# Gold (always) – 3-9 coins
	var gold_amount = randi_range(3, 9)
	Pickup.spawn(get_parent(), global_position, Pickup.Type.GOLD, gold_amount)

	# Ammo orbs (always) – 2 orbs
	for i in 2:
		Pickup.spawn(get_parent(), global_position + Vector2(randf_range(-26, 26), randf_range(-26, 26)),
			Pickup.Type.AMMO_ORB, 20)

	# Health pack (30% chance)
	if randf() < 0.3:
		Pickup.spawn(get_parent(), global_position + Vector2(randf_range(-25,25), -20),
			Pickup.Type.HEALTH_PACK, 40)

	# Ammo pack (20% chance)
	if randf() < 0.2:
		Pickup.spawn(get_parent(), global_position + Vector2(randf_range(-25,25), 20),
			Pickup.Type.AMMO_PACK, 0)

	# Random common weapon (30% chance) — never rare/boss-exclusive
	if randf() < 0.30:
		var ids = WeaponDatabase.get_all_weapon_ids().filter(
			func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
		_spawn_weapon_pickup(ids[randi() % ids.size()])

	# Destroy chest visual
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree():
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)

func _spawn_weapon_pickup(weapon_id: String):
	var area = Area2D.new()
	area.add_to_group("weapon_pickup")
	area.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20))

	var spr  = PixelArt.sprite_from(PixelArt.make_weapon_icon(weapon_id))
	area.add_child(spr)

	var lbl  = Label.new()
	lbl.text = WeaponDatabase.get_weapon(weapon_id).get("name", "?")
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	lbl.position = Vector2(-24, -22)
	area.add_child(lbl)

	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 9)
	hint.position = Vector2(-14, -34)
	area.add_child(hint)

	var col  = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 18.0
	col.shape   = circ
	area.add_child(col)
	area.collision_layer = 0
	area.collision_mask  = 2
	area.set_meta("weapon_id", weapon_id)
	get_parent().add_child(area)
