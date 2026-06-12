extends Node2D

signal boss_hp_changed(hp: float, max_hp: float)

# Room sequence per sublevel (not counting boss room at the end).
# "c"=combat  "r"=reward  "s"=shop
const SUBLEVEL_SEQUENCES = {
	1: ["c", "c", "r", "c"],
	2: ["c", "c", "r", "c", "s"],
	3: ["c", "c", "r", "c", "c", "s"],
	4: ["c", "r", "c", "c", "s", "c"],
	5: ["c", "r", "c", "c", "s", "c", "c"],
}
const MAX_SUBLEVEL = 5

var current_room: Room        = null
var room_idx: int             = 0
var sublevel_idx: int         = 1
var _in_exit_room: bool       = false
var player: CharacterBody2D   = null

@onready var hud: CanvasLayer = $HUD

var player_scene:   PackedScene = preload("res://scenes/player/Player.tscn")
var room_scene:     PackedScene = preload("res://scenes/levels/Room.tscn")
var reward_scene:   PackedScene = preload("res://scenes/levels/RewardRoom.tscn")
var shop_scene:     PackedScene = preload("res://scenes/levels/ShopRoom.tscn")
var exit_scene:     PackedScene = preload("res://scenes/levels/ExitRoom.tscn")

const ROOM_CLEAR_HEAL = 20
const ROOM_CLEAR_AMMO = 0.4

func _ready():
	GameManager.game_over.connect(_on_game_over)
	GameManager.start_game()
	_spawn_player()
	_load_next_room(true)

func _spawn_player():
	player = player_scene.instantiate()
	add_child(player)
	player.health_changed.connect(hud._on_health_changed)
	player.weapon_changed.connect(hud._on_weapon_changed)
	player.ammo_changed.connect(hud._on_ammo_changed)
	player.skill_activated.connect(hud._on_skill_activated)
	player.skill_cooldown.connect(hud._on_skill_cooldown)
	player.died.connect(_on_player_died)
	player.weapon_dropped.connect(_on_weapon_dropped)

# ── Room loading ──────────────────────────────────────────────────────────────

func _load_next_room(_first: bool = false):
	_in_exit_room = false

	if is_instance_valid(current_room):
		current_room.queue_free()
		current_room = null

	var seq: Array  = SUBLEVEL_SEQUENCES.get(sublevel_idx, SUBLEVEL_SEQUENCES[1])
	var is_boss     = (room_idx >= seq.size())
	var room_type   = "b" if is_boss else seq[room_idx]

	match room_type:
		"b":
			current_room = room_scene.instantiate() as Room
			add_child(current_room)
			current_room.build(-1, true, sublevel_idx)
			if not boss_hp_changed.is_connected(hud._on_boss_hp_changed):
				boss_hp_changed.connect(hud._on_boss_hp_changed)
			hud.show_boss_bar(true)
			hud.show_sublevel_title("曼陀罗花 BOSS")
		"r":
			current_room = reward_scene.instantiate() as Room
			add_child(current_room)
			current_room.build(-1, false, sublevel_idx)
			hud.show_sublevel_title("奖励房间")
		"s":
			current_room = shop_scene.instantiate() as Room
			add_child(current_room)
			current_room.build(-1, false, sublevel_idx)
			hud.show_sublevel_title("商店")
		_:
			current_room = room_scene.instantiate() as Room
			add_child(current_room)
			current_room.build(-1, false, sublevel_idx)
			hud.show_sublevel_title("第%d关  第%d室" % [sublevel_idx, room_idx + 1])

	current_room.all_enemies_dead.connect(_on_room_cleared)
	current_room.door_entered.connect(_on_door_entered)

	if is_instance_valid(player):
		player.global_position = current_room.get_player_start()
		player.z_index = 1

	if room_type == "c":
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(current_room):
			current_room.spawn_enemies(0.1 * sublevel_idx)

