extends RefCounted
class_name RoomGenerator

# Grid encoding: W=wall, .=floor, L=left door, R=right door, U=up door, D=down door
# Room grid is COLS x ROWS tiles, each tile 64x64 px
# Every row must be exactly COLS (20) characters.
# Door rules: L at col 0 → col 1 must be floor; R at col 19 → col 18 must be floor.

const TILE_SIZE: int = 64
const COLS: int      = 20
const ROWS: int      = 12

# 10 hand-crafted templates, each row exactly 20 chars.
# Templates 0-8 are normal rooms; template 9 is the boss arena.
const TEMPLATES: Array = [
	# Template 0 – open arena (simplest)
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..................W",
		"L..................R",
		"W..................W",
		"W..................W",
		"W..................W",
		"L..................R",
		"W..................W",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 1 – central pillars
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..................W",
		"L..................R",
		"W....WW......WW....W",
		"W....WW......WW....W",
		"W....WW......WW....W",
		"L..................R",
		"W....WW......WW....W",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 2 – horizontal barrier walls (barriers between door rows)
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..................W",
		"L..................R",
		"W...WWWWWWWWWWWW...W",
		"W...WWWWWWWWWWWW...W",
		"W..................W",
		"L..................R",
		"W...WWWWWWWWWWWW...W",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 3 – L-shape (bottom-right quarter cut off)
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..................W",
		"L..................R",
		"W..........WWWWWWWWW",
		"W..........WWWWWWWWW",
		"W..........WWWWWWWWW",
		"L..........WWWWWWWWW",
		"W..........WWWWWWWWW",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 4 – vertical centre divider (connected at top and bottom)
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W........W.........W",
		"L........W.........R",
		"W........W.........W",
		"W........W.........W",
		"W........W.........W",
		"L........W.........R",
		"W........W.........W",
		"W........W.........W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 5 – maze-like barriers
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W.WWWWWWWWW.WWWWWW.W",
		"L..................R",
		"W.WWWWWWWWW.WWWWWW.W",
		"W..........W.......W",
		"W..........W.......W",
		"L..........W.......R",
		"W.WWWWWWWWW........W",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 6 – inner chamber (accessible via open top row)
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W....W........W....W",
		"L....W........W....R",
		"W....W........W....W",
		"W....WWWWWWWWWW....W",
		"W..................W",
		"L..................R",
		"W..................W",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 7 – grid of pillar pairs
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..WW..WW..WW..WW..W",
		"L..................R",
		"W..WW..WW..WW..WW..W",
		"W..................W",
		"W..................W",
		"L..WW..WW..WW..WW..R",
		"W..WW..WW..WW..WW..W",
		"W..................W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 8 – upper barrier wall with gaps
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..WWWWWWWWWWWWWW..W",
		"W..WWWWWWWWWWWWWW..W",
		"L..................R",
		"W..................W",
		"W..................W",
		"L..................R",
		"W..................W",
		"W..WWWWWWWWWWWWWW..W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
	# Template 9 – boss arena (large open, corner pillars)
	[
		"WWWWWWWWWWWWWWWWWWWW",
		"W..................W",
		"W..W............W..W",
		"L..................R",
		"W..W............W..W",
		"W..................W",
		"W..................W",
		"W..................W",
		"L..................R",
		"W..W............W..W",
		"W..................W",
		"WWWWWWWWWWWWWWWWWWWW",
	],
]

static func get_template(index: int) -> Array:
	return TEMPLATES[clamp(index, 0, TEMPLATES.size() - 1)]

static func get_random_template() -> Array:
	# Templates 0-8 are combat rooms; template 9 is boss only
	return TEMPLATES[randi() % (TEMPLATES.size() - 1)]

static func get_boss_template() -> Array:
	return TEMPLATES[TEMPLATES.size() - 1]

static func parse_template(template: Array) -> Dictionary:
	var walls: Array        = []
	var floors: Array       = []
	var doors: Dictionary   = {"up": [], "down": [], "left": [], "right": []}
	var spawn_points: Array = []

	for row in template.size():
		var line: String = template[row]
		for col in line.length():
			var ch       = line[col]
			var tile_pos = Vector2i(col, row)
			match ch:
				"W": walls.append(tile_pos)
				".":
					floors.append(tile_pos)
				"L":
					floors.append(tile_pos)
					doors["left"].append(tile_pos)
				"R":
					floors.append(tile_pos)
					doors["right"].append(tile_pos)
				"U":
					floors.append(tile_pos)
					doors["up"].append(tile_pos)
				"D":
					floors.append(tile_pos)
					doors["down"].append(tile_pos)

	# Spawn points: mid-room floor tiles (avoid edges and door columns)
	for f in floors:
		if f.x > 3 and f.x < COLS - 3 and f.y > 2 and f.y < ROWS - 2:
			if randf() < 0.09:
				spawn_points.append(f)

	return {
		"walls":        walls,
		"floors":       floors,
		"doors":        doors,
		"spawn_points": spawn_points,
	}

static func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE * 0.5,
	               tile.y * TILE_SIZE + TILE_SIZE * 0.5)
