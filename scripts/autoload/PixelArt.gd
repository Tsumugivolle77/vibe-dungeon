extends Node
# Generates ImageTexture sprites from code-defined pixel arrays.
# Pixel scale = 3 → each "pixel" is a 3×3 block of real pixels.

const SCALE = 3

# ── Palette definitions ──────────────────────────────────────────────────────
const PAL_KNIGHT = {
	"H": Color(0.18, 0.28, 0.62),   # helmet dark
	"h": Color(0.32, 0.46, 0.80),   # helmet light
	"F": Color(0.90, 0.75, 0.60),   # skin
	"E": Color(0.10, 0.10, 0.10),   # eye
	"B": Color(0.22, 0.38, 0.72),   # armor body
	"b": Color(0.14, 0.24, 0.52),   # armor shadow
	"A": Color(0.65, 0.52, 0.18),   # gold accent
	"L": Color(0.18, 0.30, 0.60),   # legs
	"S": Color(0.75, 0.78, 0.85),   # sword blade
	"G": Color(0.45, 0.30, 0.12),   # grip brown
	".": Color(0, 0, 0, 0),
}
const SPR_KNIGHT = [
	"....hHHHh....",
	"...HHHHHHHH..",
	"...HhHHHhHH..",
	"....FFFFFF...",
	"....FEFEEF...",
	"....FFFFFF...",
	"..bBBBBBBBb..",
	"..BAAbBbAAB..",
	"..bBBBBBBBb..",
	"..BBBBBBBBB..",
	"..bbbbbbbbbb.",
	"...LL...LL...",
	"...LL...LL...",
	"...LL...LL...",
	"...bb...bb...",
]

const PAL_GOBLIN = {
	"G": Color(0.25, 0.60, 0.22),  # green body
	"g": Color(0.18, 0.45, 0.15),  # dark green
	"E": Color(0.85, 0.15, 0.15),  # red eye
	"T": Color(0.55, 0.35, 0.10),  # tooth
	"B": Color(0.40, 0.26, 0.10),  # brown clothes
	".": Color(0, 0, 0, 0),
}
const SPR_GOBLIN = [
	"..gGGGg..",
	".GGGGGGG.",
	".GEG.GEG.",
	".GGGGGGG.",
	"..GTTG...",
	"..BBBBB..",
	"..BBBBB..",
	"..B...B..",
]

const PAL_SLIME = {
	"S": Color(0.28, 0.85, 0.32),
	"s": Color(0.18, 0.65, 0.22),
	"E": Color(0.10, 0.30, 0.10),
	"H": Color(0.55, 0.95, 0.58, 0.8),
	".": Color(0, 0, 0, 0),
}
const SPR_SLIME = [
	"..SSSSS..",
	".SSSSSSS.",
	"SSSSSSSSS",
	"SSEHS.HSS",
	"SSSSSSSSS",
	".sSSSSSSs.",
	"..sSSSSs..",
	"...ssss...",
]

const PAL_FOREST_SPIRIT = {
	"P": Color(0.55, 0.32, 0.90, 0.85),
	"p": Color(0.40, 0.20, 0.72, 0.70),
	"W": Color(0.90, 0.95, 1.00, 0.90),
	"E": Color(0.95, 0.85, 0.20),
	".": Color(0, 0, 0, 0),
}
const SPR_FOREST_SPIRIT = [
	"..pPPPp..",
	".pPPPPPp.",
	".PWEWEPW.",
	".PPPPPPP.",
	"..pPPPp..",
	"..P...P..",
	"..p...p..",
]

const PAL_MUSHROOM = {
	"C": Color(0.70, 0.40, 0.15),  # cap
	"c": Color(0.85, 0.55, 0.20),
	"W": Color(0.92, 0.88, 0.82),  # stem
	"E": Color(0.15, 0.10, 0.08),
	"S": Color(0.95, 0.95, 0.90),  # spots
	".": Color(0, 0, 0, 0),
}
const SPR_MUSHROOM = [
	"..CCCCC..",
	".CCSCScC.",
	"CCCCCCCCCC",
	".WWWWWWW.",
	".WEWEWEW.",
	".WWWWWWW.",
	"..WWWWW..",
]