func _load_exit_room():
	_in_exit_room = true

	if is_instance_valid(current_room):
		current_room.queue_free()
		current_room = null

	hud.show_boss_bar(false)

	var exit_room: Room = exit_scene.instantiate() as Room
	add_child(exit_room)
	exit_room.build(-1, false, sublevel_idx)
	exit_room.connect("exit_entered", _on_exit_entered)
	current_room = exit_room

	if is_instance_valid(player):
		player.global_position = exit_room.get_player_start()
		player.z_index = 1

	hud.show_sublevel_title("第%d关通关！进入传送门前往第%d关" % [sublevel_idx, sublevel_idx + 1])

# ── Event handlers ────────────────────────────────────────────────────────────

func _on_door_entered(_direction: String):
	if _in_exit_room:
		return  # exit room uses portal, not doors
	if is_instance_valid(current_room) and current_room.is_boss_room:
		_load_exit_room()
	else:
		room_idx += 1
		_load_next_room()

func _on_exit_entered():
	sublevel_idx += 1
	room_idx      = 0
	if sublevel_idx > MAX_SUBLEVEL:
		# All sublevels cleared – game win is handled by GameManager
		return
	_load_next_room(true)

func _on_room_cleared():
	if is_instance_valid(current_room) and current_room.is_boss_room:
		GameManager.on_room_cleared()
		return  # boss room rewards come after the exit room
	GameManager.on_room_cleared()
	_grant_room_rewards()
	_maybe_drop_weapon()

func _grant_room_rewards():
	if not is_instance_valid(player):
		return
	player.heal(ROOM_CLEAR_HEAL)
	for id in player.weapon_ids:
		var w = WeaponDatabase.weapons.get(id)
		if w and w.get("type") == "ranged":
			w.ammo = min(w.ammo_max, w.get("ammo", 0) + int(ceil(w.ammo_max * ROOM_CLEAR_AMMO)))
	player._equip(player.weapon_ids[player.weapon_idx])
	_spawn_reward_label(player.global_position)

func _spawn_reward_label(pos: Vector2):
	var lbl = Label.new()
	lbl.text = "+%d HP  弹药补充" % ROOM_CLEAR_HEAL
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))
	lbl.global_position = pos + Vector2(-60, -60)
	add_child(lbl)
	var t = lbl.create_tween()
	t.tween_property(lbl, "position:y", lbl.position.y - 50, 1.2)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	t.tween_callback(lbl.queue_free)

func _maybe_drop_weapon():
	if randf() > 0.4 or not is_instance_valid(current_room):
		return
	var floors = current_room.get_floor_tiles()
	if floors.is_empty():
		return
	floors.shuffle()
	_create_pickup_node(_random_common_weapon(), RoomGenerator.tile_to_world(floors[0]))

func _random_common_weapon() -> String:
	var ids = WeaponDatabase.get_all_weapon_ids().filter(
		func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	return ids[randi() % ids.size()]

func _on_weapon_dropped(weapon_id: String, pos: Vector2):
	_create_pickup_node(weapon_id, pos)

func _create_pickup_node(weapon_id: String, pos: Vector2):
	var w    = WeaponDatabase.get_weapon(weapon_id)
	var area = Area2D.new()
	area.add_to_group("weapon_pickup")
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = pos
	area.set_meta("weapon_id", weapon_id)

	var vis = ColorRect.new()
	vis.color    = w.get("color", Color.WHITE)
	vis.size     = Vector2(28, 28)
	vis.position = Vector2(-14, -14)
	area.add_child(vis)

	var name_lbl = Label.new()
	name_lbl.text = w.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.position = Vector2(-22, -44)
	area.add_child(name_lbl)

	var hint = Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.position = Vector2(-16, 18)
	area.add_child(hint)

	var col  = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 20.0
	col.shape   = circ
	area.add_child(col)

	add_child(area)

func _on_player_died():
	hud.show_game_over()

func _on_game_over():
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
