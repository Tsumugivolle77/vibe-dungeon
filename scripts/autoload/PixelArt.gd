extends Node
# Generates ImageTexture sprites from code-defined pixel arrays.
# Pixel scale = 3 → each "pixel" is a 3×3 block of real pixels.

const SCALE = 3
const PICKUP_SCALE = 2  # smaller scale for pickup/icon sprites

# ── Palette definitions ──────────────────────────────────────────────────────
# Chibi cat-girl protagonist: silver hair, cat ears, heterochromia (gold + blue),
# navy school swimsuit, white cat-paw gloves/boots, blue-striped thigh-highs.
const PAL_LOLI = {
	"H": Color(0.88, 0.90, 0.96),   # silver hair bright
	"h": Color(0.70, 0.74, 0.86),   # hair shadow
	"F": Color(0.99, 0.90, 0.84),   # skin
	"O": Color(1.00, 0.66, 0.12),   # gold/orange eye (left)
	"E": Color(0.25, 0.55, 0.95),   # blue eye (right)
	"P": Color(0.98, 0.66, 0.70),   # pink (ear inner, paw pads, blush)
	"m": Color(0.86, 0.40, 0.46),   # mouth
	"R": Color(0.86, 0.16, 0.20),   # red collar
	"N": Color(0.17, 0.19, 0.34),   # navy swimsuit
	"B": Color(0.46, 0.74, 0.93),   # blue stocking stripe
	"W": Color(0.98, 0.99, 1.00),   # white gloves / paws / stockings
	".": Color(0, 0, 0, 0),
}
# Shared upper body rows (cat ears + head + torso) – constant across animation frames
const _LOLI_UPPER = [
	"...WW....WW...",
	"..WPPW..WPPW..",
	"..WHHHHHHHHW..",
	"..HHHHHHHHHH..",
	".HHHHHHHHHHHH.",
	".HHFFFFFFFFHH.",
	".HHFOOFFEEFHH.",
	".HhFPFFFFPFhH.",
	"...FFFmmFFF...",
	"....RRRRRR....",
	"..WNNNNNNNNW..",
	".WWNNNNNNNNWW.",
	"..WPNNNNNNPW..",
	"...NNNNNNNN...",
]
# Striped-stocking leg rows: idle / walk-A (left step) / walk-B (right step)
const _LOLI_IDLE = [
	"...WWW..WWW...",
	"...BBB..BBB...",
	"...WWW..WWW...",
	"..WWWW..WWWW..",
]
const _LOLI_WALK_A = [   # left leg slightly forward
	"..WWW...WWW...",
	"..BBB...BBB...",
	"..WWW...WWW...",
	".WWWW...WWWW..",
]
const _LOLI_WALK_B = [   # right leg slightly forward
	"...WWW...WWW..",
	"...BBB...BBB..",
	"...WWW...WWW..",
	"..WWWW...WWWW.",
]
# Keep PAL_KNIGHT alias for any code that might reference it directly
const PAL_KNIGHT = PAL_LOLI

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

# ── Goblin Archer ──────────────────────────────────────────────────────────────
const PAL_ARCHER = {
	"G": Color(0.30, 0.62, 0.24),   # green skin
	"g": Color(0.20, 0.45, 0.15),   # dark green
	"E": Color(0.90, 0.18, 0.18),   # red eye
	"C": Color(0.50, 0.32, 0.14),   # leather tunic
	"B": Color(0.55, 0.35, 0.12),   # bow limb
	"S": Color(0.85, 0.82, 0.70),   # bowstring
	".": Color(0, 0, 0, 0),
}
const SPR_ARCHER = [
	"..gGGGg..B",
	".GGGGGGGSB",
	".GEGgGEG.B",
	".GGGGGGGSB",
	"..GCCCG..B",
	".CCCCCCC.B",
	".CC...CC.B",
	"..g...g...",
]

# ── Elite Goblin ─────────────────────────────────────────────────────────────
const PAL_ELITE = {
	"G": Color(0.22, 0.50, 0.18),   # darker green skin
	"g": Color(0.14, 0.36, 0.12),
	"E": Color(1.00, 0.30, 0.10),   # fierce orange-red eye
	"T": Color(0.95, 0.92, 0.80),   # tusks
	"H": Color(0.85, 0.80, 0.30),   # horns
	"A": Color(0.55, 0.57, 0.62),   # steel armor
	"a": Color(0.38, 0.40, 0.45),   # armor shadow
	"S": Color(0.72, 0.55, 0.20),   # bronze shield
	".": Color(0, 0, 0, 0),
}
const SPR_ELITE = [
	"...H...H...",
	"..gGGGGGg..",
	"..GEGgGEG..",
	"..GGGGGGG..",
	"..GgTTTgG..",
	"SSAAAAAAA..",
	"SSAaAAaAA..",
	"SSAAAAAAA..",
	"S..G...G...",
	"...G...G...",
	"...g...g...",
]

