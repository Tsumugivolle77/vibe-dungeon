extends Node

signal game_over
signal level_completed
signal sublevel_completed
signal score_changed(new_score: int)
signal gold_changed(new_gold: int)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, WIN }

var state: GameState = GameState.MENU
var current_sublevel: int = 1
var total_sublevels: int  = 5
var score: int = 0
var gold:  int = 0
var player_ref: Node = null

# Pause is owned by PauseMenu (handles Esc + focus-out + the overlay UI).

func start_game():
	state = GameState.PLAYING
	current_sublevel = 1
	score = 0
	gold  = 0
	emit_signal("score_changed", score)
	emit_signal("gold_changed",  gold)

func on_player_died():
	if state == GameState.GAME_OVER:
		return
	state = GameState.GAME_OVER
	emit_signal("game_over")

func on_room_cleared():
	pass

func on_sublevel_cleared():
	current_sublevel += 1
	if current_sublevel > total_sublevels:
		state = GameState.WIN
		emit_signal("level_completed")
	else:
		emit_signal("sublevel_completed")

func add_score(points: int):
	score += points
	emit_signal("score_changed", score)

func add_gold(amount: int):
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true

func toggle_pause():
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		get_tree().paused = true
	elif state == GameState.PAUSED:
		state = GameState.PLAYING
		get_tree().paused = false

func reset():
	state = GameState.MENU
	current_sublevel = 1
	score = 0
	gold  = 0
	player_ref = null
	get_tree().paused = false
