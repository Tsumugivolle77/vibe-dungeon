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
var _hp: int = 100
var _max_hp: int = 100
var _shield: int = 0

var _overlay: _HudOverlay = null   # minimap + off-screen enemy markers (custom-drawn)
var _tip_panel: Control = null     # weapon stat tooltip (slides in above the minimap)
var _tip_label: Label = null
var _tip_shown: bool = false
var _tip_tween: Tween = null
var _boss_armor_bar: ProgressBar = null   # boss 护甲条 (below the boss HP bar)

const TIP_SIZE   = Vector2(232, 168)
const MM_SIZE    = Vector2(176, 128)   # must match _HudOverlay minimap box size
const HUD_MARGIN = 12.0

func _ready():
	game_over_panel.hide()
	boss_container.hide()
	sublevel_label.hide()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.sublevel_completed.connect(_on_sublevel_completed)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.gold_changed.connect(_on_gold_changed)

	# Boss armor bar (护甲条) directly below the boss HP bar.
	_boss_armor_bar = ProgressBar.new()
	_boss_armor_bar.custom_minimum_size = Vector2(0, 10)
	_boss_armor_bar.show_percentage = false
	_boss_armor_bar.modulate = Color(0.55, 0.85, 1.0)   # cyan, matching the shield motif
	_boss_armor_bar.visible = false
	boss_container.add_child(_boss_armor_bar)

	# Custom-drawn overlay (minimap + off-screen enemy markers).
	_overlay = _HudOverlay.new()
	_overlay.level = get_parent()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Weapon stat tooltip — a panel that slides in from off the right edge of the
	# screen and rests just above the minimap (hidden until near a weapon).
	_tip_panel = Control.new()
	_tip_panel.size = TIP_SIZE
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.visible = false
	var tip_bg := ColorRect.new()
	tip_bg.color = Color(0.04, 0.05, 0.08, 0.85)
	tip_bg.size = TIP_SIZE
	tip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(tip_bg)
	var tip_accent := ColorRect.new()   # gold left edge
	tip_accent.color = Color(1.0, 0.85, 0.2, 0.9)
	tip_accent.size = Vector2(4, TIP_SIZE.y)
	tip_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(tip_accent)
	_tip_label = Label.new()
	_tip_label.position = Vector2(14, 10)
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(_tip_label)
	add_child(_tip_panel)

func _process(_delta: float):
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()
	_update_weapon_tooltip()

# ── Weapon stat tooltip (item: 靠近武器后右下角显示词条) ──────────────────────────
func _update_weapon_tooltip():
	var pl = GameManager.player_ref
	if not is_instance_valid(pl):
		_hide_tip()
		return
	var best: Node = null
	var best_d := 82.0
	for n in get_tree().get_nodes_in_group("weapon_display"):
		if not is_instance_valid(n):
			continue
		var d: float = pl.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		_hide_tip()
		return
	var id: String = best.get_meta("weapon_id", "")
	if id.is_empty():
		_hide_tip()
		return
	_show_tip(id)

# Resting position: just above the minimap in the bottom-right corner.
func _tip_rest_pos() -> Vector2:
	var vr := get_viewport().get_visible_rect().size
	var mm_top := vr.y - MM_SIZE.y - HUD_MARGIN          # minimap top edge
	return Vector2(vr.x - TIP_SIZE.x - HUD_MARGIN, mm_top - TIP_SIZE.y - 10.0)

# Hidden position: fully off the right edge of the screen.
func _tip_hidden_pos() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size.x + 12.0, _tip_rest_pos().y)

func _show_tip(id: String):
	_tip_label.text = _weapon_tooltip_text(id)
	if _tip_shown:
		return   # already in/at rest — let any running slide finish without snapping
	_tip_shown = true
	_tip_panel.visible = true
	_tip_panel.position = _tip_hidden_pos()
	if _tip_tween and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_panel, "position", _tip_rest_pos(), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_tip():
	if not _tip_shown:
		return
	_tip_shown = false
	if _tip_tween and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_panel, "position", _tip_hidden_pos(), 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tip_tween.tween_callback(func(): _tip_panel.visible = false)

func _weapon_tooltip_text(id: String) -> String:
	var w := WeaponDatabase.get_weapon(id)
	if w.is_empty():
		return ""
	var lines: Array = []
	lines.append("【%s】" % w.get("name", "?"))
	lines.append("类型: %s" % ("近战" if w.get("type") == "melee" else "远程"))
	lines.append("伤害: %d" % int(w.get("damage", 0)))
	lines.append("攻速: %.1f / 秒" % float(w.get("fire_rate", 0.0)))
	if w.get("type") == "melee":
		lines.append("范围: %d°" % int(w.get("arc", 0)))
	else:
		lines.append("弹数: %d" % int(w.get("bullet_count", 1)))
	lines.append("耗能: %d" % int(w.get("energy_cost", 0)))
	var props: Dictionary = w.get("props", {})
	var tags: Array = []
	if props.get("explosive"): tags.append("爆炸")
	if props.get("piercing"):  tags.append("穿透")
	if props.get("bouncing"):  tags.append("弹射")
	if props.get("homing"):    tags.append("追踪")
	if props.get("chain"):     tags.append("连锁")
	if props.get("laser"):     tags.append("激光")
	if props.get("ring"):      tags.append("环形")
	if not tags.is_empty():
		lines.append("特性: " + ", ".join(tags))
	return "\n".join(lines)