# ── Tree Monster ─────────────────────────────────────────────────────────────
const PAL_TREE_MON = {
	"G": Color(0.20, 0.55, 0.18),   # canopy green
	"g": Color(0.14, 0.40, 0.13),   # canopy shadow
	"T": Color(0.42, 0.28, 0.12),   # bark
	"t": Color(0.30, 0.18, 0.07),   # bark shadow / roots
	"E": Color(0.98, 0.85, 0.20),   # glowing yellow eyes
	"M": Color(0.10, 0.05, 0.03),   # mouth maw
	".": Color(0, 0, 0, 0),
}
const SPR_TREE_MON = [
	"...GGGGGG...",
	"..GGGGGGGG..",
	".GGgGGGGgGG.",
	".GGGGGGGGGG.",
	"..GGGGGGGG..",
	"...TTTTTT...",
	"..TETTTTET..",
	"..TTTMMTTT..",
	"..TTMMMMTT..",
	"..TtTTTTtT..",
	"...T....T...",
	"...t....t...",
]

# ── Vine Creature ────────────────────────────────────────────────────────────
const PAL_VINE = {
	"V": Color(0.22, 0.60, 0.16),   # vine green
	"v": Color(0.13, 0.42, 0.10),   # vine shadow
	"C": Color(0.55, 0.85, 0.30),   # bright core flesh
	"E": Color(0.92, 0.25, 0.55),   # pink core eye
	".": Color(0, 0, 0, 0),
}
const SPR_VINE = [
	"V..vVv..V.",
	".V.VVV.V..",
	"..VVVVV...",
	".vVCCCVv..",
	".VCCECCV..",
	".vVCCCVv..",
	"..VVVVV...",
	".V.VVV.V..",
	"V..vVv..V.",
]

# ── Boss: Goblin King ─────────────────────────────────────────────────────────
const PAL_GOBLIN_KING = {
	"G": Color(0.26, 0.55, 0.20), "g": Color(0.16, 0.38, 0.13),
	"E": Color(1.00, 0.25, 0.12), "T": Color(0.95, 0.92, 0.80),
	"C": Color(0.98, 0.82, 0.15), "A": Color(0.58, 0.60, 0.66),
	"a": Color(0.40, 0.42, 0.48), "K": Color(0.65, 0.10, 0.12),
	".": Color(0, 0, 0, 0),
}
const SPR_GOBLIN_KING = [
	"...C.C.C.....",
	"...CCCCC.....",
	"..gGGGGGg....",
	"..GEGgGEG....",
	"..GGGGGGG....",
	"..GgTTTgG....",
	".AAAAAAAAA...",
	".AaAAAAaAA...",
	".KAAAAAAAK...",
	".K.G...G.K...",
	"...G...G.....",
	"...g...g.....",
]

# ── Boss: Slime Mother ────────────────────────────────────────────────────────
const PAL_SLIME_MOTHER = {
	"S": Color(0.30, 0.80, 0.34), "s": Color(0.18, 0.58, 0.22),
	"E": Color(0.10, 0.25, 0.10), "H": Color(0.62, 0.98, 0.64, 0.85),
	"C": Color(0.98, 0.82, 0.15), ".": Color(0, 0, 0, 0),
}
const SPR_SLIME_MOTHER = [
	"...C.C.C....",
	"...CCCCC....",
	"..SSSSSSS...",
	".SSSSSSSSS..",
	"SSSSSSSSSSS.",
	"SSEHSSSEHSS.",
	"SSSSSSSSSSS.",
	"SSSSSSSSSSS.",
	".sSSSSSSSs..",
	"..sSSSSSs...",
	"...sssss....",
]

# ── Boss: Ancient Treant ──────────────────────────────────────────────────────
const PAL_TREANT = {
	"G": Color(0.22, 0.58, 0.20), "g": Color(0.15, 0.42, 0.14),
	"T": Color(0.44, 0.29, 0.13), "t": Color(0.30, 0.18, 0.07),
	"E": Color(1.00, 0.88, 0.22), "M": Color(0.08, 0.04, 0.02),
	".": Color(0, 0, 0, 0),
}
const SPR_TREANT = [
	"....GGGGGG....",
	"..GGGGGGGGGG..",
	".GGGGGGGGGGGG.",
	".GGgGGGGGGgGG.",
	"..GGGGGGGGGG..",
	"...TTTTTTTT...",
	"..TTETTTTETT..",
	"..TTTTMMTTTT..",
	"..TTTMMMMTTT..",
	"..TTMMMMMMTT..",
	"..TtTTTTTTtT..",
	"...TT....TT...",
	"...tt....tt...",
]

