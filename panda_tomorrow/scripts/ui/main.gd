extends Control
## ============================================================
## Main —— 第一幕主界面 v6（物件驱动 · 定稿）
##
## 标题 → 选角 → 客厅（点物件弹选项 → 探索/派工）→ 结束白天 → 熊猫回家(安慰) → 夜里留记忆 → 过夜。
## 破局：昨夜留《它今天受委屈了》 + 今天再主动安慰 → 「进入下一幕」触发 S04 结局。
## 软提示 / 三终端施压 / 对话模态锁 / 记忆留·删除·换。
## ============================================================

# 顶栏
var _top_day: Label
var _top_energy: Label
var _top_slots: Label
var _top_panda: Label

# 菜单抽屉（只留操作）
var _menu_button: Button
var _menu_panel: PanelContainer

# 覆盖层
var _title_overlay: Control
var _select_overlay: Control
var _ending_overlay: Control

# 输入阻挡层（对话模态锁）
var _input_blocker: ColorRect

# 占位熊猫
var _panda_block: ColorRect
var _panda_info: Label

# 反馈条
var _feedback: Label

# 对话框
var _dialogue_overlay: PanelContainer
var _dialogue_speaker: Label
var _dialogue_text: Label
var _dialogue_choices: VBoxContainer
var _next_button: Button

# 覆盖层
var _memory_overlay: Control
var _memory_list: VBoxContainer
var _tree_overlay: Control
var _tree_list: VBoxContainer

# 对话状态
var _current_scene: Dictionary = {}
var _current_line_index: int = 0
var _current_choice_set: String = ""
var _ending_after_scene: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene()
	_build_top_bar_overlay()
	_build_feedback_banner()
	_build_action_bar()
	_build_menu()
	_build_input_blocker()
	_build_dialogue_overlay()
	_build_memory_overlay()
	_build_tree_overlay()
	_build_select_overlay()
	_build_title_overlay()
	_build_ending_overlay()
	_refresh_top()
	_refresh_panda_block()
	print("[UI] 主界面 v6 构建完成")


# ============================================================
# 场景（一个客厅，物件落在家具上）
# ============================================================
func _build_scene() -> void:
	var wall: ColorRect = ColorRect.new()
	wall.color = Color(0.22, 0.24, 0.30)
	wall.anchor_left = 0.0
	wall.anchor_right = 1.0
	wall.anchor_top = 0.0
	wall.anchor_bottom = 0.70
	add_child(wall)

	var floor: ColorRect = ColorRect.new()
	floor.color = Color(0.30, 0.22, 0.16)
	floor.anchor_left = 0.0
	floor.anchor_right = 1.0
	floor.anchor_top = 0.70
	floor.anchor_bottom = 1.0
	add_child(floor)

	# 家具（不可点）
	_add_furniture("【占位】小板凳", 0.28, 0.63, 0.36, 0.70, Color(0.40, 0.32, 0.22))
	_add_furniture("【占位】边桌", 0.72, 0.58, 0.86, 0.70, Color(0.44, 0.35, 0.24))

	# 可点物件（含软提示）
	_add_object_button("【占位】沙发\n先把地扫了吧", 0.24, 0.52, 0.42, 0.70, _on_object_sofa)
	_add_object_button("【占位】书架\n先把书架收拾一下吧", 0.86, 0.05, 0.99, 0.42, _on_object_shelf)
	_add_object_button("【占位】总控屏\n该派工了", 0.36, 0.08, 0.66, 0.30, _on_object_screen)
	_add_object_button("【占位】暖炉\n先把暖炉检查一下吧", 0.03, 0.52, 0.20, 0.70, _on_object_heater)
	_add_object_button("【占位】灯\n灯也该擦一擦", 0.74, 0.42, 0.84, 0.58, _on_object_lamp)
	_add_object_button("【占位】树洞角落\n翻便条", 0.86, 0.46, 0.99, 0.70, _on_object_tree)

	_panda_block = ColorRect.new()
	_panda_block.color = Color(0.5, 0.5, 0.5)
	_panda_block.anchor_left = 0.5
	_panda_block.anchor_top = 0.5
	_panda_block.anchor_right = 0.5
	_panda_block.anchor_bottom = 0.5
	_panda_block.offset_left = -150
	_panda_block.offset_top = -160
	_panda_block.offset_right = 150
	_panda_block.offset_bottom = 130
	add_child(_panda_block)

	_panda_info = _mk_label("【占位】熊猫立绘：未选", 18)
	_panda_info.anchor_left = 0.5
	_panda_info.anchor_top = 0.5
	_panda_info.anchor_right = 0.5
	_panda_info.anchor_bottom = 0.5
	_panda_info.offset_left = -180
	_panda_info.offset_top = 138
	_panda_info.offset_right = 180
	_panda_info.offset_bottom = 170
	_panda_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_panda_info)


