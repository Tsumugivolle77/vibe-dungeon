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
	_register_melee("dagger",           "匕首",       15,  6.0, 60,  60,  0,  {"dual": true})
	_register_melee("whip",             "鞭子",       20,  2.5, 150, 180, 0,  {})
	# Energy-cost melee: heavier/special attacks
	_register_melee("broadsword",       "宽剑",       60,  1.2, 90,  120, 4,  {})
	_register_melee("spear",            "长矛",       35,  2.0, 130, 45,  3,  {})
	_register_melee("war_hammer",       "战锤",       80,  0.8, 85,  90,  7,  {"knockback": 400.0})
	_register_melee("battle_axe",       "战斧",       55,  1.5, 85,  120, 5,  {})
	_register_melee("katana",           "武士刀",     40,  2.5, 90,  90,  3,  {"dash": true})
	_register_melee("scythe",           "大镰刀",     50,  1.0, 105, 180, 6,  {})
	_register_melee("shield_bash",      "盾击",       20,  1.5, 70,  60,  4,  {"block": true})

	# 0-cost ranged: basic guns, always usable
	_register_ranged("pistol",          "手枪",       15,  2.0, 400, 1,  0,  0,  {})
	_register_ranged("smg",             "冲锋枪",     10,  8.0, 450, 1,  5,  0,  {})
	_register_ranged("machine_gun",     "机枪",       12,  10.0,500, 1,  3,  0,  {})
	_register_ranged("revolver",        "左轮手枪",   60,  1.5, 450, 1,  0,  0,  {})
	# Energy-cost ranged: powerful/special weapons
	_register_ranged("shotgun",         "霰弹枪",     15,  1.0, 380, 6,  20, 5,  {})
	_register_ranged("sniper",          "狙击枪",     80,  0.5, 800, 1,  0,  4,  {})
	_register_ranged("rocket_launcher", "火箭炮",     100, 0.5, 300, 1,  0,  15, {"explosive": true, "explosion_radius": 80.0})
	_register_ranged("fire_staff",      "火焰法杖",   18,  1.4, 300, 3,  20, 4,  {"fire_dot": true, "element": "fire", "trail": true})
	_register_ranged("ice_staff",       "冰霜法杖",   14,  1.4, 280, 3,  24, 4,  {"slow": true, "slow_factor": 0.4, "element": "ice", "trail": true})
	_register_ranged("lightning_staff", "闪电法杖",   22,  1.1, 350, 4,  18, 5,  {"chain": true, "chain_range": 150.0, "element": "lightning", "trail": true})
	_register_ranged("crossbow",        "弩",         45,  1.0, 500, 1,  0,  3,  {"piercing": true})
	_register_ranged("grenade_launcher","榴弹炮",     70,  0.7, 250, 1,  0,  10, {"explosive": true, "bouncing": true, "explosion_radius": 80.0})
	_register_ranged("flamethrower",    "火焰喷射器", 8,   15.0,200, 1,  15, 1,  {"continuous": true, "element": "fire"})
	_register_ranged("laser_gun",       "激光枪",     30,  3.0, 650, 1,  0,  3,  {"laser": true})
	_register_ranged("boomerang",       "回旋镖",     25,  1.5, 350, 1,  0,  8,  {"returns": true})
	_register_ranged("bow",             "弓箭",       35,  1.0, 450, 1,  0,  5,  {"charged": true})
	_register_ranged("plasma_gun",      "等离子枪",   40,  1.5, 400, 1,  0,  5,  {"piercing": true, "element": "plasma"})
	_register_ranged("minigun",         "加特林",     8,   15.0,480, 1,  5,  1,  {"windup": true, "windup_time": 1.0})
	_register_ranged("railgun",         "轨道炮",     120, 0.3, 900, 1,  0,  20, {"piercing": true})
	_register_ranged("holy_staff",      "神圣法杖",   18,  1.4, 250, 3,  16, 5,  {"homing": true, "element": "holy", "trail": true})

	# ── 稀有精英掉落武器 ──────────────────────────────────────────────────────
	_register_ranged("void_cannon",  "虚空炮",    150, 0.4, 620, 1, 0,  25, {"piercing": true, "explosive": true, "explosion_radius": 70.0, "rare": true})
	_register_ranged("thunder_bow",  "雷鸣弓",    65,  0.9, 580, 3, 12, 8,  {"chain": true, "chain_range": 160.0, "element": "lightning", "rare": true})
	_register_ranged("frozen_gale",  "冰霜疾风",  32,  1.2, 300, 5, 22, 5,  {"slow": true, "slow_factor": 0.12, "element": "ice", "rare": true})
	_register_melee ("dragon_fang",  "龙牙",      110, 2.2, 115, 120, 8,  {"dash": true, "knockback": 350.0, "rare": true})
	_register_melee ("holy_sword",   "圣剑",      80,  2.8, 105, 90,  6,  {"knockback": 280.0, "element": "holy", "rare": true})

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

func get_all_weapon_ids() -> Array:
	return weapons.keys()
