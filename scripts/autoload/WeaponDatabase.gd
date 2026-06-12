extends Node

# All weapon data keyed by id.
# type: "melee" or "ranged"
# Melee props: range (px), arc (deg), can_cancel_bullets=true
# Ranged props: bullet_speed, bullet_count, spread (deg), ammo_max
# Extra behaviors stored in "props" dict.
var weapons: Dictionary = {}

func _ready():
	_register_melee("short_sword",      "短剑",       25,  3.0, 80,  90,  {})
	_register_melee("broadsword",       "宽剑",       60,  1.2, 90,  120, {})
	_register_melee("dagger",           "匕首",       15,  6.0, 60,  60,  {"dual": true})
	_register_melee("spear",            "长矛",       35,  2.0, 130, 45,  {})
	_register_melee("war_hammer",       "战锤",       80,  0.8, 85,  90,  {"knockback": 400.0})
	_register_melee("whip",             "鞭子",       20,  2.5, 150, 180, {})
	_register_melee("battle_axe",       "战斧",       55,  1.5, 85,  120, {})
	_register_melee("katana",           "武士刀",     40,  2.5, 90,  90,  {"dash": true})
	_register_melee("scythe",           "大镰刀",     50,  1.0, 105, 180, {})
	_register_melee("shield_bash",      "盾击",       20,  1.5, 70,  60,  {"block": true})

	_register_ranged("pistol",          "手枪",       15,  2.0, 400, 1,  0,  60,  {})
	_register_ranged("smg",             "冲锋枪",     10,  8.0, 450, 1,  5,  120, {})
	_register_ranged("shotgun",         "霰弹枪",     15,  1.0, 380, 6,  20, 60,  {})
	_register_ranged("sniper",          "狙击枪",     80,  0.5, 800, 1,  0,  25,  {})
	_register_ranged("rocket_launcher", "火箭炮",     100, 0.5, 300, 1,  0,  15,  {"explosive": true, "explosion_radius": 80.0})
	_register_ranged("fire_staff",      "火焰法杖",   20,  1.5, 300, 1,  5,  80,  {"fire_dot": true, "element": "fire"})
	_register_ranged("ice_staff",       "冰霜法杖",   15,  1.5, 280, 1,  8,  80,  {"slow": true, "slow_factor": 0.4, "element": "ice"})
	_register_ranged("lightning_staff", "闪电法杖",   25,  1.2, 350, 1,  0,  60,  {"chain": true, "chain_range": 150.0, "element": "lightning"})
	_register_ranged("crossbow",        "弩",         45,  1.0, 500, 1,  0,  40,  {"piercing": true})
	_register_ranged("grenade_launcher","榴弹炮",     70,  0.7, 250, 1,  0,  20,  {"explosive": true, "bouncing": true, "explosion_radius": 80.0})
	_register_ranged("flamethrower",    "火焰喷射器", 8,   15.0,200, 1,  15, 200, {"continuous": true, "element": "fire"})
	_register_ranged("laser_gun",       "激光枪",     30,  3.0, 650, 1,  0,  90,  {"laser": true})
	_register_ranged("boomerang",       "回旋镖",     25,  1.5, 350, 1,  0,  1,   {"returns": true})
	_register_ranged("bow",             "弓箭",       35,  1.0, 450, 1,  0,  50,  {"charged": true})
	_register_ranged("machine_gun",     "机枪",       12,  10.0,500, 1,  3,  150, {})
	_register_ranged("plasma_gun",      "等离子枪",   40,  1.5, 400, 1,  0,  60,  {"piercing": true, "element": "plasma"})
	_register_ranged("minigun",         "加特林",     8,   15.0,480, 1,  5,  300, {"windup": true, "windup_time": 1.0})
	_register_ranged("revolver",        "左轮手枪",   60,  1.5, 450, 1,  0,  24,  {})
	_register_ranged("railgun",         "轨道炮",     120, 0.3, 900, 1,  0,  10,  {"piercing": true})
	_register_ranged("holy_staff",      "神圣法杖",   20,  1.5, 250, 1,  0,  60,  {"homing": true, "element": "holy"})

	# ── 稀有精英掉落武器 ──────────────────────────────────────────────────────
	_register_ranged("void_cannon",   "虚空炮",     150, 0.4, 620, 1,  0,  12,  {"piercing": true, "explosive": true, "explosion_radius": 70.0, "rare": true})
	_register_ranged("thunder_bow",   "雷鸣弓",     65,  0.9, 580, 3,  12, 24,  {"chain": true, "chain_range": 160.0, "element": "lightning", "rare": true})
	_register_ranged("frozen_gale",   "冰霜疾风",   32,  1.2, 300, 5,  22, 35,  {"slow": true, "slow_factor": 0.12, "element": "ice", "rare": true})
	_register_melee ("dragon_fang",   "龙牙",       110, 2.2, 115, 120, {"dash": true, "knockback": 350.0, "rare": true})
	_register_melee ("holy_sword",    "圣剑",       80,  2.8, 105, 90,  {"knockback": 280.0, "element": "holy", "rare": true})

func _register_melee(id: String, dname: String, damage: float, fire_rate: float,
		range_px: float, arc_deg: float, props: Dictionary):
	weapons[id] = {
		"id": id, "name": dname, "type": "melee",
		"damage": damage, "fire_rate": fire_rate,
		"range": range_px, "arc": arc_deg,
		"can_cancel_bullets": true,
		"props": props,
		"color": Color(0.8, 0.55, 0.15)
	}

func _register_ranged(id: String, dname: String, damage: float, fire_rate: float,
		bullet_speed: float, bullet_count: int, spread: float,
		ammo_max: int, props: Dictionary):
	weapons[id] = {
		"id": id, "name": dname, "type": "ranged",
		"damage": damage, "fire_rate": fire_rate,
		"bullet_speed": bullet_speed, "bullet_count": bullet_count,
		"spread": spread, "ammo_max": ammo_max, "ammo": ammo_max,
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

func restore_ammo(id: String):
	if weapons.has(id):
		weapons[id].ammo = weapons[id].ammo_max
