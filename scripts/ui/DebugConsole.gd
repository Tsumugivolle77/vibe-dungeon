extends CanvasLayer

# Simple debug console. Press "/" to open (the game pauses while typing). Commands:
#   /give <weapon_id>   give the player that weapon
#   /invincible (/god)  toggle invincibility + infinite energy
#   /tp_boss            teleport to this level's boss room

var _input: LineEdit
var _hint: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS   # works while the tree is paused
	layer = 128

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_hint.position = Vector2(42, 18)
	_hint.visible = false
	add_child(_hint)

	_input = LineEdit.new()
	_input.placeholder_text = "/give pistol   |   /invincible   |   /tp_boss"
	_input.anchor_right = 1.0
	_input.offset_left = 40.0
	_input.offset_right = -40.0
	_input.offset_top = 40.0
	_input.offset_bottom = 72.0
	_input.visible = false
	_input.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_input)
	_input.text_submitted.connect(_on_submit)

func _unhandled_input(event: InputEvent):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_SLASH and not _input.visible:
		_open()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _input.visible:
		_close()
		get_viewport().set_input_as_handled()

func _open():
	_input.visible = true
	_input.text = "/"
	_input.grab_focus()
	_input.caret_column = 1
	get_tree().paused = true

func _close():
	_input.visible = false
	_input.release_focus()
	get_tree().paused = false

func _flash(msg: String, ok: bool = true):
	_hint.text = msg
	_hint.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.4))
	_hint.visible = true
	# Show briefly (timer is process-always so it fires even after unpause).
	var t := get_tree().create_timer(2.0, true, false, true)
	t.timeout.connect(func(): if is_instance_valid(_hint): _hint.visible = false)

func _on_submit(text: String):
	var parts := text.strip_edges().split(" ", false)
	_close()
	if parts.is_empty():
		return
	match parts[0]:
		"/give":
			_cmd_give(parts[1] if parts.size() >= 2 else "")
		"/invincible", "/god":
			_cmd_god()
		"/tp_boss":
			_cmd_tp_boss()
		_:
			_flash("未知命令: " + parts[0], false)

func _cmd_give(id: String):
	var pl = GameManager.player_ref
	if not is_instance_valid(pl):
		return
	if id.is_empty() or WeaponDatabase.get_weapon(id).is_empty():
		_flash("无此武器: " + id, false)
		return
	pl.pick_up_weapon(id)
	_flash("已获得 " + id)

func _cmd_god():
	var pl = GameManager.player_ref
	if not is_instance_valid(pl) or not ("debug_god" in pl):
		return
	pl.debug_god = not pl.debug_god
	_flash("无敌模式: " + ("开" if pl.debug_god else "关"))

func _cmd_tp_boss():
	var lvl = get_parent()
	var pl = GameManager.player_ref
	if lvl == null or not ("rooms" in lvl) or not is_instance_valid(pl):
		return
	for i in lvl.rooms.size():
		if i < lvl.room_types.size() and lvl.room_types[i] == "b" and is_instance_valid(lvl.rooms[i]):
			pl.global_position = lvl.rooms[i].get_center_world()
			_flash("已传送到Boss房")
			return
	_flash("未找到Boss房", false)
