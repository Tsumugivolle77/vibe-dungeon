extends RefCounted
class_name RoomGenerator

# Procedurally builds a rectangular room of a given tile size with door openings
# at the MIDPOINTS of chosen edges. Rooms are connected by corridors (roads) that
# the Level lays between adjacent edge-midpoint doors.
#
# Returned dictionary:
#   cols, rows         : size in tiles
#   floors             : Array[Vector2i] walkable interior + door-opening tiles
#   walls              : Array[Vector2i] solid border tiles (minus openings)
#   door_tiles         : { "left"/"right"/"up"/"down" : Array[Vector2i] } opening tiles
#   spawn_points       : Array[Vector2i] safe interior tiles (margin from walls)
#   center             : Vector2i centre tile

const TILE_SIZE: int = 64
const DOOR_HALF: int = 1   # opening spans 2 tiles centred on the edge midpoint

static func generate(cols: int, rows: int, doors: Dictionary) -> Dictionary:
	var floors: Array          = []
	var walls: Array           = []
	var door_tiles: Dictionary = {"left": [], "right": [], "up": [], "down": []}
	var spawn_points: Array     = []

	var mid_c: int = cols / 2
	var mid_r: int = rows / 2

	# Collect opening tiles (border tiles that are passable) keyed for quick lookup.
	var openings: Dictionary = {}
	if doors.get("left", false):
		for r in range(mid_r - DOOR_HALF, mid_r + DOOR_HALF):
			var t := Vector2i(0, r)
			openings[t] = true
			door_tiles["left"].append(t)
	if doors.get("right", false):
		for r in range(mid_r - DOOR_HALF, mid_r + DOOR_HALF):
			var t := Vector2i(cols - 1, r)
			openings[t] = true
			door_tiles["right"].append(t)
	if doors.get("up", false):
		for c in range(mid_c - DOOR_HALF, mid_c + DOOR_HALF):
			var t := Vector2i(c, 0)
			openings[t] = true
			door_tiles["up"].append(t)
	if doors.get("down", false):
		for c in range(mid_c - DOOR_HALF, mid_c + DOOR_HALF):
			var t := Vector2i(c, rows - 1)
			openings[t] = true
			door_tiles["down"].append(t)

	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			var is_border: bool = (x == 0 or x == cols - 1 or y == 0 or y == rows - 1)
			if is_border and not openings.has(t):
				walls.append(t)
			else:
				floors.append(t)

	# Spawn points: interior tiles kept two tiles away from every wall, so monsters
	# never appear inside or hugging an impassable border.
	for y in range(2, rows - 2):
		for x in range(2, cols - 2):
			spawn_points.append(Vector2i(x, y))

	return {
		"cols":         cols,
		"rows":         rows,
		"floors":       floors,
		"walls":        walls,
		"door_tiles":   door_tiles,
		"spawn_points": spawn_points,
		"center":       Vector2i(mid_c, mid_r),
	}

# Local (room-relative) centre of a tile in pixels.
static func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE * 0.5,
				   tile.y * TILE_SIZE + TILE_SIZE * 0.5)