# ── Boss: Fairy Queen ─────────────────────────────────────────────────────────
const PAL_FAIRY_QUEEN = {
	"P": Color(0.90, 0.30, 0.84), "p": Color(0.66, 0.18, 0.62),
	"W": Color(0.96, 0.92, 1.00, 0.80), "E": Color(0.98, 0.95, 0.30),
	"G": Color(0.55, 0.95, 0.60, 0.55), "C": Color(0.98, 0.82, 0.15),
	".": Color(0, 0, 0, 0),
}
const SPR_FAIRY_QUEEN = [
	"....CCC......",
	"W...C.C...W..",
	"GW.PPPPP.WG..",
	"GWPPPPPPPWG..",
	"WWPEPPPEPWW..",
	"GWPPPPPPPWG..",
	"GW.PPPPP.WG..",
	"W...PPP...W..",
	"....P.P......",
]

# ── Public API ────────────────────────────────────────────────────────────────
func make_goblin_king() -> ImageTexture:   return _tex(SPR_GOBLIN_KING,  PAL_GOBLIN_KING)
func make_slime_mother() -> ImageTexture:  return _tex(SPR_SLIME_MOTHER, PAL_SLIME_MOTHER)
func make_ancient_treant() -> ImageTexture:return _tex(SPR_TREANT,       PAL_TREANT)
func make_fairy_queen() -> ImageTexture:   return _tex(SPR_FAIRY_QUEEN,  PAL_FAIRY_QUEEN)

func make_goblin_archer() -> ImageTexture: return _tex(SPR_ARCHER,   PAL_ARCHER)
func make_elite_goblin() -> ImageTexture:  return _tex(SPR_ELITE,    PAL_ELITE)
func make_tree_monster() -> ImageTexture:  return _tex(SPR_TREE_MON, PAL_TREE_MON)
func make_vine_creature() -> ImageTexture: return _tex(SPR_VINE,     PAL_VINE)

func _loli_tex(leg_rows: Array) -> ImageTexture:
	return _tex(_LOLI_UPPER + leg_rows, PAL_LOLI)

func make_knight() -> ImageTexture:
	return _loli_tex(_LOLI_IDLE)

func make_loli_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()

	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 2.0)
	sf.add_frame("idle", _loli_tex(_LOLI_IDLE),   1.0)

	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 8.0)
	sf.add_frame("walk", _loli_tex(_LOLI_IDLE),   1.0)
	sf.add_frame("walk", _loli_tex(_LOLI_WALK_A), 1.0)
	sf.add_frame("walk", _loli_tex(_LOLI_IDLE),   1.0)
	sf.add_frame("walk", _loli_tex(_LOLI_WALK_B), 1.0)

	return sf

func make_goblin() -> ImageTexture:      return _tex(SPR_GOBLIN,       PAL_GOBLIN)
func make_slime() -> ImageTexture:       return _tex(SPR_SLIME,        PAL_SLIME)
func make_spirit() -> ImageTexture:      return _tex(SPR_FOREST_SPIRIT,PAL_FOREST_SPIRIT)
func make_mushroom() -> ImageTexture:    return _tex(SPR_MUSHROOM,     PAL_MUSHROOM)
func make_golem() -> ImageTexture:       return _tex(SPR_GOLEM,        PAL_GOLEM)
func make_fairy() -> ImageTexture:       return _tex(SPR_FAIRY,        PAL_FAIRY)
func make_mandrake() -> ImageTexture:    return _tex(SPR_MANDRAKE,     PAL_MANDRAKE)

func make_health_orb() -> ImageTexture:
	return _tex_p([
		".HH..HH.",
		"HHRRRRRH",
		"RRRRRRRR",
		"RRRRRRRR",
		".RRRRRR.",
		"..RRRR..",
		"...RR...",
	], {"R": Color(0.92, 0.12, 0.12), "H": Color(1.00, 0.55, 0.55), ".": Color(0,0,0,0)})

