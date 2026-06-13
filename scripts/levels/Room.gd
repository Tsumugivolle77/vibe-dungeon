extends Node2D
class_name Room

signal all_enemies_dead

@export var is_boss_room: bool = false
@export var sublevel_idx: int  = 1

const TILE_SIZE   = RoomGenerator.TILE_SIZE
const WALL_COLOR  = Color(0.18, 0.25, 0.12)
const FLOOR_COLOR = Color(0.22, 0.35, 0.15)
const DOOR_COLOR  = Color(0.55, 0.38, 0.12)

var room_type: String      = "combat"
var data: Dictionary       = {}
var doors: Dictionary      = {}   # dir -> StaticBody2D barrier
var enemies_alive: int     = 0
var cleared: bool          = false

# Wave state (combat rooms)
var combat_started: bool   = false
var total_waves: int       = 1
var current_wave: int      = 0

var _chest_scene: PackedScene = preload("res://scenes/entities/Chest.tscn")

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
}

const SUBLEVEL_POOLS = {
	1: ["goblin", "slime", "goblin_archer"],
	2: ["goblin", "slime", "goblin_archer", "forest_spirit"],
	3: ["goblin_archer", "forest_spirit", "tree_monster", "mushroom_man"],
	4: ["elite_goblin", "stone_golem", "vine_creature", "forest_spirit"],
	5: ["corrupted_fairy", "elite_goblin", "stone_golem", "vine_creature"],
}

# One distinct boss per sublevel; sublevel 5 = final boss (Mandrake).
const BOSS_BY_SUBLEVEL = {
	1: "res://scenes/enemies/GoblinKing.tscn",
	2: "res://scenes/enemies/SlimeMother.tscn",
	3: "res://scenes/enemies/AncientTreant.tscn",
	4: "res://scenes/enemies/FairyQueen.tscn",
	5: "res://scenes/enemies/MandrakeFlower.tscn",
}

# ── Construction ──────────────────────────────────────────────────────────────

# Safety net: any enemy that ends up outside the room walls (e.g. a boss minion
# spawned into a corner, or one shoved through a gap) takes "suffocation" damage so
# it dies and gets counted — never leaving the room un-clearable.
func _process(delta: float):
	if cleared or not combat_started or data.is_empty():
		return
	var w: float = float(data.cols) * TILE_SIZE
	var h: float = float(data.rows) * TILE_SIZE
	for e in get_children():
		if not (e is Node2D) or not e.is_in_group("enemy") or not is_instance_valid(e):
			continue
		var p: Vector2 = e.position
		if p.x < -8.0 or p.y < -8.0 or p.x > w + 8.0 or p.y > h + 8.0:
			if e.has_method("take_damage"):
				e.take_damage(90.0 * delta)

func build(spec: Dictionary, sublevel: int):
	room_type    = spec.get("type", "combat")
	sublevel_idx = sublevel
	is_boss_room = (room_type == "boss")
	data = RoomGenerator.generate(spec.cols, spec.rows, spec.get("doors", {}))
	_build_floors()
	_build_walls()
	_build_doors(spec.get("doors", {}))
	_build_navmesh()

func _build_floors():
	var floor_node = Node2D.new()
	floor_node.name = "Floors"
	add_child(floor_node)
	var alt := FLOOR_COLOR.darkened(0.08)
	for tile in data.floors:
		var cr = ColorRect.new()
		cr.color    = FLOOR_COLOR if (tile.x + tile.y) % 2 == 0 else alt   # checker
		cr.size     = Vector2(TILE_SIZE, TILE_SIZE)
		cr.position = Vector2(tile.x * TILE_SIZE, tile.y * TILE_SIZE)
		floor_node.add_child(cr)
		# Scattered moss / pebble detail for texture.
		if randf() < 0.12:
			var d = ColorRect.new()
			var s = randf_range(8.0, 16.0)
			d.size  = Vector2(s, s)
			d.position = cr.position + Vector2(randf_range(4, TILE_SIZE - s - 4),
											   randf_range(4, TILE_SIZE - s - 4))
			d.color = FLOOR_COLOR.lightened(0.14) if randf() < 0.5 else FLOOR_COLOR.darkened(0.2)
			floor_node.add_child(d)

