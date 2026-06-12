extends Control

@onready var start_btn: Button = $VBox/StartButton
@onready var quit_btn: Button  = $VBox/QuitButton
@onready var title_label: Label = $Title

func _ready():
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(_on_quit)
	title_label.text = "元气森林"

func _on_start():
	get_tree().change_scene_to_file("res://scenes/levels/Level.tscn")

func _on_quit():
	get_tree().quit()
