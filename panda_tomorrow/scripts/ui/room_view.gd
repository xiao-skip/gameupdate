extends Control
class_name RoomView
## ============================================================
## RoomView —— 四房间视图（B 独占：scripts/ui/room_view.gd）
##
## 玄关 → 客厅 → 厨房 → 暖炉房，首尾传送（第 4 间再往前 = 回到第 1 间，
## 首次完成一圈时 mark_loop_completed 并解锁快捷切换 tab）。
## 物件（点击发 object_clicked，由 main 编排剧情/结算）：
##   footprint 湿脚印（S01 入口，未标记漏水时可见）
##   lamp      常亮的灯（S02 入口；命名后显示灯名）
##   nameplate 名牌（显示熊猫名）
##   fridge    冰箱·一沓便条（便条翻阅入口，A-Q4）
##   valve     暖炉回水阀（T04 派工入口；有待回收水时高亮）
## ============================================================

signal object_clicked(obj_id: String)
signal loop_completed

const ROOMS := [
	{"name": "玄关", "objects": ["footprint"]},
	{"name": "客厅", "objects": ["lamp", "nameplate"]},
	{"name": "厨房", "objects": ["fridge"]},
	{"name": "暖炉房", "objects": ["valve"]},
]

var current_room := 0

var _room_label: Label
var _objects_box: VBoxContainer
var _tab_row: HBoxContainer
var _hint: Label


func _ready() -> void:
	# 背板
	var bg := PanelContainer.new()
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.12, 0.10, 0.85)
	s.set_corner_radius_all(8)
	s.set_border_width_all(1)
	s.border_color = Color(0.45, 0.4, 0.32, 0.5)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	bg.add_theme_stylebox_override("panel", s)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 10
	col.offset_bottom = -10
	add_child(col)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 6)
	col.add_child(_tab_row)

	_room_label = Label.new()
	_room_label.add_theme_font_size_override("font_size", 24)
	_room_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	col.add_child(_room_label)

	_objects_box = VBoxContainer.new()
	_objects_box.add_theme_constant_override("separation", 8)
	_objects_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_objects_box)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.58, 0.56, 0.5))
	col.add_child(_hint)
	refresh()


## 全量刷新（房间名、物件可用性、快捷 tab）。
func refresh() -> void:
	var gs := GameState
	_room_label.text = "%s（%d/4）" % [String(ROOMS[current_room]["name"]), current_room + 1]

	for c in _objects_box.get_children():
		_objects_box.remove_child(c)
		c.queue_free()
	for obj_id in ROOMS[current_room]["objects"]:
		var btn := _build_object_button(String(obj_id))
		if btn != null:
			_objects_box.add_child(btn)

	# 快捷切换 tab（走完一圈解锁；B4 房间快捷切换）。
	for c in _tab_row.get_children():
		_tab_row.remove_child(c)
		c.queue_free()
	if gs.looped_once:
		for i in range(ROOMS.size()):
			var tab := Button.new()
			tab.text = String(ROOMS[i]["name"])
			tab.toggle_mode = true
			tab.button_pressed = (i == current_room)
			tab.disabled = (i == current_room)
			tab.pressed.connect(goto_room.bind(i))
			_tab_row.add_child(tab)
	else:
		var tip := Label.new()
		tip.text = "把四个房间走完一圈（在暖炉房再往前走），解锁房间快捷切换"
		tip.add_theme_font_size_override("font_size", 13)
		tip.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46))
		_tab_row.add_child(tip)

	_hint.text = "← → 切换房间"
	match current_room:
		3:
			_hint.text = "→ 再往前走，就回到玄关（首尾传送）"


## 切换房间（环形）。在暖炉房（index 3）再前进 → 回玄关并判定「走完一圈」。
func goto_room(index: int) -> void:
	var gs := GameState
	var n: int = ROOMS.size()
	var next: int = index
	if index >= n:
		next = 0
	elif index < 0:
		next = n - 1
	# 首尾传送判定：从最后一间前进回到第一间。
	if next == 0 and current_room == n - 1 and not gs.looped_once:
		gs.mark_loop_completed()
		loop_completed.emit()
	current_room = next
	refresh()


func go_next() -> void:
	goto_room(current_room + 1)


func go_prev() -> void:
	goto_room(current_room - 1)


## 可编程点击物件（冒烟/测试用）。
func click_object(obj_id: String) -> void:
	object_clicked.emit(obj_id)


func get_current_room_name() -> String:
	return String(ROOMS[current_room]["name"])


# ============================================================
# 内部
# ============================================================

func _build_object_button(obj_id: String) -> Control:
	var gs := GameState
	var text := ""
	var sub := ""
	var enabled := true
	match obj_id:
		"footprint":
			# 湿脚印：漏未标记时可见（S01 入口）；标记后已处理。
			if gs.leak_marked:
				return null
			text = "🐾 一串湿脚印"
			sub = "水从暖炉那边渗出来的……去看看"
		"lamp":
			if gs.lamp_named:
				text = "💡 不加班灯（已命名）"
				sub = "灯负责亮，我们负责休息。"
				enabled = false
			else:
				text = "💡 一盏常亮的灯"
				sub = "它一直亮着……"
		"nameplate":
			if gs.panda_name == "":
				return null
			text = "🏷 名牌：%s" % gs.panda_name
			sub = "竹城环巷 37 号的住户。"
			enabled = false
		"fridge":
			var count: int = gs.notes.size()
			if count == 0:
				text = "🧊 冰箱门上贴着什么"
				sub = "好像有一角纸片……"
			else:
				text = "🧊 冰箱 · 一沓便条（%d 张）" % count
				sub = "点开一张张翻"
		"valve":
			var pending: int = gs.pending_water
			if pending > 0:
				text = "🔧 暖炉回水阀（待回收 ×%d）" % pending
				sub = "把用掉的水收回来（T04 派工入口）"
			elif gs.water_returned:
				text = "🔧 暖炉回水阀（已回水）"
				sub = "密封口修好了。水会回家。"
				enabled = false
			else:
				text = "🔧 暖炉回水阀"
				sub = "还没有待回收的水。"
				enabled = false
		_:
			return null

	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.17, 0.15, 0.9) if enabled else Color(0.14, 0.14, 0.13, 0.7)
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = Color(0.7, 0.6, 0.4, 0.8) if enabled else Color(0.4, 0.38, 0.33, 0.5)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", s)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8) if enabled else Color(0.55, 0.53, 0.48))
	col.add_child(t)
	var d := Label.new()
	d.text = sub
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	col.add_child(d)

	if enabled:
		var btn := Button.new()
		btn.text = "查看"
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		btn.pressed.connect(func() -> void: object_clicked.emit(obj_id))
		col.add_child(btn)
	return card


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_RIGHT:
			go_next()
		elif event.keycode == KEY_LEFT:
			go_prev()