func make_ammo_orb() -> ImageTexture:
	return _tex_p([
		"...YYY..",
		"..YYY...",
		".YYYYYY.",
		"YYYYYYYY",
		"....YYY.",
		"...YYY..",
		"..YYY...",
		"...YY...",
	], {"Y": Color(0.95, 0.88, 0.10), ".": Color(0,0,0,0)})

func make_gold_coin() -> ImageTexture:
	return _tex_p([
		"...DDD...",
		"..DYYYD..",
		".DYHYYYD.",
		"DYYHYYYYD",
		"DYYYYYYYD",
		".DYYYYYD.",
		"..DYYYD..",
		"...DDD...",
	], {"D": Color(0.70, 0.50, 0.05), "Y": Color(0.98, 0.82, 0.20), "H": Color(1.00, 0.95, 0.60), ".": Color(0,0,0,0)})

func make_health_pack() -> ImageTexture:
	return _tex_p([
		"..CCC..",
		"..CCC..",
		"CCCCCCC",
		"CCCCCCC",
		"CCCCCCC",
		"..CCC..",
		"..CCC..",
	], {"C": Color(0.88, 0.05, 0.05), ".": Color(0,0,0,0)})

func make_ammo_pack() -> ImageTexture:
	return _tex_p([
		"B.B.B",
		"B.B.B",
		"B.B.B",
		"BBBBB",
		"BBBBB",
	], {"B": Color(0.05, 0.38, 0.88), ".": Color(0.05, 0.15, 0.35, 0.25)})

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

# ── Weapon icons ──────────────────────────────────────────────────────────────
const WICON_SWORD     = [".......W","......WW","....GWW.","...GWWW.","..BBWW..",".BB..W..","BB......"]
const WICON_DAGGER    = ["......WW","....GGWW","..BBGG..",".BB.....","BB......"]
const WICON_HAMMER    = ["WWWWWWWW","WWWWWWWW","WWWWWWWW","...BB...","...BB...","...BB...","...BB..."]
const WICON_AXE       = ["WWWW....","WWWWWWW.","WWWW....","...BB...","...BB...","...BB...","...BB..."]
const WICON_SPEAR     = ["...WW...","...WW...","..WWWW..",".WWWWWW.","...BB...","...BB...","...BB...","...BB..."]
const WICON_PISTOL    = ["...WWWWW","..WWWWWW","WWWWWWWW","BBWW...W","BBBBBWWW",".BBB...."]
const WICON_SMG       = ["..WWWWWW",".WWWWWWW","WWWWWWWW","BBBWWWWW","BBBBB...",".BBBBB.."]
const WICON_SHOTGUN   = ["WWWWWWWW","WWWWWWWW","BBBWWWWW","BBBWWWWW","BBBB....",".BBB...."]
const WICON_SNIPER    = ["WWWWWWWW","BWWWWWWW","BBWWWWWW","BBBWWWWW","BBBB....","BBBBB..."]
const WICON_STAFF     = ["..XXXX..",".XXXXXX.",".XXEXX..",".XXXXXX.","..XXXX..","....B...","....B...","....B...","....B..."]
const WICON_BOW       = ["W.......","WW......","WWWW....","WWWWWWWW","WWWW....","WW......","W.......","......WA"]
const WICON_CROSSBOW  = ["WWWWWWWW","...W....","...W....",".WWWWWW.","...W....","...W...."]
const WICON_ROCKET    = ["WWWWWWWW","WWWWWWWW","WWWWWWWW","BBBWWWWW","BBBB....",".BBB...."]
const WICON_BOOMERANG = ["WWWWW...","..WWWWW.",".....WWW","..WWWWW.","WWWWW..."]
const WICON_LASER     = ["...LLLLL","..LLLLLL","BBLLLLLL","BBLLLLLL","..LLLLLL","...LLLLL"]

