extends CanvasLayer

# Pause overlay. Opens on Esc (ui_cancel) or when the window loses focus / the
# app is backgrounded. Runs while the tree is paused (PROCESS_MODE_ALWAYS) so its
# buttons stay interactive.

var _paused: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	visible = false

func _build_ui():
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	vbox.add_child(title)

	var resume := Button.new()
	resume.text = "继续游戏"
	resume.custom_minimum_size = Vector2(240, 52)
	resume.add_theme_font_size_override("font_size", 20)
	resume.pressed.connect(_on_resume)
	vbox.add_child(resume)

	var menu := Button.new()
	menu.text = "返回主菜单"
	menu.custom_minimum_size = Vector2(240, 52)
	menu.add_theme_font_size_override("font_size", 20)
	menu.pressed.connect(_on_menu)
	vbox.add_child(menu)

func _input(event):
	if event.is_action_pressed("ui_cancel") and _can_pause_state():
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()

func _notification(what):
	# Pause automatically when the window loses focus / the app is backgrounded.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not _paused and _can_pause_state():
			_set_paused(true)

func _can_pause_state() -> bool:
	return GameManager.state == GameManager.GameState.PLAYING \
		or GameManager.state == GameManager.GameState.PAUSED

func _set_paused(p: bool):
	if p == _paused:
		return
	if p and GameManager.state != GameManager.GameState.PLAYING:
		return
	_paused = p
	visible = p
	get_tree().paused = p
	GameManager.state = GameManager.GameState.PAUSED if p else GameManager.GameState.PLAYING

func _on_resume():
	_set_paused(false)

func _on_menu():
	_set_paused(false)
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
