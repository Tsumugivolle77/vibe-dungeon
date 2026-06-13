extends Room
class_name ShopRoom

# Shop room: no enemies, sell weapons/health packs/ammo packs for gold.
# Items displayed in the room; player approaches and presses [Enter] to buy.

const ITEM_SPREAD_X = 110.0

var _shop_items: Array = []

func build(spec: Dictionary, sublevel: int):
	super.build(spec, sublevel)
	cleared = true
	await get_tree().process_frame
	_build_shop()

func _build_shop():
	var centre = get_player_start()

	# Banner
	var banner = Label.new()
	banner.text = "★ 商店 ★  [Enter] 购买"
	banner.add_theme_font_size_override("font_size", 20)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	banner.global_position = centre + Vector2(-150, -180)
	add_child(banner)

	# 2 random weapons + health pack + ammo pack
	var all_ids = WeaponDatabase.get_all_weapon_ids()
	var common_ids = all_ids.filter(func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	common_ids.shuffle()

	var items = []
	items.append({"kind": "weapon", "id": common_ids[0], "price": 50})
	items.append({"kind": "weapon", "id": common_ids[1], "price": 50})
	items.append({"kind": "health_pack", "id": "",        "price": 20})
	items.append({"kind": "ammo_pack",   "id": "",        "price": 15})

	for i in items.size():
		var offset = Vector2((i - 1.5) * ITEM_SPREAD_X, -80.0)
		var node = _make_shop_node(items[i], centre + offset)
		_shop_items.append(node)
		add_child(node)

func _make_shop_node(item: Dictionary, pos: Vector2) -> Node2D:
	var container = Node2D.new()
	container.add_to_group("shop_item")
	container.global_position = pos
	container.set_meta("shop_data", item)
	container.set_script(null)  # vanilla Node2D, buy() added below

	var color: Color
	var display_name: String
	match item.kind:
		"weapon":
			var w = WeaponDatabase.get_weapon(item.id)
			color        = w.get("color", Color.WHITE)
			display_name = w.get("name", "?")
		"health_pack":
			color        = Color(0.9, 0.15, 0.15)
			display_name = "血包"
		"ammo_pack":
			color        = Color(0.2, 0.5, 0.9)
			display_name = "能量包"

	var bg = ColorRect.new()
	bg.color    = color
	bg.size     = Vector2(38, 38)
	bg.position = Vector2(-19, -19)
	container.add_child(bg)

	var name_lbl = Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.position = Vector2(-28, -58)
	container.add_child(name_lbl)

	var price_lbl = Label.new()
	price_lbl.text = "$ %d" % item.price
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	price_lbl.position = Vector2(-16, 24)
	container.add_child(price_lbl)

	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.position = Vector2(-18, 44)
	container.add_child(hint)

	return container

func _process(_delta: float):
	if not Input.is_action_just_pressed("ui_accept"):
		return
	var player = GameManager.player_ref
	if not is_instance_valid(player):
		return

	for item_node in _shop_items:
		if not is_instance_valid(item_node):
			continue
		if player.global_position.distance_to(item_node.global_position) > 65.0:
			continue
		var data: Dictionary = item_node.get_meta("shop_data", {})
		if data.is_empty():
			continue
		_try_buy(player, item_node, data)
		break

func _try_buy(player: Node, item_node: Node2D, data: Dictionary):
	var price: int = data.get("price", 999)
	if not GameManager.spend_gold(price):
		_flash_insufficient(item_node)
		return

	match data.kind:
		"weapon":
			if player.has_method("pick_up_weapon"):
				player.pick_up_weapon(data.id)
		"health_pack":
			if player.has_method("heal"):
				player.heal(40)
		"ammo_pack":
			if player.has_method("restore_energy"):
				player.restore_energy(60)

	item_node.queue_free()
	_shop_items.erase(item_node)

func _flash_insufficient(item_node: Node2D):
	var t = item_node.create_tween()
	t.tween_property(item_node, "modulate", Color(1, 0.2, 0.2), 0.1)
	t.tween_property(item_node, "modulate", Color.WHITE, 0.2)
