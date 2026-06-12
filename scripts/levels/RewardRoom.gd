extends Room
class_name RewardRoom

# Override: reward room has no enemies and presents 3 weapon choices.
# Player picks one with [Enter]; the others disappear; doors open immediately.

const CHOICE_COUNT = 3
const SPREAD_X     = 120.0

var _choices: Array = []  # Array of Area2D weapon choice nodes

func build(template_idx: int = -1, is_boss: bool = false, sublevel: int = 1):
	super.build(template_idx, false, sublevel)
	cleared = true
	_unlock_doors()
	_lock_doors()  # Re-lock until player makes a choice
	await get_tree().process_frame
	_present_choices()

func _present_choices():
	var all_ids = WeaponDatabase.get_all_weapon_ids()
	# Exclude rare weapons from common reward pool
	var common_ids = all_ids.filter(func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	common_ids.shuffle()

	var centre = get_player_start()
	for i in CHOICE_COUNT:
		var id = common_ids[i % common_ids.size()]
		var offset = Vector2((i - 1) * SPREAD_X, -60.0)
		var node = _make_choice_node(id, centre + offset)
		_choices.append(node)
		add_child(node)

	# Banner
	var lbl = Label.new()
	lbl.text = "选择一件武器 [Enter]"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lbl.global_position = centre + Vector2(-120, -130)
	add_child(lbl)

func _make_choice_node(weapon_id: String, pos: Vector2) -> Area2D:
	var w = WeaponDatabase.get_weapon(weapon_id)
	var area = Area2D.new()
	area.add_to_group("weapon_pickup")
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = pos
	area.set_meta("weapon_id", weapon_id)
	area.set_meta("is_reward_choice", true)

	var bg = ColorRect.new()
	bg.color    = w.get("color", Color.WHITE)
	bg.size     = Vector2(36, 36)
	bg.position = Vector2(-18, -18)
	area.add_child(bg)

	var name_lbl = Label.new()
	name_lbl.text = w.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.position = Vector2(-30, -50)
	area.add_child(name_lbl)

	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint.position = Vector2(-18, 22)
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
	var closest_dist = 80.0
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

	# Remove all choices
	for c in _choices:
		if is_instance_valid(c):
			c.queue_free()
	_choices.clear()

	# Open doors now
	cleared = true
	_unlock_doors()
