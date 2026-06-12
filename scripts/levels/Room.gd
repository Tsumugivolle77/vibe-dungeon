extends Node2D
class_name Room

signal all_enemies_dead
signal door_entered(direction: String)

@export var is_boss_room: bool  = false
@export var sublevel_idx: int   = 1
@export var room_idx: int       = 0

const TILE_SIZE = RoomGenerator.TILE_SIZE
const WALL_COLOR  = Color(0.18, 0.25, 0.12)
const FLOOR_COLOR = Color(0.22, 0.35, 0.15)
const DOOR_COLOR  = Color(0.55, 0.38, 0.12)

var template_data: Dictionary = {}
var enemies_alive: int        = 0
var cleared: bool             = false
var doors: Dictionary         = {}  # "left","right","up","down" -> Area2D

var _chest_scene: PackedScene = preload("res://scenes/entities/Chest.tscn")
var _crate_scene: PackedScene = preload("res://scenes/entities/Crate.tscn")

const ENEMY_SCENES = {
	"goblin":          "res://scenes/enemies/Goblin.tscn",
	"goblin_archer":   "res://scenes/enemies/GoblinArcher.tscn",
	"slime":           "res://scenes/enemies/Slime.tscn",
	"forest_spirit":   "res://scenes/enemies/ForestSpirit.tscn",
	"tree_monster":    "res://scenes/enemies/TreeMonster.tscn",
	"mushroom_man":    "res://scenes/enemies/MushroomMan.tscn",
	"elite_goblin":    "res://scenes/enemies/EliteGoblin.tscn",
	"stone_golem":     "res://scenes/enemies/StoneGolem.tscn",
	"vine_creature":   "res://scenes/enemies/VineCreature.tscn",
	"corrupted_fairy": "res://scenes/enemies/CorruptedFairy.tscn",
	"mandrake":        "res://scenes/enemies/MandrakeFlower.tscn",
}

const SUBLEVEL_POOLS = {
	1: ["goblin", "slime", "goblin_archer"],
	2: ["goblin", "slime", "goblin_archer", "forest_spirit"],
	3: ["goblin_archer", "forest_spirit", "tree_monster", "mushroom_man"],
	4: ["elite_goblin", "stone_golem", "vine_creature", "forest_spirit"],
	5: ["corrupted_fairy", "elite_goblin", "stone_golem", "vine_creature"],
}

func build(template_idx: int = -1, is_boss: bool = false, sublevel: int = 1):
	is_boss_room = is_boss
	sublevel_idx = sublevel
	var tmpl: Array
	if is_boss_room:
		tmpl = RoomGenerator.get_boss_template()
	elif template_idx < 0:
		tmpl = RoomGenerator.get_random_template()
	else:
		tmpl = RoomGenerator.get_template(template_idx)

	template_data = RoomGenerator.parse_template(tmpl)
	_build_geometry()
	_build_doors()
	_lock_doors()
	if not is_boss_room:
		_spawn_obstacles()

func _build_geometry():
	var wall_node = Node2D.new()
	wall_node.name = "Walls"
	add_child(wall_node)

	var floor_node = Node2D.new()
	floor_node.name = "Floors"
	add_child(floor_node)

	for tile in template_data.floors:
		var cr = ColorRect.new()
		cr.color    = FLOOR_COLOR
		cr.size     = Vector2(TILE_SIZE, TILE_SIZE)
		cr.position = Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE)
		floor_node.add_child(cr)

	for tile in template_data.walls:
		var sb = StaticBody2D.new()
		sb.add_to_group("wall")
		sb.position = Vector2(tile.x * TILE_SIZE + TILE_SIZE * 0.5,
		                      tile.y * TILE_SIZE + TILE_SIZE * 0.5)
		var cr = ColorRect.new()
		cr.color    = WALL_COLOR
		cr.size     = Vector2(TILE_SIZE, TILE_SIZE)
		cr.position = -Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		sb.add_child(cr)
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		col.shape  = rect
		sb.add_child(col)
		wall_node.add_child(sb)

	_build_navmesh()

