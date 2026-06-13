extends Node2D

signal boss_hp_changed(hp: float, max_hp: float)

# A 关卡 (level) is a chain of rooms connected by corridors (roads). The player
# spawns in a small start room, fights through combat/reward/shop rooms, and ends
# at the boss room. Rooms are placed left-to-right, all vertically centred on a
# shared axis so their edge-midpoint doors line up with straight roads.
#
# Sequences below are the MIDDLE rooms; "v" start room is the first entry and the
# boss room is appended automatically. "v"=start "c"=combat "r"=reward "s"=shop
const SUBLEVEL_SEQUENCES = {
	1: ["v", "c", "c", "r", "c"],
	2: ["v", "c", "c", "r", "c", "s"],
	3: ["v", "c", "c", "r", "c", "c", "s"],
	4: ["v", "c", "r", "c", "c", "s", "c"],
	5: ["v", "c", "r", "c", "c", "s", "c", "c"],
}
const MAX_SUBLEVEL = 5

const BOSS_NAMES = {
	1: "哥布林王", 2: "史莱姆之母", 3: "远古树妖", 4: "精灵女王", 5: "曼陀罗花",
}

# Room sizes in tiles (cols × rows). Start room is small & square.
const ROOM_SIZES = {
	"v": Vector2i(7, 7),
	"c": Vector2i(13, 9),
	"r": Vector2i(11, 9),
	"s": Vector2i(13, 9),
	"b": Vector2i(17, 13),
}

const TILE          = RoomGenerator.TILE_SIZE
const CENTER_Y      = 0.0           # shared horizontal axis all rooms centre on
const CORRIDOR_LEN  = 3 * TILE      # gap between adjacent rooms (road length)
const ROAD_COLOR    = Color(0.34, 0.32, 0.30)
const ROAD_COLOR_2  = Color(0.28, 0.26, 0.25)

const ROOM_CLEAR_HEAL   = 20
const ROOM_CLEAR_ENERGY = 30

var rooms:          Array = []
var room_types:     Array = []
var room_activated: Array = []
var sublevel_idx:   int   = 1
var _current_gen:   int   = 0

var player: CharacterBody2D = null

@onready var hud: CanvasLayer = $HUD

var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
var room_scene:   PackedScene = preload("res://scenes/levels/Room.tscn")
var reward_scene: PackedScene = preload("res://scenes/levels/RewardRoom.tscn")
var shop_scene:   PackedScene = preload("res://scenes/levels/ShopRoom.tscn")
var start_scene:  PackedScene = preload("res://scenes/levels/StartRoom.tscn")

# ── Lifecycle ─────────────────────────────────────────────────────────────────

var pause_menu_scene: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")

func _ready():
	GameManager.game_over.connect(_on_game_over)
	GameManager.start_game()
	add_child(pause_menu_scene.instantiate())
	_spawn_player()
	if not boss_hp_changed.is_connected(hud._on_boss_hp_changed):
		boss_hp_changed.connect(hud._on_boss_hp_changed)
	_load_sublevel(1)

func _process(_delta: float):
	if not is_instance_valid(player) or rooms.is_empty():
		return
	for i in rooms.size():
		if room_activated[i]:
			continue
		var room: Room = rooms[i]
		if not is_instance_valid(room):
			continue
		if room.interior_world_rect().has_point(player.global_position):
			_activate_room(i)
			break

func _spawn_player():
	player = player_scene.instantiate()
	add_child(player)
	player.health_changed.connect(hud._on_health_changed)
	player.weapon_changed.connect(hud._on_weapon_changed)
	player.energy_changed.connect(hud._on_energy_changed)
	player.skill_activated.connect(hud._on_skill_activated)
	player.skill_cooldown.connect(hud._on_skill_cooldown)
	player.died.connect(_on_player_died)
	player.weapon_dropped.connect(_on_weapon_dropped)
	hud._on_health_changed(player.hp, player.max_hp)
	hud._on_weapon_changed(player.weapon)
	hud._on_energy_changed(player.energy, player.MAX_ENERGY)

# ── Sublevel build ────────────────────────────────────────────────────────────

