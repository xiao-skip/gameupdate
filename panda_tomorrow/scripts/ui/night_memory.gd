extends Control
class_name NightMemory
## ============================================================
## NightMemory —— 夜间记忆界面（B 独占：scripts/ui/night_memory.gd）
##
## 0 点记忆刷新前的「沉淀」时刻。交互语义（分工文档 4.3-B）：
##   预览 —— 点候选卡显示 desc；
##   留存 —— 今晚想留住哪条（单槽；重复点 = 改选）；
##   撤回 —— 取消今晚的改动，回到今晚开始时的状态；
##   空槽 —— 什么都不选直接睡（= 保持原有槽位；从未留过 = 真空槽，A-Q6）。
##
## 实现要点：选择先存在 _pending，点「睡了」才真正调
## GameState.save_memory（A 的接口只在候选内生效）——这样「撤回」
## 不需要 A 提供清空接口也能正确恢复。
## ============================================================

signal night_confirmed(kept_id: String)

var _initial_kept := ""   ## 进夜时 GameState.kept_id 的快照
var _pending_kept := ""   ## 今晚当前选择（起步 = _initial_kept）

var _panel: PanelContainer
var _title: Label
var _current_label: Label
var _preview_label: Label
var _list_box: VBoxContainer
var _status_label: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(720, 520)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.06, 0.1, 0.97)
	s.set_corner_radius_all(10)
	s.set_border_width_all(2)
	s.border_color = Color(0.4, 0.45, 0.65)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", s)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	_title = Label.new()
	_title.text = "夜深了。记忆刷新之前，只来得及留住一件事。"
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.98))
	col.add_child(_title)

	_current_label = Label.new()
	_current_label.add_theme_font_size_override("font_size", 15)
	_current_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	col.add_child(_current_label)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_list_box)

	_preview_label = Label.new()
	_preview_label.add_theme_font_size_override("font_size", 15)
	_preview_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_label.custom_minimum_size = Vector2(0, 76)
	col.add_child(_preview_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	col.add_child(_status_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	col.add_child(actions)
	var revoke_btn := Button.new()
	revoke_btn.text = "撤回今晚的改动"
	revoke_btn.pressed.connect(revoke)
	actions.add_child(revoke_btn)
	var sleep_btn := Button.new()
	sleep_btn.text = "睡了，明天见"
	sleep_btn.custom_minimum_size = Vector2(180, 0)
	sleep_btn.pressed.connect(confirm)
	actions.add_child(sleep_btn)

	visible = false


## 打开夜间界面（渲染 GameState.memory_candidates + 当前槽位）。
func open() -> void:
	_initial_kept = GameState.kept_id
	_pending_kept = _initial_kept
	visible = true
	_render()


## 点某条候选 = 预览 + 留存选择（再点别的 = 改选）。
func keep(id: String) -> void:
	if not GameState.memory_candidates.has(id):
		return
	_pending_kept = id
	_render()


## 撤回：今晚的改动全部取消，回到进夜时的状态。
func revoke() -> void:
	_pending_kept = _initial_kept
	_render()


## 可编程点第 index 条候选（冒烟/测试用）。
func keep_index(index: int) -> void:
	var c: Array = GameState.memory_candidates
	if index >= 0 and index < c.size():
		keep(String(c[index]))


## 「睡了」：把 pending 提交给 GameState（单槽，save_memory 只在候选内生效），
## 发 night_confirmed(最终 kept_id)，关闭界面。
func confirm() -> void:
	var final_id := _pending_kept
	if final_id != _initial_kept and final_id != "":
		GameState.save_memory(final_id)
	visible = false
	night_confirmed.emit(final_id)


## 今晚当前选择（测试断言用）。
func get_pending() -> String:
	return _pending_kept


# ============================================================
# 内部
# ============================================================

func _render() -> void:
	var gs := GameState

	# 当前槽位行。
	if gs.kept_id != "":
		var m: Dictionary = gs.get_memory_info(gs.kept_id)
		_current_label.text = "昨天的记忆还在槽里：《%s》" % String(m.get("title", gs.kept_id))
	else:
		_current_label.text = "记忆槽是空的。（什么都不留也能过明天）"

	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()

	var cands: Array = gs.memory_candidates
	if cands.is_empty():
		var empty := Label.new()
		empty.text = "今晚没有新的沉淀候选。"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.5, 0.52, 0.6))
		_list_box.add_child(empty)
	for id in cands:
		_list_box.add_child(_build_candidate_row(String(id)))

	# 预览区 + 状态行。
	if _pending_kept != "":
		var pm: Dictionary = gs.get_memory_info(_pending_kept)
		_preview_label.text = "《%s》——%s" % [String(pm.get("title", "")), String(pm.get("desc", ""))]
		_status_label.text = "今晚将留住：《%s》" % String(pm.get("title", _pending_kept))
	else:
		_preview_label.text = "（未选择。今晚什么都不留。）"
		if gs.kept_id != "":
			_status_label.text = "今晚不留新的，继续用昨天那条。"
		else:
			_status_label.text = "空槽。明天从零开始也没关系。"


func _build_candidate_row(id: String) -> Control:
	var gs := GameState
	var m: Dictionary = gs.get_memory_info(id)
	var selected := (_pending_kept == id)
	var kept_before := (gs.kept_id == id and _initial_kept == id)

	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	s.set_border_width_all(2)
	if selected:
		s.bg_color = Color(0.18, 0.2, 0.32, 0.95)
		s.border_color = Color(0.85, 0.85, 0.95)
	elif kept_before:
		s.bg_color = Color(0.14, 0.15, 0.2, 0.9)
		s.border_color = Color(0.5, 0.55, 0.75)
	else:
		s.bg_color = Color(0.1, 0.11, 0.16, 0.9)
		s.border_color = Color(0.35, 0.38, 0.5)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var title := Label.new()
	var suffix := ""
	if kept_before:
		suffix = "（槽里那条）"
	title.text = "《%s》%s" % [String(m.get("title", id)), suffix]
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color",
		Color(0.95, 0.93, 0.8) if selected else Color(0.78, 0.78, 0.85))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var type_label := Label.new()
	type_label.text = String(m.get("type", ""))
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.7))
	row.add_child(type_label)

	var btn := Button.new()
	btn.text = "留住这条" if not selected else "★ 今晚的选择"
	btn.pressed.connect(keep.bind(id))
	row.add_child(btn)
	return card
