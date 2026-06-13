extends Control

@onready var score_label: Label = $Panel/VBox/ScoreLabel
@onready var gold_label:  Label = $Panel/VBox/GoldLabel
@onready var retry_btn:   Button = $Panel/VBox/RetryButton
@onready var menu_btn:    Button = $Panel/VBox/MenuButton

func _ready():
	# Read stats before reset() zeroes them.
	score_label.text = "最终分数: %d" % GameManager.score
	gold_label.text  = "收集金币: %d" % GameManager.gold
	retry_btn.pressed.connect(_on_retry)
	menu_btn.pressed.connect(_on_menu)
	GameManager.reset()

func _on_retry():
	get_tree().change_scene_to_file("res://scenes/levels/Level.tscn")

func _on_menu():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
