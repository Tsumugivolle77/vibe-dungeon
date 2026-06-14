extends Node

# All weapon data keyed by id.
# type: "melee" or "ranged"
# Melee props: range (px), arc (deg), can_cancel_bullets=true
# Ranged props: bullet_speed, bullet_count, spread (deg)
# energy_cost: energy consumed per shot/swing from the player's energy pool.
# Extra behaviors stored in "props" dict.
var weapons: Dictionary = {}

func _ready():
	# 0-cost melee: basic attacks, always usable
	_register_melee("short_sword",      "短剑",       25,  3.0, 80,  90,  0,  {})
	_register_melee("dagger",           "匕首",       25,  6.0, 60,  60,  0,  {"dual": true})
	_register_melee("whip",             "鞭子",       25,  2.5, 150, 180, 0,  {})
	# Energy-cost melee: heavier/special attacks
	_register_melee("broadsword",       "宽剑",       25,  1.2, 90,  120, 1,  {})
	_register_melee("spear",            "长矛",       25,  2.0, 130, 45,  1,  {})
	_register_melee("war_hammer",       "战锤",       35,  0.8, 85,  90,  3,  {"knockback": 400.0})
	_register_melee("battle_axe",       "战斧",       31,  1.5, 85,  120, 2,  {})
	_register_melee("katana",           "武士刀",     28,  2.5, 90,  90,  2,  {"dash": true})
	_register_melee("scythe",           "大镰刀",     40,  1.0, 105, 180, 3,  {})
	_register_melee("shield_bash",      "盾击",       25,  1.25,70,  60,  1,  {"block": true})

	# 0-cost ranged: basic guns, always usable
	_register_ranged("pistol",          "手枪",       15,  2.0, 400, 1,  0,  0,  {})
	_register_ranged("smg",             "冲锋枪",     15,  8.0, 450, 1,  5,  1,  {})
	_register_ranged("machine_gun",     "机枪",       15,  10.0,500, 1,  3,  1,  {})
	_register_ranged("revolver",        "左轮手枪",   35,  1.5, 450, 1,  0,  2,  {})
	# Energy-cost ranged: powerful/special weapons
	_register_ranged("shotgun",         "霰弹枪M1",   20,  1.0, 380, 6,  20, 3,  {})
	_register_ranged("shotgun_m2",      "霰弹枪M2",   22,  1.0, 360, 6,  22, 3,  {"bouncing": true, "max_bounces": 2})
	_register_ranged("shotgun_m3",      "霰弹枪M3",   16,  0.9, 320, 9,  0,  4,  {"expanding_ring": true})
	_register_ranged("sniper",          "狙击枪",     50,  0.5, 800, 1,  0,  4,  {})
	_register_ranged("rocket_launcher", "火箭炮",     40, 0.5, 300, 1,  0,  10, {"explosive": true, "explosion_radius": 80.0})
	_register_ranged("cannon",          "加农炮",     35,  0.6, 340, 1,  0,  8, {"explosive": true, "explosion_radius": 95.0})
	_register_ranged("fire_staff",      "火焰法杖",   28,  1.4, 300, 5,  20, 4,  {"fire_dot": true, "bouncing": true, "element": "fire", "trail": true, "fire_trail": true})
	_register_ranged("ice_staff",       "冰霜法杖",   28,  1.4, 280, 5,  24, 4,  {"slow": true, "bouncing": true, "slow_factor": 0.4, "element": "ice", "trail": true})
	_register_ranged("lightning_staff", "闪电法杖",   20,  1.0, 300, 15, 0,  6,  {"ring": true, "bouncing": true, "max_bounces": 4, "element": "lightning", "trail": true})
	_register_ranged("crossbow",        "弩",         25,  1.0, 500, 1,  0,  3,  {"piercing": true})
	_register_ranged("grenade_launcher","榴弹炮",     35,  0.7, 250, 1,  0,  8, {"explosive": true, "bouncing": true, "explosion_radius": 80.0})
	_register_ranged("flamethrower",    "火焰喷射器", 20,   15.0,200, 1,  15, 1,  {"continuous": true, "element": "fire"})
	_register_ranged("laser_gun",       "激光枪",     30,  3.0, 650, 1,  0,  1,  {"laser": true})
	_register_ranged("boomerang",       "回旋镖",     25,  1.5, 350, 1,  0,  4,  {"returns": true})
	_register_ranged("bow",             "弓箭",       35,  1.0, 450, 1,  0,  2,  {"charged": true})
	_register_ranged("plasma_gun",      "等离子枪",   40,  1.5, 400, 3,  0,  3,  {"bouncing": true, "max_bounces": 2, "element": "plasma", "paralyze_chance": 0.5})
	_register_ranged("minigun",         "加特林",     18,   9.0, 480, 5,  24, 2,  {})
	_register_ranged("railgun",         "轨道炮",     40, 0.3, 900, 1,  0,  10, {"laser": true, "piercing": true, "clear_bullets": true})
	_register_ranged("holy_staff",      "神圣法杖",   28,  1.4, 250, 8,  16, 5,  {"holy_strike": true, "element": "holy"})

	# ── 稀有精英掉落武器 ──────────────────────────────────────────────────────
	_register_ranged("star_requiem", "星灭者",     35,  0.7, 300, 3,  16, 10, {"homing": true, "explosive": true, "explosion_radius": 100.0})
	_register_ranged("void_cannon",  "虚空炮",    45, 0.4, 620, 3, 0,  10, {"piercing": true, "explosive": true, "explosion_radius": 150.0, "black_hole": true, "rare": true})
	_register_ranged("thunder_bow",  "雷鸣弓",    35,  0.9, 580, 3, 12, 4,  {"chain": true, "chain_range": 160.0, "element": "lightning", "thunder_strike": true, "rare": true})
	_register_ranged("frozen_gale",  "冰霜疾风",  60,  1.0, 300, 1, 22, 3,  {"summon_tornado": true, "element": "ice", "rare": true})
	_register_melee ("dragon_fang",  "龙牙",      40, 2.2, 115, 120, 4,  {"dash": true, "summon_dragons": true, "knockback": 350.0, "rare": true})
	_register_melee ("holy_sword",   "圣剑",      40,  2.8, 105, 90,  3,  {"knockback": 280.0, "element": "holy", "summon_sword_qi": true, "rare": true})

	# ── Boss 专属稀有掉落 (one per boss) ───────────────────────────────────────
	_register_melee ("kings_greataxe", "哥布林王巨斧", 45, 1.6, 135, 150, 5, {"knockback": 420.0, "lava_pool": true, "rare": true, "boss": true})
	_register_ranged("slime_burst",    "史莱姆爆弹",   38,  1.0, 300, 3, 30, 2, {"explosive": true, "bouncing": true, "max_bounces": 3, "explosion_radius": 72.0, "summon_ally": "slime", "summon_chance": 0.2, "rare": true, "boss": true})
	_register_ranged("treant_staff",   "古树之灵杖",   20,  1.0, 300, 14, 0, 3, {"ring": true, "bouncing": true, "max_bounces": 3, "element": "fire", "summon_ally": "vine", "summon_chance": 0.16, "rare": true, "boss": true})
	_register_ranged("fairy_scepter",  "妖精女王杖",   30,  1.4, 380, 6, 0,  3, {"ring": true, "homing": true, "element": "holy", "summon_ally": "fairy", "summon_chance": 0.2, "rare": true, "boss": true})
	_register_ranged("mandrake_rod",   "曼陀罗魔杖",   45,  0.8, 420, 8, 0,  4, {"ring": true, "explosive": true, "explosion_radius": 60.0, "lava_pool": true, "element": "plasma", "rare": true, "boss": true})