func _build_navmesh():
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	add_child(nav_region)

	var nav_poly = NavigationPolygon.new()
	var min_x = INF; var min_y = INF; var max_x = -INF; var max_y = -INF
	for tile in template_data.floors:
		min_x = min(min_x, tile.x * TILE_SIZE)
		min_y = min(min_y, tile.y * TILE_SIZE)
		max_x = max(max_x, (tile.x + 1) * TILE_SIZE)
		max_y = max(max_y, (tile.y + 1) * TILE_SIZE)

	if min_x < INF:
		var outline = PackedVector2Array([
			Vector2(min_x, min_y),
			Vector2(max_x, min_y),
			Vector2(max_x, max_y),
			Vector2(min_x, max_y),
		])
		nav_poly.add_outline(outline)
		nav_poly.make_polygons_from_outlines()
		nav_region.navigation_polygon = nav_poly

func _build_doors():
	var door_container = Node2D.new()
	door_container.name = "Doors"
	add_child(door_container)

	for dir in ["left", "right", "up", "down"]:
		var dir_tiles: Array = template_data.doors.get(dir, [])
		if dir_tiles.is_empty():
			continue
		var tile = dir_tiles[0]
		var area = Area2D.new()
		area.name = "Door_" + dir
		area.add_to_group("door")
		area.set_meta("direction", dir)
		area.collision_layer = 0
		area.collision_mask = 2
		area.position = RoomGenerator.tile_to_world(tile)

		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE * 1.2, TILE_SIZE * 1.2)
		col.shape  = rect
		area.add_child(col)

		var vis = ColorRect.new()
		vis.color    = DOOR_COLOR
		vis.size     = Vector2(TILE_SIZE, TILE_SIZE)
		vis.position = -Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		area.add_child(vis)

		area.body_entered.connect(_on_door_body(dir))
		door_container.add_child(area)
		doors[dir] = area

func _on_door_body(dir: String) -> Callable:
	return func(body: Node2D):
		if body.is_in_group("player") and cleared:
			emit_signal("door_entered", dir)

func _lock_doors():
	for dir in doors:
		doors[dir].get_child(0).set_deferred("disabled", true)
		if doors[dir].get_child_count() > 1:
			doors[dir].get_child(1).color = WALL_COLOR

func _unlock_doors():
	for dir in doors:
		doors[dir].get_child(0).set_deferred("disabled", false)
		if doors[dir].get_child_count() > 1:
			doors[dir].get_child(1).color = DOOR_COLOR

# ─── Obstacle spawning ───────────────────────────────────────────────────────

func _spawn_obstacles():
	# Collect forbidden tiles: door tiles + spawn points + center buffer
	var forbidden: Array = []
	for dir in template_data.doors:
		for t in template_data.doors[dir]:
			forbidden.append(t)
	for t in template_data.spawn_points:
		forbidden.append(t)

	# Inner floor tiles only (avoid the border row/col)
	var inner_floors: Array = []
	for t in template_data.floors:
		var is_inner = true
		for f in forbidden:
			if t == f:
				is_inner = false
				break
		if is_inner:
			inner_floors.append(t)

	inner_floors.shuffle()
	var budget = int(inner_floors.size() * 0.18)  # use up to 18% of floor for obstacles

	var i = 0
	while i < min(budget, inner_floors.size()):
		var tile = inner_floors[i]
		var pos = RoomGenerator.tile_to_world(tile)
		var r = randf()
		if r < 0.30:
			_make_tree(pos)
		elif r < 0.55:
			_make_bush(pos)
		elif r < 0.70:
			_make_crate(pos)
		i += 1

