extends ShopRoom
class_name StartRoom

# 起点房间 (CLAUDE.md): a small safe room the player spawns into at the start of a
# 关卡. Contains one 自动贩卖机 (vending machine) that sells a random weapon for gold.

func _build_shop():
	var centre = get_player_start()

	var banner = Label.new()
	banner.text = "自动贩卖机  [Enter] 购买随机武器"
	banner.add_theme_font_size_override("font_size", 18)
	banner.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	banner.global_position = centre + Vector2(-150, -150)
	add_child(banner)

	var all_ids = WeaponDatabase.get_all_weapon_ids()
	var common_ids = all_ids.filter(func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	common_ids.shuffle()

	var item = {"kind": "weapon", "id": common_ids[0], "price": 40}
	var node = _make_shop_node(item, centre + Vector2(0, -90))
	_shop_items.append(node)
	add_child(node)
