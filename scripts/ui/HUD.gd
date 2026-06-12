extends CanvasLayer

@onready var hp_bar: ProgressBar          = $TopLeft/HPBar
@onready var hp_label: Label              = $TopLeft/HPLabel
@onready var weapon_name_label: Label     = $TopRight/WeaponName
@onready var ammo_label: Label            = $TopRight/AmmoLabel
@onready var skill_bar: ProgressBar       = $BottomLeft/SkillBar
@onready var skill_label: Label           = $BottomLeft/SkillLabel
@onready var boss_container: Control      = $BossBar
@onready var boss_hp_bar: ProgressBar     = $BossBar/HPBar
@onready var boss_name_label: Label       = $BossBar/NameLabel
@onready var score_label: Label           = $TopLeft/ScoreLabel
@onready var gold_label: Label            = $TopLeft/GoldLabel
@onready var game_over_panel: Control     = $GameOverPanel
@onready var sublevel_label: Label        = $SublevelLabel

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
	hp_bar.max_value   = max_hp
	hp_bar.value       = hp
	hp_label.text      = "%d / %d" % [hp, max_hp]

func _on_weapon_changed(weapon: Dictionary):
	weapon_name_label.text = weapon.get("name", "?")
	if weapon.get("type") == "melee":
		ammo_label.text = "∞"
	else:
		ammo_label.text = "%d / %d" % [weapon.get("ammo", 0), weapon.get("ammo_max", 0)]

func _on_ammo_changed(current: int, maximum: int):
	ammo_label.text = "%d / %d" % [current, maximum]

func _on_skill_activated(duration: float):
	skill_label.text    = "技能激活!"
	skill_bar.value     = skill_max
	var t = create_tween()
	t.tween_property(skill_bar, "value", 0.0, duration)
	t.tween_callback(func(): skill_label.text = "技能就绪")

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

func show_boss_bar(visible: bool):
	boss_container.visible = visible
	if visible:
		boss_name_label.text = "曼陀罗花"

func _on_score_changed(score: int):
	score_label.text = "分数: %d" % score

func _on_gold_changed(gold: int):
	gold_label.text = "金币: %d" % gold

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