func _load_sublevel(idx: int):
	sublevel_idx = idx
	_current_gen += 1
	var gen := _current_gen

	for c in get_children():
		if c is Room or c.is_in_group("level_geometry"):
			c.queue_free()
	rooms.clear()
	room_types.clear()
	room_activated.clear()

	var seq: Array = SUBLEVEL_SEQUENCES.get(idx, SUBLEVEL_SEQUENCES[1])
	var types: Array = seq + ["b"]

	var x_cursor := 0.0
	for i in types.size():
		var t: String = types[i]
		var size: Vector2i = ROOM_SIZES.get(t, ROOM_SIZES["c"])
		var spec := {
			"type": _type_name(t),
			"cols": size.x,
			"rows": size.y,
			"doors": {
				"left":  i > 0,
				"right": i < types.size() - 1,
				"up": false, "down": false,
			},
		}

		var room: Room = _instantiate_room(t)
		add_child(room)
		# Vertically centre so the door midpoint sits on CENTER_Y.
		room.position = Vector2(x_cursor, CENTER_Y - (size.y / 2) * TILE)
		room.build(spec, idx)

		var ridx := i
		var snap_gen := gen
		room.all_enemies_dead.connect(func():
			if _current_gen == snap_gen:
				_on_room_cleared(ridx))

		rooms.append(room)
		room_types.append(t)
		room_activated.append(false)

		x_cursor += size.x * TILE
		if i < types.size() - 1:
			_build_corridor(x_cursor, x_cursor + CORRIDOR_LEN)
			x_cursor += CORRIDOR_LEN

	# Place the player in the centre of the start room.
	if is_instance_valid(player) and rooms.size() > 0:
		player.global_position = rooms[0].get_center_world()
		player.z_index = 1

	hud.show_boss_bar(false)
	hud.show_sublevel_title("第 %d 关" % idx)

func _type_name(code: String) -> String:
	match code:
		"v": return "start"
		"c": return "combat"
		"r": return "reward"
		"s": return "shop"
		"b": return "boss"
	return "combat"

func _instantiate_room(code: String) -> Room:
	match code:
		"v": return start_scene.instantiate()  as Room
		"r": return reward_scene.instantiate() as Room
		"s": return shop_scene.instantiate()   as Room
		_:   return room_scene.instantiate()    as Room

# ── Corridors (roads) ─────────────────────────────────────────────────────────

# Carves a 2-tile-tall stone-brick road between x_start and x_end at CENTER_Y,
# walled above and below so it stays enclosed.
func _build_corridor(x_start: float, x_end: float):
	var holder = Node2D.new()
	holder.add_to_group("level_geometry")
	add_child(holder)

	var tx0 := int(round(x_start / TILE))
	var tx1 := int(round(x_end / TILE))
	var cy  := int(round(CENTER_Y / TILE))   # 0
	# Road floor occupies tile rows cy-1 and cy (spanning [-TILE, +TILE] around CENTER_Y).
	for tx in range(tx0, tx1):
		for ty in [cy - 1, cy]:
			var cr = ColorRect.new()
			cr.color    = ROAD_COLOR if (tx + ty) % 2 == 0 else ROAD_COLOR_2
			cr.size     = Vector2(TILE, TILE)
			cr.position = Vector2(tx * TILE, ty * TILE)
			holder.add_child(cr)
		# Enclosing walls one tile above and below the road.
		for ty in [cy - 2, cy + 1]:
			_corridor_wall(holder, tx, ty)

func _corridor_wall(holder: Node2D, tx: int, ty: int):
	var sb = StaticBody2D.new()
	sb.add_to_group("wall")
	sb.collision_layer = 1
	sb.position = Vector2(tx * TILE + TILE * 0.5, ty * TILE + TILE * 0.5)
	var cr = ColorRect.new()
	cr.color    = Room.WALL_COLOR
	cr.size     = Vector2(TILE, TILE)
	cr.position = -Vector2(TILE, TILE) * 0.5
	sb.add_child(cr)
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	col.shape = rect
	sb.add_child(col)
	holder.add_child(sb)

# ── Room activation ───────────────────────────────────────────────────────────

func _activate_room(i: int):
	room_activated[i] = true
	var room: Room = rooms[i]
	match room_types[i]:
		"c":
			room.start_combat()
		"b":
			var bname: String = BOSS_NAMES.get(sublevel_idx, "曼陀罗花")
			hud.show_boss_bar(true, bname)
			hud.show_sublevel_title("%s  BOSS" % bname)
			room.start_boss()

# ── Room cleared ──────────────────────────────────────────────────────────────

func _on_room_cleared(i: int):
	GameManager.on_room_cleared()
	var t: String = room_types[i]
	if t == "b":
		hud.show_boss_bar(false)
		GameManager.on_sublevel_cleared()
		if sublevel_idx >= MAX_SUBLEVEL:
			_on_game_clear()
		else:
			_spawn_exit_portal(rooms[i])
		return
	# Combat room: reward + possible weapon drop.
	_grant_room_rewards()
	if is_instance_valid(rooms[i]):
		_maybe_drop_weapon_at(rooms[i])