func _make_tree(pos: Vector2):
	var sb = StaticBody2D.new()
	sb.add_to_group("wall")
	sb.global_position = pos

	var sprite = PixelArt.sprite_from(PixelArt.make_tree())
	sb.add_child(sprite)

	var col = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 14.0
	col.shape = circ
	sb.add_child(col)

	add_child(sb)

func _make_bush(pos: Vector2):
	var sb = StaticBody2D.new()
	sb.add_to_group("wall")
	sb.global_position = pos

	var sprite = PixelArt.sprite_from(PixelArt.make_bush())
	sb.add_child(sprite)

	var col = CollisionShape2D.new()
	var circ = CircleShape2D.new()
	circ.radius = 10.0
	col.shape = circ
	sb.add_child(col)

	add_child(sb)

func _make_crate(pos: Vector2):
	var crate = _crate_scene.instantiate()
	crate.global_position = pos
	add_child(crate)

# ─── Enemy spawning ──────────────────────────────────────────────────────────

func spawn_enemies(boss_mode_chance: float = 0.15):
	if is_boss_room:
		_spawn_boss()
		return

	var pool: Array = SUBLEVEL_POOLS.get(sublevel_idx, SUBLEVEL_POOLS[1])
	var count = 3 + sublevel_idx + randi() % 3
	var spawns = template_data.spawn_points.duplicate()
	spawns.shuffle()

	var spawned = 0
	for i in min(count, spawns.size()):
		var enemy_type = pool[randi() % pool.size()]
		var scene_path = ENEMY_SCENES.get(enemy_type, "")
		if scene_path.is_empty():
			continue
		var scene = load(scene_path)
		if not scene:
			continue
		var enemy = scene.instantiate()
		enemy.global_position = RoomGenerator.tile_to_world(spawns[i])
		if randf() < boss_mode_chance and not is_boss_room:
			enemy.is_boss_mode = true
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)
		enemies_alive += 1
		spawned += 1

	if spawned == 0:
		cleared = true
		_unlock_doors()

func _spawn_boss():
	var scene = load(ENEMY_SCENES.get("mandrake", ""))
	if not scene:
		return
	var boss = scene.instantiate()
	boss.global_position = Vector2(
		RoomGenerator.COLS * RoomGenerator.TILE_SIZE * 0.5,
		RoomGenerator.ROWS * RoomGenerator.TILE_SIZE * 0.5
	)
	boss.died.connect(_on_enemy_died)
	boss.boss_hp_changed.connect(func(h, m): get_parent().emit_signal("boss_hp_changed", h, m))
	add_child(boss)
	enemies_alive = 1

func _on_enemy_died(_pos: Vector2, _xp: int):
	enemies_alive -= 1
	if enemies_alive <= 0:
		cleared = true
		_unlock_doors()
		emit_signal("all_enemies_dead")
		if is_boss_room:
			GameManager.on_sublevel_cleared()
		else:
			_spawn_chest()

func _spawn_chest():
	var chest = _chest_scene.instantiate()
	# Place near room center on a floor tile
	var centre = Vector2i(RoomGenerator.COLS / 2, RoomGenerator.ROWS / 2)
	var best_tile = centre
	var best_dist = INF
	for t in template_data.floors:
		var d = float((t - centre).length())
		if d < best_dist:
			best_dist = d
			best_tile = t
	chest.global_position = RoomGenerator.tile_to_world(best_tile) + Vector2(0, -20)
	add_child(chest)

func get_floor_tiles() -> Array:
	return template_data.floors.duplicate()

func get_player_start() -> Vector2:
	var floors = template_data.floors
	if floors.is_empty():
		return Vector2(TILE_SIZE * 2, TILE_SIZE * 2)
	var centre = Vector2i(RoomGenerator.COLS / 2, RoomGenerator.ROWS / 2)
	var best_tile = floors[0]
	var best_dist = INF
	for t in floors:
		var d = float((t - centre).length())
		if d < best_dist:
			best_dist = d
			best_tile = t
	return RoomGenerator.tile_to_world(best_tile)