func _register_melee(id: String, dname: String, damage: float, fire_rate: float,
		range_px: float, arc_deg: float, energy_cost: int, props: Dictionary):
	weapons[id] = {
		"id": id, "name": dname, "type": "melee",
		"damage": damage, "fire_rate": fire_rate,
		"range": range_px, "arc": arc_deg,
		"energy_cost": energy_cost,
		"can_cancel_bullets": true,
		"props": props,
		"color": Color(0.8, 0.55, 0.15)
	}

func _register_ranged(id: String, dname: String, damage: float, fire_rate: float,
		bullet_speed: float, bullet_count: int, spread: float,
		energy_cost: int, props: Dictionary):
	weapons[id] = {
		"id": id, "name": dname, "type": "ranged",
		"damage": damage, "fire_rate": fire_rate,
		"bullet_speed": bullet_speed, "bullet_count": bullet_count,
		"spread": spread,
		"energy_cost": energy_cost,
		"can_cancel_bullets": false,
		"props": props,
		"color": Color(0.3, 0.65, 0.9)
	}

func get_weapon(id: String) -> Dictionary:
	if weapons.has(id):
		return weapons[id].duplicate(true)
	return {}

# A rough power score: sustained output (damage × rate × pellets) plus premiums for
# special behaviours, energy cost, and rarity. Used to scale shop prices.
func weapon_power(id: String) -> float:
	var w = get_weapon(id)
	if w.is_empty():
		return 1.0
	var dps := float(w.get("damage", 10.0)) * float(w.get("fire_rate", 1.0)) \
		* float(w.get("bullet_count", 1))
	var p: Dictionary = w.get("props", {})
	var mult := 1.0
	if p.get("explosive"): mult += 0.4
	if p.get("piercing"):  mult += 0.25
	if p.get("bouncing"):  mult += 0.2
	if p.get("homing"):    mult += 0.3
	if p.get("chain"):     mult += 0.3
	if p.get("laser"):     mult += 0.3
	if p.get("ring"):      mult += 0.2
	if p.get("rare"):      mult += 1.0
	return dps * mult + float(w.get("energy_cost", 0)) * 2.0

# Gold price for a weapon in shops — stronger weapons cost more (clamped).
func weapon_price(id: String) -> int:
	return int(clampf(25.0 + weapon_power(id) * 0.55, 30.0, 220.0))

func get_all_weapon_ids() -> Array:
	return weapons.keys()