func _add_furniture(label: String, al: float, at: float, ar: float, ab: float, color: Color) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = al
	panel.anchor_top = at
	panel.anchor_right = ar
	panel.anchor_bottom = ab
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl: Label = _mk_label(label, 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(lbl)
	add_child(panel)


func _add_object_button(text: String, al: float, at: float, ar: float, ab: float, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.anchor_left = al
	b.anchor_top = at
	b.anchor_right = ar
	b.anchor_bottom = ab
	b.pressed.connect(cb)
	add_child(b)


# ============================================================
# 顶栏 + 反馈条 + 操作条 + 菜单
# ============================================================
func _build_top_bar_overlay() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_bottom = 44
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	bar.add_child(hb)
	_top_day = _mk_label("第 1 天")
	_top_energy = _mk_label("电量 8/8")
	_top_slots = _mk_label("槽位 3/3")
	_top_panda = _mk_label("熊猫：未选")
	hb.add_child(_top_day)
	hb.add_child(_top_energy)
	hb.add_child(_top_slots)
	hb.add_child(_top_panda)
	add_child(bar)


func _build_feedback_banner() -> void:
	var banner: PanelContainer = PanelContainer.new()
	banner.anchor_left = 0.22
	banner.anchor_right = 0.78
	banner.anchor_top = 0.0
	banner.anchor_bottom = 0.0
	banner.offset_top = 50
	banner.offset_bottom = 92
	_feedback = _mk_label("", 15)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(_feedback)
	add_child(banner)


func _build_action_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.90
	bar.anchor_bottom = 1.0
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bar.add_child(hb)
	hb.add_child(_mk_button("结束白天 · 它回家", _on_end_day))
	hb.add_child(_mk_button("夜里留记忆", _on_open_memory))
	hb.add_child(_mk_button("过夜 · 0点", _on_new_day))
	hb.add_child(_mk_button("进入下一幕", _on_check_break))
	hb.add_child(_mk_button("重新开始", _on_reset))
	add_child(bar)


func _build_menu() -> void:
	_menu_button = Button.new()
	_menu_button.text = "☰ 菜单"
	_menu_button.anchor_left = 0.0
	_menu_button.anchor_right = 0.12
	_menu_button.anchor_top = 0.0
	_menu_button.anchor_bottom = 0.0
	_menu_button.offset_top = 0
	_menu_button.offset_bottom = 44
	_menu_button.pressed.connect(_on_menu_toggle)
	add_child(_menu_button)

	_menu_panel = PanelContainer.new()
	_menu_panel.visible = false
	_menu_panel.anchor_left = 0.68
	_menu_panel.anchor_right = 1.0
	_menu_panel.anchor_top = 0.08
	_menu_panel.anchor_bottom = 0.88
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_menu_panel.add_child(v)
	v.add_child(_mk_label("操作", 18))
	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_child(_mk_button("结束白天 · 它回家", _on_end_day))
	actions.add_child(_mk_button("夜里留记忆", _on_open_memory))
	actions.add_child(_mk_button("过夜 · 0点重启", _on_new_day))
	actions.add_child(_mk_button("进入下一幕", _on_check_break))
	actions.add_child(_mk_button("重新开始", _on_reset))
	v.add_child(actions)
	add_child(_menu_panel)


func _on_menu_toggle() -> void:
	_menu_panel.visible = not _menu_panel.visible


func _build_input_blocker() -> void:
	_input_blocker = ColorRect.new()
	_input_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.visible = false
	add_child(_input_blocker)


func _set_dialogue_modal(active: bool) -> void:
	_input_blocker.visible = active


# ============================================================
# 标题 / 选角 / 结局
# ============================================================
func _build_title_overlay() -> void:
	_title_overlay = Control.new()
	_title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_overlay.add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 20)
	_title_overlay.add_child(v)
	var t: Label = _mk_label("《熊猫，明天见》", 42)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub: Label = _mk_label("主题「环」· 第一幕", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var start: Button = _mk_button("开始", _on_start)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.custom_minimum_size = Vector2(220, 64)
	v.add_child(start)
	add_child(_title_overlay)


func _build_select_overlay() -> void:
	_select_overlay = Control.new()
	_select_overlay.visible = false
	_select_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_overlay.add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	_select_overlay.add_child(v)
	v.add_child(_mk_label("你叫念念，是这座房子的全屋总控 AI。\n你要照顾的那只熊猫，是哪一位？", 20))
	for pid in Dialogue.get_panda_ids():
		var prof: Dictionary = Dialogue.get_profile(pid)
		var text: String = str(prof.get("name", pid)) + " · " + str(prof.get("job", "")) + " · " + str(prof.get("subspecies", ""))
		var btn: Button = _mk_button(text, _on_select_panda.bind(pid))
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(420, 44)
		v.add_child(btn)
	add_child(_select_overlay)


func _build_ending_overlay() -> void:
	_ending_overlay = Control.new()
	_ending_overlay.visible = false
	_ending_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending_overlay.add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_ending_overlay.add_child(v)
	var l1: Label = _mk_label("第一幕 · 完", 38)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2: Label = _mk_label("它不是第一次说这句话。", 22)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var l3: Label = _mk_label("—— 明天见。", 22)
	l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l3)
	var again: Button = _mk_button("重新开始", _on_reset)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.custom_minimum_size = Vector2(200, 50)
	v.add_child(again)
	add_child(_ending_overlay)


func _on_start() -> void:
	_title_overlay.visible = false
	_select_overlay.visible = true


func _show_ending() -> void:
	_dialogue_overlay.visible = false
	_set_dialogue_modal(false)
	_ending_overlay.visible = true


# ============================================================
# 对话框 / 记忆 / 树洞
# ============================================================
func _build_dialogue_overlay() -> void:
	_dialogue_overlay = PanelContainer.new()
	_dialogue_overlay.visible = false
	_dialogue_overlay.anchor_left = 0.0
	_dialogue_overlay.anchor_right = 1.0
	_dialogue_overlay.anchor_top = 0.74
	_dialogue_overlay.anchor_bottom = 1.0
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_dialogue_overlay.add_child(v)
	_dialogue_speaker = _mk_label("", 18)
	_dialogue_text = _mk_label("", 15)
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_choices = VBoxContainer.new()
	_next_button = _mk_button("下一句", _on_next_line)
	var close: Button = _mk_button("收起对话", _close_dialogue)
	v.add_child(_dialogue_speaker)
	v.add_child(_dialogue_text)
	v.add_child(_dialogue_choices)
	v.add_child(_next_button)
	v.add_child(close)
	add_child(_dialogue_overlay)


func _build_memory_overlay() -> void:
	_memory_overlay = Control.new()
	_memory_overlay.visible = false
	_memory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_memory_overlay.add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	_memory_overlay.add_child(v)
	v.add_child(_mk_label("夜间记忆 —— 你每天只能留一条（留记忆要花电）", 20))
	_memory_list = VBoxContainer.new()
	v.add_child(_memory_list)
	v.add_child(_mk_button("关闭", _close_memory))
	add_child(_memory_overlay)


func _build_tree_overlay() -> void:
	_tree_overlay = Control.new()
	_tree_overlay.visible = false
	_tree_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree_overlay.add_child(bg)
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	_tree_overlay.add_child(v)
	v.add_child(_mk_label("树洞角落 —— 一沓会增长的便条", 20))
	_tree_list = VBoxContainer.new()
	v.add_child(_tree_list)
	v.add_child(_mk_button("关闭", _close_tree))
	add_child(_tree_overlay)


# ============================================================
# 小工具
# ============================================================
func _mk_label(text: String, size: int = 16) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _mk_button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _profile_color(prof: Dictionary) -> Color:
	var rgb: Array = prof.get("color_rgb", [128, 128, 128])
	return Color(float(rgb[0]) / 255.0, float(rgb[1]) / 255.0, float(rgb[2]) / 255.0)


func _status_cn(status: String) -> String:
	if status == "available":
		return "可派工"
	if status == "done":
		return "已完成"
	return "未解锁"


func _task_name(tid: String) -> String:
	for task: Dictionary in GameState.get_tasks():
		if str(task.get("id", "")) == tid:
			return str(task.get("name", tid))
	return tid


# ============================================================
# 刷新
# ============================================================
func _refresh_top() -> void:
	_top_day.text = "第 " + str(GameState.day_count) + " 天"
	_top_energy.text = "电量 " + str(GameState.energy) + "/" + str(GameState.max_energy)
	_top_slots.text = "槽位 " + str(GameState.slots_left) + "/" + str(GameState.slots)
	var pname: String = GameState.panda_name
	_top_panda.text = "熊猫：" + (pname if pname != "" else "未选")


func _refresh_panda_block() -> void:
	if GameState.selected_panda == "":
		_panda_block.color = Color(0.5, 0.5, 0.5)
		_panda_info.text = "【占位】熊猫立绘：未选"
		return
	var prof: Dictionary = Dialogue.get_profile(GameState.selected_panda)
	_panda_block.color = _profile_color(prof)
	_panda_info.text = "【占位】熊猫立绘：" + str(prof.get("name", "")) + " · " + str(prof.get("job", ""))


func _terminal_pressure() -> String:
	var done: int = 0
	for t in GameState.get_tasks():
		if str(GameState.tasks_status.get(str(t.get("id", "")), "locked")) == "done":
			done += 1
	var total: int = GameState.get_tasks().size()
	var missing: int = total - done
	if missing >= 2:
		return "多吉：「任务完成率低于基准值。」 小咪：「还有没收拾的地方！」"
	if missing == 1:
		return "帕丁：「家不能一直乱着。念念。」"
	return "多吉：「今日任务已完成，验收通过。」"


# ============================================================
# 物件选项（模态）
# ============================================================
func _show_modal_choices(title_text: String, options: Array) -> void:
	_clear_children(_dialogue_choices)
	_dialogue_speaker.text = ""
	_dialogue_text.text = title_text
	_next_button.visible = false
	for opt in options:
		var pair: Array = opt
		_dialogue_choices.add_child(_mk_button(str(pair[0]), pair[1]))
	_set_dialogue_modal(true)
	_dialogue_overlay.visible = true


func _on_object_sofa() -> void:
	_show_modal_choices("沙发 —— 先把地扫了吧", [
		["派小咪打扫（T01 · 2电1槽）", _on_dispatch_task.bind("T01")],
		["算了", _close_dialogue],
	])


func _on_object_shelf() -> void:
	_show_modal_choices("书架 —— 先把书架收拾一下吧", [
		["派多吉微课（T03 · 2电1槽）", _on_dispatch_task.bind("T03")],
		["算了", _close_dialogue],
	])


func _on_object_screen() -> void:
	var opts: Array = []
	for t in GameState.get_tasks():
		var tid: String = str(t.get("id", ""))
		var status: String = str(GameState.tasks_status.get(tid, "locked"))
		opts.append(["派工 · " + str(t.get("name", "")) + "（" + _status_cn(status) + "）", _on_dispatch_task.bind(tid)])
	opts.append(["听三终端说", _on_terminal_report])
	opts.append(["算了", _close_dialogue])
	_show_modal_choices("总控屏 —— 该派工了", opts)


func _on_object_heater() -> void:
	var opts: Array = []
	if not GameState.leak_found:
		opts.append(["检查密封口（探索 · 1电1槽）", _on_heater_explore])
	else:
		opts.append(["暖炉已标记漏水，等修", _close_dialogue])
	opts.append(["派帕丁修暖炉（T04 · 2电1槽）", _on_dispatch_task.bind("T04")])
	opts.append(["算了", _close_dialogue])
	_show_modal_choices("暖炉 —— 先把暖炉检查一下吧", opts)


func _on_object_lamp() -> void:
	_show_modal_choices("灯 —— 灯也该擦一擦", [
		["给灯命名「不加班灯」", _on_lamp_name],
		["算了", _close_dialogue],
	])


func _on_object_tree() -> void:
	_show_modal_choices("树洞角落", [
		["翻看便条", _on_tree_open],
		["算了", _close_dialogue],
	])


func _on_heater_explore() -> void:
	_close_dialogue()
	if not GameState.spend_energy(1) or not GameState.spend_slot():
		_show_feedback("探索失败：没电或没时间槽了。")
		return
	GameState.leak_found = true
	GameState.unlock_task("T04")
	_refresh_top()
	_show_feedback("发现暖炉密封口漏水了！可在暖炉处派工「修好暖炉密封口」。")


func _on_lamp_name() -> void:
	_close_dialogue()
	GameState.set_lamp_name("不加班灯")
	_refresh_top()
	_show_feedback("给那盏常亮的灯起名「不加班灯」。生成记忆候选 M03。")


func _on_tree_open() -> void:
	_close_dialogue()
	_clear_children(_tree_list)
	if GameState.notes.is_empty():
		_tree_list.add_child(_mk_label("（树洞角落还是空的。过夜后这里会长出便条。）"))
	else:
		for n in GameState.notes:
			_tree_list.add_child(_mk_label("第 " + str(n.get("day", "?")) + " 天：" + str(n.get("text", ""))))
	_tree_overlay.visible = true


func _on_dispatch_task(tid: String) -> void:
	_close_dialogue()
	if GameState.submit_task(tid):
		_refresh_top()
		_show_feedback("派工完成：" + _task_name(tid) + "。 " + _terminal_pressure())
	else:
		_show_feedback("派工失败（未解锁 / 没电 / 没时间槽）。")


func _on_terminal_report() -> void:
	_close_dialogue()
	_show_feedback(_terminal_pressure())


# ============================================================
# 对话框逻辑
# ============================================================
func _flatten_scene(scene: Dictionary) -> Array:
	var items: Array = []
	for ln: Dictionary in scene.get("lines", []):
		items.append({"kind": "line", "data": ln})
	var app: Array = scene.get("approach_choices", [])
	if app.size() > 0:
		items.append({"kind": "choices", "set": "approach", "data": app})
	for ln: Dictionary in scene.get("grievance_lines", []):
		items.append({"kind": "line", "data": ln})
	var comf: Array = scene.get("comfort_choices", [])
	if comf.size() > 0:
		items.append({"kind": "choices", "set": "comfort", "data": comf})
	for ln: Dictionary in scene.get("after_comfort", []):
		items.append({"kind": "line", "data": ln})
	var std: Array = scene.get("choices", [])
	if std.size() > 0:
		items.append({"kind": "choices", "set": "generic", "data": std})
	return items


func _play_scene(phase_id: String) -> void:
	var scene: Dictionary = Dialogue.resolve_scene(phase_id, GameState.selected_panda)
	if scene.is_empty():
		_show_feedback("没有这场剧情。")
		return
	_current_scene = {"phase": phase_id, "items": _flatten_scene(scene)}
	_current_line_index = 0
	_set_dialogue_modal(true)
	_dialogue_overlay.visible = true
	_show_current_item()


func _show_current_item() -> void:
	_clear_children(_dialogue_choices)
	_next_button.visible = false
	var items: Array = _current_scene.get("items", [])
	if _current_line_index >= items.size():
		if _ending_after_scene:
			_ending_after_scene = false
			_show_ending()
		else:
			_close_dialogue()
		return
	var item: Dictionary = items[_current_line_index]
	if str(item.get("kind", "")) == "line":
		var ln: Dictionary = item.get("data", {})
		_dialogue_speaker.text = str(ln.get("speaker", ""))
		_dialogue_text.text = str(ln.get("text", ""))
		_next_button.visible = true
	else:
		_dialogue_speaker.text = ""
		_dialogue_text.text = "（请选择）"
		_current_choice_set = str(item.get("set", "generic"))
		var choices: Array = item.get("data", [])
		for c: Dictionary in choices:
			_dialogue_choices.add_child(_mk_button(str(c.get("text", "")), _on_choice_pressed.bind(c)))


func _on_next_line() -> void:
	_current_line_index += 1
	_show_current_item()


func _on_choice_pressed(c: Dictionary) -> void:
	print("[选择] ", str(c.get("text", "")))
	var set: String = _current_choice_set
	var choice_id: String = str(c.get("id", ""))
	if set == "comfort":
		GameState.comfort_panda()
		if choice_id == "C":
			_show_feedback("灵魂镜像——「我看得见」。它被真正看见了。生成记忆 M05。")
		else:
			_show_feedback("它好受了一些。生成记忆 M05。")
		_refresh_top()
	_current_line_index += 1
	_show_current_item()


func _show_feedback(msg: String) -> void:
	_feedback.text = msg


func _close_dialogue() -> void:
	_dialogue_overlay.visible = false
	_set_dialogue_modal(false)
	_clear_children(_dialogue_choices)


# ============================================================
# 按钮回调
# ============================================================
func _on_select_panda(pid: String) -> void:
	var prof: Dictionary = Dialogue.get_profile(pid)
	GameState.select_panda(pid, str(prof.get("name", pid)))
	GameState.unlock_task("T01")
	GameState.unlock_task("T02")
	GameState.unlock_task("T03")
	_select_overlay.visible = false
	_refresh_top()
	_refresh_panda_block()
	_play_scene("S00")
	_show_feedback(_terminal_pressure())


func _on_end_day() -> void:
	_play_scene("S02b")


func _on_open_memory() -> void:
	_clear_children(_memory_list)
	for mid in GameState.kept_memory_ids:
		var mem: Dictionary = GameState.get_memory(mid)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label: Label = _mk_label("已留：[" + str(mem.get("title", mid)) + "]")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		row.add_child(_mk_button("删除", _on_delete_memory.bind(mid)))
		_memory_list.add_child(row)
	for mid in GameState.memory_candidates:
		var mem: Dictionary = GameState.get_memory(mid)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label: Label = _mk_label("候选：" + str(mem.get("title", mid)) + "（留=花" + str(mem.get("keep_cost", 0)) + "电）")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		row.add_child(_mk_button("留", _on_keep_memory.bind(mid)))
		_memory_list.add_child(row)
	if GameState.memory_candidates.is_empty() and GameState.kept_memory_ids.is_empty():
		_memory_list.add_child(_mk_label("（还没有记忆候选。先点暖炉/灯/安慰它，就有候选了。）"))
	_memory_overlay.visible = true


func _on_keep_memory(mid: String) -> void:
	if GameState.keep_memory(mid):
		var mem: Dictionary = GameState.get_memory(mid)
		_show_feedback("留住了记忆「" + str(mem.get("title", mid)) + "」（花了 " + str(mem.get("keep_cost", 0)) + " 电）")
		_refresh_top()
		_on_open_memory()
	else:
		_memory_overlay.visible = false
		_show_feedback("留不下（沉淀槽已满，先删除已留的 或 电量不够）")


func _on_delete_memory(mid: String) -> void:
	GameState.delete_memory(mid)
	var mem: Dictionary = GameState.get_memory(mid)
	_show_feedback("已删除记忆「" + str(mem.get("title", mid)) + "」，可以另留一条。")
	_refresh_top()
	_on_open_memory()


func _on_new_day() -> void:
	GameState.start_new_day()
	_refresh_top()
	_show_feedback("第 " + str(GameState.day_count) + " 天开始了。你忘了昨天，只有「沉淀」里那一件还在。树洞角落多了一张便条。")


func _on_check_break() -> void:
	if GameState.can_break_loop():
		_ending_after_scene = true
		_play_scene("S04")
	else:
		var msg: String = "还没破局。还差 → "
		if not GameState.m05_remembered_today:
			msg += "「昨夜把《它今天受委屈了》留进沉淀」 "
		if not GameState.comforted_today:
			msg += "「今天再主动安慰它」"
		_show_feedback(msg)


func _on_reset() -> void:
	GameState.reset_for_new_game()
	_ending_overlay.visible = false
	_title_overlay.visible = false
	_set_dialogue_modal(false)
	_refresh_top()
	_refresh_panda_block()
	_select_overlay.visible = true


func _close_memory() -> void:
	_memory_overlay.visible = false


func _close_tree() -> void:
	_tree_overlay.visible = false
