extends PanelContainer
class_name TaskPanel
## ============================================================
## TaskPanel —— 任务卡面板（B 独占：scripts/ui/task_panel.gd）
##
## 「渲染任意列表」的通用组件（分工文档扩展性表：加 T05/T06 不改代码）：
## 遍历 GameState.get_task_ids() → get_task_info() 逐张渲染。
## 点卡 = 派工：转发 task_clicked 信号，由 main 调 GameState.submit_task。
## 成本变化（渗漏加价 / 留记忆免电）实时反映在卡面上。
## ============================================================

signal task_clicked(id: String)

var _cards_box: HBoxContainer
var _card_ids: Array = []   ## 当前渲染的卡序（可编程点击用）


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.4, 0.36, 0.3, 0.6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var title_row := HBoxContainer.new()
	# 标题 + 卡片区上下排
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)

	var title := Label.new()
	title.text = "今日派工（点卡 = 派这台机器人去干活）"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	col.add_child(title)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 10)
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_cards_box)
	refresh()


## 全量刷新任务卡（资源/成本/完成态变动后由 main 调用）。
func refresh() -> void:
	for c in _cards_box.get_children():
		_cards_box.remove_child(c)
		c.queue_free()
	_card_ids.clear()
	for id in GameState.get_task_ids():
		var info: Dictionary = GameState.get_task_info(id)
		if info.is_empty():
			continue
		_card_ids.append(id)
		_cards_box.add_child(_build_card(info))


## 可编程点击第 index 张卡（冒烟/测试用）。
func click_card(index: int) -> void:
	if index >= 0 and index < _card_ids.size():
		task_clicked.emit(String(_card_ids[index]))


## 可编程点击指定 id 的卡。
func click_card_id(id: String) -> void:
	if _card_ids.has(id):
		task_clicked.emit(id)


func get_card_count() -> int:
	return _card_ids.size()


# ============================================================
# 内部
# ============================================================

func _build_card(info: Dictionary) -> Control:
	var done := bool(info["done"])
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(215, 0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	if done:
		s.bg_color = Color(0.16, 0.18, 0.15, 0.95)
		s.border_color = Color(0.35, 0.55, 0.35, 0.9)
	else:
		s.bg_color = Color(0.15, 0.14, 0.12, 0.95)
		s.border_color = Color(0.62, 0.55, 0.38, 0.9)
	s.set_border_width_all(1)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", s)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var name_label := Label.new()
	name_label.text = "%s · %s" % [String(info["name"]), String(info["robot"])]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color",
		Color(0.8, 0.9, 0.75) if done else Color(0.95, 0.88, 0.62))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var done_mark := Label.new()
	done_mark.text = "✓ 已派" if done else ""
	done_mark.add_theme_font_size_override("font_size", 15)
	done_mark.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	head.add_child(done_mark)

	var desc := Label.new()
	desc.text = String(info["desc"])
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.68, 0.66, 0.6))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(195, 40)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)

	# 成本行：电/水/家光。加价与免电直接显示当前有效值。
	var cost := Label.new()
	var e := int(info["energy"])
	var w := int(info["water"])
	var jg := int(info["jg"])
	var cost_text := "电 %d" % e
	if e == 0:
		cost_text = "电 0（记忆免电）"
	cost_text += " · 水 %d · 家光 +✦%d" % [w, jg]
	cost.text = cost_text
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", Color(0.62, 0.72, 0.85))
	col.add_child(cost)

	var btn := Button.new()
	btn.text = "派工" if not done else "今日已完成"
	btn.disabled = done
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func() -> void: task_clicked.emit(String(info["id"])))
	col.add_child(btn)
	return card