# ── Exit portal / win ─────────────────────────────────────────────────────────

func _spawn_exit_portal(boss_room: Room):
	hud.show_sublevel_title("进入传送门 → 第 %d 关" % (sublevel_idx + 1))
	var portal = Area2D.new()
	portal.add_to_group("level_geometry")
	portal.collision_layer = 0
	portal.collision_mask  = 2
	portal.global_position = boss_room.get_center_world()

	var vis = ColorRect.new()
	vis.color    = Color(0.15, 0.80, 1.00, 0.78)
	vis.size     = Vector2(52, 68)
	vis.position = Vector2(-26, -34)
	portal.add_child(vis)
	var lbl = Label.new()
	lbl.text = "传送门"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.position = Vector2(-24, -56)
	portal.add_child(lbl)
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(52, 68)
	col.shape = rect
	portal.add_child(col)
	add_child(portal)

	var tw = portal.create_tween().set_loops()
	tw.tween_property(vis, "modulate:a", 0.45, 0.55)
	tw.tween_property(vis, "modulate:a", 1.00, 0.55)

	var snap_gen := _current_gen
	portal.body_entered.connect(func(body):
		if body.is_in_group("player") and _current_gen == snap_gen:
			portal.collision_mask = 0
			_on_exit_entered())

func _on_exit_entered():
	sublevel_idx += 1
	if sublevel_idx > MAX_SUBLEVEL:
		return
	_load_sublevel(sublevel_idx)

func _on_game_clear():
	hud.show_sublevel_title("通关！恭喜！")
	if is_instance_valid(player):
		player.set_physics_process(false)
	await get_tree().create_timer(2.6).timeout
	get_tree().change_scene_to_file("res://scenes/Win.tscn")

# ── Rewards ───────────────────────────────────────────────────────────────────

func _grant_room_rewards():
	if not is_instance_valid(player):
		return
	player.heal(ROOM_CLEAR_HEAL)
	player.restore_energy(ROOM_CLEAR_ENERGY)
	_spawn_reward_label(player.global_position)

func _spawn_reward_label(pos: Vector2):
	var lbl = Label.new()
	lbl.text = "+%d HP  +%d 能量" % [ROOM_CLEAR_HEAL, ROOM_CLEAR_ENERGY]
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	lbl.global_position = pos + Vector2(-60, -60)
	add_child(lbl)
	var t = lbl.create_tween()
	t.tween_property(lbl, "position:y", lbl.position.y - 50, 1.2)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	t.tween_callback(lbl.queue_free)

func _maybe_drop_weapon_at(room: Room):
	if randf() > 0.4:
		return
	var floors := room.get_floor_tiles()
	if floors.is_empty():
		return
	floors.shuffle()
	var world_pos := room.to_global(RoomGenerator.tile_to_world(floors[0]))
	_create_pickup_node(_random_common_weapon(), world_pos)

func _random_common_weapon() -> String:
	var ids := WeaponDatabase.get_all_weapon_ids().filter(
		func(id): return not WeaponDatabase.get_weapon(id).get("props", {}).get("rare", false))
	return ids[randi() % ids.size()]

func _on_weapon_dropped(weapon_id: String, pos: Vector2):
	_create_pickup_node(weapon_id, pos)

func _create_pickup_node(weapon_id: String, pos: Vector2):
	var w    := WeaponDatabase.get_weapon(weapon_id)
	var area := Area2D.new()
	area.add_to_group("weapon_pickup")
	area.add_to_group("level_geometry")
	area.collision_layer = 0
	area.collision_mask  = 2
	area.global_position = pos
	area.set_meta("weapon_id", weapon_id)

	area.add_child(PixelArt.sprite_from(PixelArt.make_weapon_icon(weapon_id)))

	var name_lbl := Label.new()
	name_lbl.text = w.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.position = Vector2(-22, -44)
	area.add_child(name_lbl)

	var hint := Label.new()
	hint.text = "[Enter]"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.position = Vector2(-16, 18)
	area.add_child(hint)

	var col  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 20.0
	col.shape   = circ
	area.add_child(col)
	add_child(area)

# ── Game-state ────────────────────────────────────────────────────────────────

func _on_player_died():
	hud.show_game_over()

func _on_game_over():
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
