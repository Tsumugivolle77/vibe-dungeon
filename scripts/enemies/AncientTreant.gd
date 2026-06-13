extends "res://scripts/enemies/BossBase.gd"

# Sublevel 3 boss — 远古树妖. Stationary tank: heavy seed barrages from all
# directions, aimed volleys, and summons forest minions in later phases.

const SPIRIT_SCENE  = "res://scenes/enemies/ForestSpirit.tscn"
const MUSHROOM_SCENE = "res://scenes/enemies/MushroomMan.tscn"

func _get_pixel_texture(): return PixelArt.make_ancient_treant()

func _on_ready_extra():
	max_hp     = 1300.0
	hp         = max_hp
	move_speed = 0.0     # rooted in place
	damage     = 16.0
	xp_value   = 400
	boss_drop_weapon = "treant_staff"
	body_color = Color(0.22, 0.58, 0.20)
	body_size  = Vector2(72, 72)
	body_rect.color    = body_color
	body_rect.size     = body_size
	body_rect.position = -body_size * 0.5
	super()

func _boss_ai(_delta: float):
	velocity = Vector2.ZERO
	if action_timer > 0.0:
		return

	match phase:
		1:
			action_timer = 2.6
			if randi() % 2 == 0:
				ring(12, 150.0)
			else:
				aimed_spread(5, 14.0, 200.0)   # seed volley
		2:
			action_timer = 2.8
			if randi() % 2 == 0:
				_spiral_seeds()
			else:
				summon(SPIRIT_SCENE, 2)
		3:
			action_timer = 2.4
			match randi() % 3:
				0: _spiral_seeds()
				1:
					ring(14, 150.0)
					ring(14, 200.0, -1.0, deg_to_rad(12.0))
				2: summon(MUSHROOM_SCENE, 2)

func _spiral_seeds():
	for i in 12:
		await get_tree().create_timer(0.08).timeout
		if not is_inside_tree() or not alive:
			return
		var a := i * deg_to_rad(33.0)
		shoot(Vector2(cos(a), sin(a)), 190.0)
