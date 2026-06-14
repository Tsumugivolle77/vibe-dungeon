extends ShopRoom
class_name StartRoom

# 起点房间 (CLAUDE.md): a small safe room the player spawns into at the start of a
# 关卡. Contains one 自动贩卖机 (vending machine) in the TOP-RIGHT corner that sells a
# random weapon for a small fee (10 gold). The sold item is NOT displayed; the
# price/prompt text only appears when the player stands near the machine.

var _vend: Node2D = null
var _vend_text: Node2D = null   # holder for the proximity-only labels

func _build_shop():
	var w := float(data.cols) * TILE_SIZE
	# Top-right interior corner, inset from the walls.
	var pos := Vector2(w - TILE_SIZE * 1.6, TILE_SIZE * 1.6)

	var all_ids = WeaponDatabase.get_all_weapon_ids()
	var common = all_ids.filter(func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	common.shuffle()
	var item = {"kind": "weapon", "id": common[0], "price": 10}

	var node = Node2D.new()
	node.add_to_group("shop_item")
	node.position = pos
	node.set_meta("shop_data", item)
	node.add_child(PixelArt.sprite_from(PixelArt.make_vending_machine()))

	# Proximity-only text (hidden until the player approaches).
	var text = Node2D.new()
	text.visible = false
	var title = Label.new()
	title.text = "自动贩卖机"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	title.position = Vector2(-34, -54)
	text.add_child(title)
	var price = Label.new()
	price.text = "随机武器  $10  [Enter]"
	price.add_theme_font_size_override("font_size", 11)
	price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	price.position = Vector2(-54, 34)
	text.add_child(price)
	node.add_child(text)

	add_child(node)
	_shop_items.append(node)
	_vend = node
	_vend_text = text

func _process(_delta: float):
	if not is_instance_valid(_vend):
		return
	var pl = GameManager.player_ref
	var near: bool = is_instance_valid(pl) and pl.global_position.distance_to(_vend.global_position) < 95.0
	# Reveal the machine's text only when the player is close.
	if is_instance_valid(_vend_text):
		_vend_text.visible = near
	# Repeatable purchase: each buy dispenses a random weapon from the FULL pool.
	# (We handle it here instead of ShopRoom._process so the machine isn't consumed.)
	if near and Input.is_action_just_pressed("ui_accept") \
			and pl.global_position.distance_to(_vend.global_position) < 70.0:
		_buy_random_weapon(pl)

func _buy_random_weapon(pl: Node):
	if not GameManager.spend_gold(10):
		var t := _vend.create_tween()
		t.tween_property(_vend, "modulate", Color(1, 0.3, 0.3), 0.1)
		t.tween_property(_vend, "modulate", Color.WHITE, 0.2)
		return
	# Full pool: every weapon, including rare/boss-exclusive ones.
	var ids := WeaponDatabase.get_all_weapon_ids()
	var id: String = ids[randi() % ids.size()]
	if pl.has_method("pick_up_weapon"):
		pl.pick_up_weapon(id)
	_show_vend_result(WeaponDatabase.get_weapon(id).get("name", "?"))

func _show_vend_result(wname: String):
	var lbl := Label.new()
	lbl.text = "获得 " + wname + "!"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	lbl.position = _vend.position + Vector2(-40, -78)
	add_child(lbl)
	var t := lbl.create_tween()
	t.tween_property(lbl, "position:y", lbl.position.y - 26, 0.9)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
	t.tween_callback(lbl.queue_free)