const PAL_GOLEM = {
	"R": Color(0.45, 0.45, 0.48),  # rock grey
	"r": Color(0.32, 0.32, 0.35),
	"L": Color(0.60, 0.60, 0.62),  # light rock
	"E": Color(0.85, 0.40, 0.10),  # lava eye
	"C": Color(0.25, 0.25, 0.28),
	".": Color(0, 0, 0, 0),
}
const SPR_GOLEM = [
	"rRRRRRRRr",
	"RRRRRRRRR",
	"RLRERERL R",
	"RRRRRRRRR",
	"rRCRRRCRr",
	"RRRRRRRRR",
	"RRRRRRRRR",
	"rR.....Rr",
	".RR...RR.",
	".rR...Rr.",
]

const PAL_FAIRY = {
	"P": Color(0.88, 0.28, 0.82),
	"p": Color(0.65, 0.18, 0.62),
	"W": Color(0.95, 0.90, 1.00, 0.75),
	"E": Color(0.95, 0.95, 0.30),
	"G": Color(0.50, 0.95, 0.55, 0.60),
	".": Color(0, 0, 0, 0),
}
const SPR_FAIRY = [
	"W...W.W...W",
	"GW.P.P.P.WG",
	"GWP.PPP.PWG",
	"WWWPEPEPWWW",
	"GWP.PPP.PWG",
	"GW.P.P.P.WG",
	"W...W.W...W",
]

const PAL_MANDRAKE = {
	"M": Color(0.78, 0.18, 0.60),
	"m": Color(0.55, 0.10, 0.42),
	"G": Color(0.20, 0.65, 0.18),
	"g": Color(0.14, 0.48, 0.12),
	"E": Color(0.95, 0.92, 0.20),
	"P": Color(0.90, 0.35, 0.75),
	"W": Color(0.98, 0.95, 0.98),
	".": Color(0, 0, 0, 0),
}
const SPR_MANDRAKE = [
	"..GgGGgGG...",
	".GgGGGGGgG..",
	"GGGGgGGGGGG.",
	".GGGMMMMMgG.",
	"..GMMMMMMG..",
	"..MMEPEPEMM.",
	"..mMMMMMMMm.",
	"..MMmMMMmMM.",
	"..mMMMMMMMm.",
	"..MMMMMMMM..",
	"..gMMMMMMg..",
	"...GGGGGG...",
	"....GGGG....",
]

# ── Public API ────────────────────────────────────────────────────────────────
func make_knight() -> ImageTexture:      return _tex(SPR_KNIGHT,       PAL_KNIGHT)
func make_goblin() -> ImageTexture:      return _tex(SPR_GOBLIN,       PAL_GOBLIN)
func make_slime() -> ImageTexture:       return _tex(SPR_SLIME,        PAL_SLIME)
func make_spirit() -> ImageTexture:      return _tex(SPR_FOREST_SPIRIT,PAL_FOREST_SPIRIT)
func make_mushroom() -> ImageTexture:    return _tex(SPR_MUSHROOM,     PAL_MUSHROOM)
func make_golem() -> ImageTexture:       return _tex(SPR_GOLEM,        PAL_GOLEM)
func make_fairy() -> ImageTexture:       return _tex(SPR_FAIRY,        PAL_FAIRY)
func make_mandrake() -> ImageTexture:    return _tex(SPR_MANDRAKE,     PAL_MANDRAKE)

func make_health_orb() -> ImageTexture:
	return _circle_tex(10, Color(0.95, 0.15, 0.15), Color(1.0, 0.50, 0.50))
func make_ammo_orb() -> ImageTexture:
	return _circle_tex(10, Color(0.10, 0.42, 0.92), Color(0.45, 0.72, 1.00))
func make_gold_coin() -> ImageTexture:
	return _circle_tex(8,  Color(0.85, 0.65, 0.05), Color(1.00, 0.90, 0.40))