func _on_health_changed(hp: int, max_hp: int):
	_hp = hp
	_max_hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value     = hp
	_refresh_hp_label()

func _on_shield_changed(current: int, _maximum: int):
	_shield = current
	_refresh_hp_label()

func _refresh_hp_label():
	if _shield > 0:
		hp_label.text = "♥ %d/%d   🛡 %d" % [_hp, _max_hp, _shield]
	else:
		hp_label.text = "♥ %d / %d" % [_hp, _max_hp]

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

func _on_boss_armor_changed(armor: float, max_armor: float):
	if _boss_armor_bar == null:
		return
	_boss_armor_bar.max_value = max_armor
	_boss_armor_bar.value     = armor
	_boss_armor_bar.visible   = boss_container.visible and max_armor > 0.0

func show_boss_bar(visible: bool, boss_name: String = "曼陀罗花"):
	boss_container.visible = visible
	if is_instance_valid(_boss_armor_bar):
		_boss_armor_bar.visible = visible
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

# ── Custom-drawn overlay: minimap + off-screen enemy markers ──────────────────
class _HudOverlay extends Control:
	var level: Node = null

	const ROOM_COLORS = {
		"v": Color(0.3, 0.8, 1.0), "c": Color(0.55, 0.57, 0.62),
		"r": Color(1.0, 0.82, 0.2), "s": Color(0.3, 0.85, 0.4),
		"b": Color(0.92, 0.25, 0.2),
	}

	func _draw():
		_draw_minimap()
		_draw_offscreen_markers()

	func _draw_minimap():
		if level == null or not ("rooms" in level):
			return
		var rooms: Array = level.rooms
		var rtypes: Array = level.room_types if ("room_types" in level) else []
		if rooms.is_empty():
			return
		var minp := Vector2(INF, INF)
		var maxp := Vector2(-INF, -INF)
		for r in rooms:
			if not is_instance_valid(r):
				continue
			var tl: Vector2 = r.position
			var sz := Vector2(float(r.data.cols) * 64.0, float(r.data.rows) * 64.0)
			minp = minp.min(tl)
			maxp = maxp.max(tl + sz)
		var world_size := maxp - minp
		if world_size.x <= 0.0 or world_size.y <= 0.0:
			return

		var box_size := Vector2(176.0, 128.0)
		var vr := get_viewport_rect().size
		# Bottom-right corner (clear of the other HUD panels).
		var box_pos := Vector2(vr.x - box_size.x - 12.0, vr.y - box_size.y - 12.0)
		draw_rect(Rect2(box_pos, box_size), Color(0, 0, 0, 0.5), true)
		draw_rect(Rect2(box_pos, box_size), Color(1, 1, 1, 0.25), false)

		var sc: float = minf(box_size.x / world_size.x, box_size.y / world_size.y) * 0.84
		var draw_off := box_pos + (box_size - world_size * sc) * 0.5 - minp * sc

		for i in rooms.size():
			var r = rooms[i]
			if not is_instance_valid(r):
				continue
			var tl: Vector2 = r.position
			var sz := Vector2(float(r.data.cols) * 64.0, float(r.data.rows) * 64.0)
			var rp := draw_off + tl * sc
			var rs := sz * sc
			var code: String = rtypes[i] if i < rtypes.size() else "c"
			draw_rect(Rect2(rp, rs), ROOM_COLORS.get(code, Color(0.5, 0.5, 0.5)), true)
			draw_rect(Rect2(rp, rs), Color(0, 0, 0, 0.45), false)

		var pl = GameManager.player_ref
		if is_instance_valid(pl):
			draw_circle(draw_off + pl.global_position * sc, 3.5, Color(0.3, 1.0, 0.45))

	func _draw_offscreen_markers():
		var pl = GameManager.player_ref
		if not is_instance_valid(pl):
			return
		var xform := get_viewport().get_canvas_transform()
		var vr := get_viewport_rect().size
		var center := vr * 0.5
		var margin := 34.0
		var font := ThemeDB.fallback_font
		var shown := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			var sp: Vector2 = xform * e.global_position
			if sp.x >= 0.0 and sp.x <= vr.x and sp.y >= 0.0 and sp.y <= vr.y:
				continue   # on-screen, no marker needed
			var dir := sp - center
			if dir.length() < 1.0:
				continue
			dir = dir.normalized()
			var half := vr * 0.5 - Vector2(margin, margin)
			var tx := INF
			var ty := INF
			if absf(dir.x) > 0.0001: tx = half.x / absf(dir.x)
			if absf(dir.y) > 0.0001: ty = half.y / absf(dir.y)
			var edge := center + dir * minf(tx, ty)
			draw_circle(edge, 11.0, Color(0.1, 0.1, 0.1, 0.55))
			draw_circle(edge, 9.0, Color(1.0, 0.85, 0.1))
			draw_string(font, edge + Vector2(-3.0, 6.0), "!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.25, 0.12, 0.0))
			shown += 1
			if shown >= 14:
				break