func _build_walls():
	var wall_node = Node2D.new()
	wall_node.name = "Walls"
	add_child(wall_node)
	for tile in data.walls:
		var sb = StaticBody2D.new()
		sb.add_to_group("wall")
		sb.collision_layer = 1
		sb.position = Vector2(tile.x * TILE_SIZE + TILE_SIZE * 0.5,
							  tile.y * TILE_SIZE + TILE_SIZE * 0.5)
		var cr = ColorRect.new()
		cr.color    = WALL_COLOR if (tile.x + tile.y) % 2 == 0 else WALL_COLOR.lightened(0.07)
		cr.size     = Vector2(TILE_SIZE, TILE_SIZE)
		cr.position = -Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		sb.add_child(cr)
		# Top highlight edge for a bit of depth.
		var edge = ColorRect.new()
		edge.color = WALL_COLOR.lightened(0.18)
		edge.size  = Vector2(TILE_SIZE, 5)
		edge.position = -Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		sb.add_child(edge)
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		col.shape = rect
		sb.add_child(col)
		wall_node.add_child(sb)

func _build_navmesh():
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	add_child(nav_region)
	# Interior is a clean rectangle (no obstacles) inside the wall border.
	# Define the polygon explicitly (vertices + indices) rather than relying on the
	# deprecated make_polygons_from_outlines(), which can yield an empty navmesh.
	var nav_poly = NavigationPolygon.new()
	var min_x = float(TILE_SIZE)
	var min_y = float(TILE_SIZE)
	var max_x = float((data.cols - 1) * TILE_SIZE)
	var max_y = float((data.rows - 1) * TILE_SIZE)
	nav_poly.vertices = PackedVector2Array([
		Vector2(min_x, min_y), Vector2(max_x, min_y),
		Vector2(max_x, max_y), Vector2(min_x, max_y),
	])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly

# ── Doors (lockable barriers at edge midpoints) ───────────────────────────────

func _build_doors(door_flags: Dictionary):
	var door_node = Node2D.new()
	door_node.name = "Doors"
	add_child(door_node)
	for dir in ["left", "right", "up", "down"]:
		if not door_flags.get(dir, false):
			continue
		var barrier = _make_door_barrier(dir)
		door_node.add_child(barrier)
		doors[dir] = barrier
	# Doors start OPEN; combat/boss rooms close them on entry.
	_unlock_doors()

func _make_door_barrier(dir: String) -> StaticBody2D:
	var mid_c: int = data.cols / 2
	var mid_r: int = data.rows / 2
	var pos: Vector2
	var size: Vector2
	match dir:
		"left":
			pos  = Vector2(TILE_SIZE * 0.5, mid_r * TILE_SIZE)
			size = Vector2(TILE_SIZE, TILE_SIZE * 2)
		"right":
			pos  = Vector2((data.cols - 0.5) * TILE_SIZE, mid_r * TILE_SIZE)
			size = Vector2(TILE_SIZE, TILE_SIZE * 2)
		"up":
			pos  = Vector2(mid_c * TILE_SIZE, TILE_SIZE * 0.5)
			size = Vector2(TILE_SIZE * 2, TILE_SIZE)
		"down":
			pos  = Vector2(mid_c * TILE_SIZE, (data.rows - 0.5) * TILE_SIZE)
			size = Vector2(TILE_SIZE * 2, TILE_SIZE)

	var sb = StaticBody2D.new()
	sb.collision_layer = 1
	sb.position = pos
	var vis = ColorRect.new()
	vis.color    = DOOR_COLOR
	vis.size     = size
	vis.position = -size * 0.5
	sb.add_child(vis)
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	sb.add_child(col)
	return sb