func make_health_pack() -> ImageTexture: return _cross_tex(Color(0.88, 0.05, 0.05))
func make_ammo_pack() -> ImageTexture:   return _bars_tex(Color(0.05, 0.38, 0.88))

func make_chest() -> ImageTexture:
	var rows = [
		"AAAAAAAAAA",
		"AhAAAAAAAA",
		"LLLLLLLLLL",
		"LBBBBBBBL",
		"LBGGGGGBL",
		"LBBBBBBBL",
		"LLLLLLLLLL",
	]
	var pal = {
		"A": Color(0.60, 0.38, 0.10),
		"h": Color(0.80, 0.60, 0.25),
		"L": Color(0.40, 0.24, 0.06),
		"B": Color(0.50, 0.32, 0.08),
		"G": Color(0.90, 0.75, 0.10),
	}
	return _tex(rows, pal)

func make_crate() -> ImageTexture:
	var rows = [
		"WWWWWWWWWW",
		"WdWWWWWdWW",
		"WddWWWddWW",
		"WWWWWWWWWW",
		"WWWWWWWWWW",
		"WddWWWddWW",
		"WdWWWWWdWW",
		"WWWWWWWWWW",
	]
	var pal = {
		"W": Color(0.68, 0.50, 0.25),
		"d": Color(0.48, 0.34, 0.14),
	}
	return _tex(rows, pal)

func make_tree() -> ImageTexture:
	var rows = [
		"...GGG...",
		"..GGGGG..",
		".GGGGGGG.",
		"GGGGGGGGG",
		".GGGGGGG.",
		"..GGGGG..",
		"...GGG...",
		"....B....",
		"....B....",
		"....B....",
	]
	var pal = {
		"G": Color(0.15, 0.52, 0.12),
		"B": Color(0.40, 0.25, 0.08),
		".": Color(0, 0, 0, 0),
	}
	return _tex(rows, pal)

func make_bush() -> ImageTexture:
	var rows = [
		".GGG.GGG.",
		"GGGGGGGGG",
		"GGGGGGGGG",
		".GGGGGGG.",
		"..GGGGG..",
	]
	var pal = {
		"G": Color(0.20, 0.58, 0.15),
		".": Color(0, 0, 0, 0),
	}
	return _tex(rows, pal)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _tex(rows: Array, palette: Dictionary) -> ImageTexture:
	if rows.is_empty():
		return ImageTexture.new()
	var cols = 0
	for r in rows:
		cols = max(cols, r.length())
	var w = cols * SCALE
	var h = rows.size() * SCALE
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for row in rows.size():
		var line: String = rows[row]
		for col in line.length():
			var ch = line[col]
			var color: Color = palette.get(ch, Color.TRANSPARENT)
			for px in SCALE:
				for py in SCALE:
					img.set_pixel(col * SCALE + px, row * SCALE + py, color)
	return ImageTexture.create_from_image(img)

func _circle_tex(r: int, center: Color, highlight: Color) -> ImageTexture:
	var sz = r * 2 * SCALE
	var img = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var cr = r * SCALE
	for x in sz:
		for y in sz:
			var dx = x - cr + 0.5
			var dy = y - cr + 0.5
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= cr:
				var t = dist / cr
				var c = center.lerp(highlight, clamp(1.0 - t * 1.5 + 0.3, 0, 1))
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _cross_tex(color: Color) -> ImageTexture:
	var rows = [
		"..CCC..",
		"..CCC..",
		"CCCCCCC",
		"CCCCCCC",
		"CCCCCCC",
		"..CCC..",
		"..CCC..",
	]
	return _tex(rows, {"C": color, ".": Color(0,0,0,0)})

func _bars_tex(color: Color) -> ImageTexture:
	var rows = [
		"B.B.B",
		"B.B.B",
		"B.B.B",
		"BBBBB",
		"BBBBB",
	]
	return _tex(rows, {"B": color, ".": Color(color.r, color.g, color.b, 0.25)})

# ── Sprite2D factory ──────────────────────────────────────────────────────────
func sprite_from(tex: ImageTexture) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex
	return s