func make_weapon_icon(weapon_id: String) -> ImageTexture:
	var bp = {"W": Color(0.82,0.85,0.90), "G": Color(0.90,0.70,0.10), "B": Color(0.45,0.28,0.10), ".": Color(0,0,0,0)}
	var gp = {"W": Color(0.62,0.65,0.70), "B": Color(0.28,0.28,0.30), ".": Color(0,0,0,0)}
	match weapon_id:
		"short_sword","broadsword","spear","scythe":
			return _tex_p(WICON_SWORD, bp)
		"katana":
			return _tex_p(WICON_SWORD, {"W":Color(0.78,0.85,0.95),"G":Color(0.80,0.65,0.08),"B":Color(0.38,0.22,0.08),".":Color(0,0,0,0)})
		"holy_sword":
			return _tex_p(WICON_SWORD, {"W":Color(0.98,0.95,0.70),"G":Color(1.0,0.85,0.10),"B":Color(0.60,0.50,0.15),".":Color(0,0,0,0)})
		"dagger","whip":
			return _tex_p(WICON_DAGGER, bp)
		"dragon_fang":
			return _tex_p(WICON_DAGGER, {"W":Color(0.90,0.20,0.15),"G":Color(0.85,0.55,0.05),"B":Color(0.25,0.08,0.05),".":Color(0,0,0,0)})
		"war_hammer","shield_bash":
			return _tex_p(WICON_HAMMER, {"W":Color(0.62,0.62,0.65),"B":Color(0.45,0.28,0.10),".":Color(0,0,0,0)})
		"battle_axe":
			return _tex_p(WICON_AXE, {"W":Color(0.60,0.62,0.65),"B":Color(0.45,0.28,0.10),".":Color(0,0,0,0)})
		"pistol","revolver":
			return _tex_p(WICON_PISTOL, gp)
		"smg","machine_gun","minigun":
			return _tex_p(WICON_SMG, gp)
		"shotgun","grenade_launcher":
			return _tex_p(WICON_SHOTGUN, gp)
		"sniper","railgun":
			return _tex_p(WICON_SNIPER, gp)
		"crossbow":
			return _tex_p(WICON_CROSSBOW, {"W":Color(0.65,0.45,0.18),"B":Color(0.38,0.24,0.08),".":Color(0,0,0,0)})
		"rocket_launcher","flamethrower":
			return _tex_p(WICON_ROCKET, {"W":Color(0.45,0.45,0.48),"B":Color(0.32,0.32,0.35),".":Color(0,0,0,0)})
		"fire_staff":
			return _tex_p(WICON_STAFF, {"X":Color(0.95,0.42,0.05),"E":Color(1.0,0.85,0.10),"B":Color(0.45,0.28,0.10),".":Color(0,0,0,0)})
		"ice_staff","frozen_gale":
			return _tex_p(WICON_STAFF, {"X":Color(0.30,0.85,0.95),"E":Color(0.95,0.98,1.0),"B":Color(0.45,0.28,0.10),".":Color(0,0,0,0)})
		"lightning_staff":
			return _tex_p(WICON_STAFF, {"X":Color(0.92,0.88,0.10),"E":Color(1.0,1.0,0.80),"B":Color(0.45,0.28,0.10),".":Color(0,0,0,0)})
		"holy_staff":
			return _tex_p(WICON_STAFF, {"X":Color(1.0,0.88,0.30),"E":Color(1.0,1.0,0.95),"B":Color(0.55,0.42,0.12),".":Color(0,0,0,0)})
		"bow":
			return _tex_p(WICON_BOW, {"W":Color(0.65,0.42,0.14),"A":Color(0.82,0.85,0.90),".":Color(0,0,0,0)})
		"thunder_bow":
			return _tex_p(WICON_BOW, {"W":Color(0.65,0.42,0.14),"A":Color(0.92,0.88,0.10),".":Color(0,0,0,0)})
		"boomerang":
			return _tex_p(WICON_BOOMERANG, {"W":Color(0.72,0.52,0.18),".":Color(0,0,0,0)})
		"laser_gun","plasma_gun":
			return _tex_p(WICON_LASER, {"L":Color(0.10,0.85,0.95),"B":Color(0.28,0.28,0.30),".":Color(0,0,0,0)})
		"void_cannon":
			return _tex_p(WICON_SNIPER, {"W":Color(0.45,0.12,0.72),"B":Color(0.22,0.05,0.38),".":Color(0,0,0,0)})
		_:
			return _tex_p(WICON_PISTOL, gp)

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

func _tex_p(rows: Array, palette: Dictionary) -> ImageTexture:
	if rows.is_empty():
		return ImageTexture.new()
	var cols = 0
	for r in rows:
		cols = max(cols, r.length())
	var img = Image.create(cols * PICKUP_SCALE, rows.size() * PICKUP_SCALE, false, Image.FORMAT_RGBA8)
	for row in rows.size():
		var line: String = rows[row]
		for col in line.length():
			var color: Color = palette.get(line[col], Color.TRANSPARENT)
			for dy in PICKUP_SCALE:
				for dx in PICKUP_SCALE:
					img.set_pixel(col * PICKUP_SCALE + dx, row * PICKUP_SCALE + dy, color)
	return ImageTexture.create_from_image(img)

# ── Sprite2D factory ──────────────────────────────────────────────────────────
func sprite_from(tex: ImageTexture) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex
	return s