func _lock_doors():
	for dir in doors:
		var b: StaticBody2D = doors[dir]
		b.visible = true
		b.get_child(1).set_deferred("disabled", false)  # CollisionShape2D

func _unlock_doors():
	for dir in doors:
		var b: StaticBody2D = doors[dir]
		b.visible = false
		b.get_child(1).set_deferred("disabled", true)

# ── Combat (wave-based monster room) ──────────────────────────────────────────

func start_combat():
	if combat_started or cleared:
		return
	combat_started = true
	_lock_doors()                       # close entrance AND exit
	total_waves  = randi_range(1, 3)    # CLAUDE.md: 1–3 waves
	current_wave = 0
	_spawn_next_wave()

func _spawn_next_wave():
	current_wave += 1
	var pool: Array = SUBLEVEL_POOLS.get(sublevel_idx, SUBLEVEL_POOLS[1])
	var spawns: Array = data.spawn_points.duplicate()
	spawns.shuffle()
	var count = 2 + sublevel_idx + randi() % 2
	var spawned = 0
	for i in min(count, spawns.size()):
		var enemy_type = pool[randi() % pool.size()]
		var scene = load(ENEMY_SCENES.get(enemy_type, ""))
		if not scene:
			continue
		var enemy = scene.instantiate()
		enemy.died.connect(_on_combat_enemy_died)
		add_child(enemy)
		enemy.position = RoomGenerator.tile_to_world(spawns[i])  # room-local, on floor
		enemies_alive += 1
		spawned += 1
	if spawned == 0:
		_finish_combat()

func _on_combat_enemy_died(_pos: Vector2, _xp: int):
	enemies_alive -= 1
	if enemies_alive > 0:
		return
	if current_wave < total_waves:
		_spawn_next_wave()
	else:
		_finish_combat()

func _finish_combat():
	cleared = true
	_unlock_doors()
	_spawn_chest()
	emit_signal("all_enemies_dead")

# ── Boss room ─────────────────────────────────────────────────────────────────

func start_boss():
	if combat_started or cleared:
		return
	combat_started = true
	_lock_doors()                       # close the single entrance
	var path: String = BOSS_BY_SUBLEVEL.get(sublevel_idx, BOSS_BY_SUBLEVEL[5])
	var scene = load(path)
	if not scene:
		_on_boss_died(Vector2.ZERO, 0)
		return
	var boss = scene.instantiate()
	boss.died.connect(_on_boss_died)
	if boss.has_signal("boss_hp_changed"):
		boss.boss_hp_changed.connect(func(h, m): get_parent().emit_signal("boss_hp_changed", h, m))
	add_child(boss)
	boss.position = RoomGenerator.tile_to_world(data.center)  # room-local centre
	enemies_alive = 1

func _on_boss_died(_pos: Vector2, _xp: int):
	cleared = true
	_unlock_doors()
	emit_signal("all_enemies_dead")

# ── Chest ─────────────────────────────────────────────────────────────────────

func _spawn_chest():
	var chest = _chest_scene.instantiate()
	add_child(chest)
	chest.position = RoomGenerator.tile_to_world(data.center) + Vector2(0, -20)  # room-local

# ── Queries ───────────────────────────────────────────────────────────────────

func get_floor_tiles() -> Array:
	return data.floors.duplicate()

# Local centre (used by sub-rooms to lay out child items).
func get_player_start() -> Vector2:
	return RoomGenerator.tile_to_world(data.center)

# Global centre (used by Level to place the player / boss / portal).
func get_center_world() -> Vector2:
	return to_global(RoomGenerator.tile_to_world(data.center))

# Interior world rectangle, inset one tile so triggers fire only when the player
# is genuinely inside the room (past the doorway).
func interior_world_rect() -> Rect2:
	var top_left = to_global(Vector2(TILE_SIZE, TILE_SIZE))
	var size = Vector2((data.cols - 2) * TILE_SIZE, (data.rows - 2) * TILE_SIZE)
	return Rect2(top_left, size)
