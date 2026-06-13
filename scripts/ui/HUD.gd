extends CanvasLayer

@onready var hp_bar:           ProgressBar = $StatusPanel/Content/HPBar
@onready var hp_label:         Label       = $StatusPanel/Content/HPLabel
@onready var energy_bar:       ProgressBar = $StatusPanel/Content/EnergyBar
@onready var energy_label:     Label       = $StatusPanel/Content/EnergyLabel
@onready var gold_label:       Label       = $StatusPanel/Content/GoldLabel
@onready var score_label:      Label       = $StatusPanel/Content/ScoreLabel
@onready var weapon_name_label: Label      = $WeaponPanel/Content/WeaponName
@onready var weapon_cost_label: Label      = $WeaponPanel/Content/WeaponCostLabel
@onready var skill_bar:        ProgressBar = $SkillPanel/Content/SkillBar
@onready var skill_label:      Label       = $SkillPanel/Content/SkillLabel
@onready var boss_container:   Control     = $BossBar
@onready var boss_hp_bar:      ProgressBar = $BossBar/HPBar
@onready var boss_name_label:  Label       = $BossBar/NameLabel
@onready var sublevel_label:   Label       = $SublevelLabel
@onready var game_over_panel:  Control     = $GameOverPanel

var skill_max: float = 30.0

func _ready():
	game_over_panel.hide()
	boss_container.hide()
	sublevel_label.hide()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.sublevel_completed.connect(_on_sublevel_completed)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.gold_changed.connect(_on_gold_changed)

func _on_health_changed(hp: int, max_hp: int):
	hp_bar.max_value = max_hp
	hp_bar.value     = hp
	hp_label.text    = "♥  %d / %d" % [hp, max_hp]

func _on_energy_changed(current: int, maximum: int):
	energy_bar.max_value = maximum
	energy_bar.value     = current
	energy_label.text    = "⚡  %d / %d" % [current, maximum]

func _on_weapon_changed(weapon: Dictionary):
	weapon_name_label.text = weapon.get("name", "?")
	var cost: int = weapon.get("energy_cost", 0)
	var prefix = "近战  " if weapon.get("type") == "melee" else ""
	if cost == 0:
		weapon_cost_label.text = prefix + "免费使用"
	else:
		weapon_cost_label.text = prefix + "耗能: %d / 次" % cost

func _on_skill_activated(duration: float):
	skill_label.text = "技能激活!"
	skill_bar.value  = skill_max
	var t = create_tween()
	t.tween_property(skill_bar, "value", 0.0, duration)
	t.tween_callback(func(): skill_label.text = "技能就绪 [空格]")

func _on_skill_cooldown(remaining: float, total: float):
	skill_max = total
	skill_bar.max_value = total
	skill_bar.value     = total - remaining
	if remaining > 0.01:
		skill_label.text = "冷却 %.0f秒" % remaining
	else:
		skill_label.text = "技能就绪 [空格]"

func _on_boss_hp_changed(hp: float, max_hp: float):
	boss_hp_bar.max_value = max_hp
	boss_hp_bar.value     = hp

func show_boss_bar(visible: bool, boss_name: String = "曼陀罗花"):
	boss_container.visible = visible
	if visible:
		boss_name_label.text = boss_name

func _on_score_changed(score: int):
	score_label.text = "分数: %d" % score

func _on_gold_changed(gold: int):
	gold_label.text = "★  金币: %d" % gold

func show_game_over():
	game_over_panel.show()

func _on_sublevel_completed():
	_show_sublevel_banner("第%d关通关！" % GameManager.current_sublevel)

func _on_level_completed():
	_show_sublevel_banner("通关！恭喜！")

func _show_sublevel_banner(text: String):
	sublevel_label.text = text
	sublevel_label.show()
	var t = create_tween()
	t.tween_interval(2.5)
	t.tween_callback(sublevel_label.hide)

func show_sublevel_title(text: String):
	sublevel_label.text = text
	sublevel_label.modulate.a = 1.0
	sublevel_label.show()
	var t = create_tween()
	t.tween_interval(2.0)
	t.tween_property(sublevel_label, "modulate:a", 0.0, 0.5)
	t.tween_callback(sublevel_label.hide)
