extends Room
class_name RewardRoom

# Override: reward room has no enemies and presents 3 weapon choices.
# Player picks one with [Enter]; the others disappear; doors open immediately.

const CHOICE_COUNT = 3
const SPREAD_X     = 120.0

var _choices: Array = []  # Array of Area2D weapon choice nodes

func build(spec: Dictionary, sublevel: int):
	super.build(spec, sublevel)
	cleared = true
	await get_tree().process_frame
	_present_choices()

func _present_choices():
	var all_ids = WeaponDatabase.get_all_weapon_ids()
	var common_ids = all_ids.filter(func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	common_ids.shuffle()

	var centre = get_player_start()
	for i in CHOICE_COUNT:
		var id = common_ids[i % common_ids.size()]
		var offset = Vector2((i - 1) * SPREAD_X, -60.0)
		var node = _make_choice_node(id, centre + offset)
		_choices.append(node)
		add_child(node)

	var lbl = Label.new()
	lbl.text = "选择一件武器 [Enter]"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lbl.global_position = centre + Vector2(-120, -130)
	add_child(lbl)

func _make_choice_node(weapon_id: String, pos: Vector2) -> Area2D:
	var w = WeaponDatabase.get_weapon(weapon_id)
	var area = Area2D.new()
	# NOT in "weapon_pickup" group so Player._try_pickup_weapon() ignores it;
	# RewardRoom._process owns the full pick-then-cleanup sequence.
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = pos
	area.set_meta("weapon_id", weapon_id)

	var icon_spr = PixelArt.sprite_from(PixelArt.make_weapon_icon(weapon_id))
	area.add_child(icon_spr)

	var name_lbl = Label.new()
	name_lbl.text = w.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.position = Vector2(-30, -26)
	area.add_child(name_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "耗能 %d/次" % w.get("energy_cost", 0)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	cost_lbl.position = Vector2(-28, -12)
	area.add_child(cost_lbl)

	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint.position = Vector2(-18, 20)
	area.add_child(hint)

	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	col.shape = rect
	area.add_child(col)

	return area

func _process(_delta: float):
	if _choices.is_empty():
		return
	if not Input.is_action_just_pressed("ui_accept"):
		return

	var player = GameManager.player_ref
	if not is_instance_valid(player):
		return

	var closest: Area2D = null
	var closest_dist = 90.0
	for c in _choices:
		if not is_instance_valid(c):
			continue
		var d = player.global_position.distance_to(c.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = c

	if not is_instance_valid(closest):
		return

	var chosen_id: String = closest.get_meta("weapon_id", "")
	if not chosen_id.is_empty() and player.has_method("pick_up_weapon"):
		player.pick_up_weapon(chosen_id)

	# Free all choices (including the chosen one) now that pickup is done
	for c in _choices:
		if is_instance_valid(c):
			c.queue_free()
	_choices.clear()

	cleared = true
	_unlock_doors()
