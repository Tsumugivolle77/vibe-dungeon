extends Room
class_name ExitRoom

signal exit_entered

var _sublevel_dest: int = 2

func build(template_idx: int = -1, is_boss: bool = false, sublevel: int = 1):
	_sublevel_dest = sublevel + 1
	super.build(template_idx, false, sublevel)
	cleared = true
	_unlock_doors()
	await get_tree().process_frame
	_spawn_portal()

func _spawn_portal():
	var centre = get_player_start()

	# Portal visual – glowing animated ring
	var portal_node = Node2D.new()
	portal_node.global_position = centre + Vector2(0, -60)
	add_child(portal_node)

	var ring = ColorRect.new()
	ring.color    = Color(0.25, 0.75, 1.0, 0.85)
	ring.size     = Vector2(52, 52)
	ring.position = Vector2(-26, -26)
	portal_node.add_child(ring)

	var inner = ColorRect.new()
	inner.color    = Color(0.05, 0.05, 0.25, 0.9)
	inner.size     = Vector2(36, 36)
	inner.position = Vector2(-18, -18)
	portal_node.add_child(inner)

	var dest_lbl = Label.new()
	dest_lbl.text = "第 %d 关" % _sublevel_dest
	dest_lbl.add_theme_font_size_override("font_size", 14)
	dest_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	dest_lbl.position = Vector2(-22, -52)
	portal_node.add_child(dest_lbl)

	var hint_lbl = Label.new()
	hint_lbl.text = "踏入传送门"
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hint_lbl.position = Vector2(-28, 32)
	portal_node.add_child(hint_lbl)

	# Bobbing animation
	var tw = portal_node.create_tween().set_loops()
	tw.tween_property(portal_node, "position:y", portal_node.position.y - 8, 1.0).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(portal_node, "position:y", portal_node.position.y,     1.0).set_ease(Tween.EASE_IN_OUT)

	# Glow pulse
	var glow_tw = ring.create_tween().set_loops()
	glow_tw.tween_property(ring, "modulate:a", 0.5, 0.8)
	glow_tw.tween_property(ring, "modulate:a", 1.0, 0.8)

	# Collision area
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = portal_node.global_position
	var col = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 28.0
	col.shape = circ
	area.add_child(col)
	area.body_entered.connect(_on_portal_body)
	add_child(area)

func _on_portal_body(body: Node2D):
	if body.is_in_group("player"):
		emit_signal("exit_entered")
