extends Control
class_name NotesBrowser
## ============================================================
## NotesBrowser —— 便条翻阅（B 独占：scripts/ui/notes_browser.gd）
##
## 冰箱门上的一沓便条（S03「树洞角落」意象的实体入口）：
## 上一张 / 下一张逐张翻，日期递增、内容几乎一样（验收 A-Q4：
## 玩家亲手一张张翻，自己数出「已经第 N 张了」）。
## open() 每次从 GameState.notes 全量重读。
## ============================================================

signal closed

var _page := 0
var _date_label: Label
var _text_label: Label
var _count_label: Label
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 340)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.97, 0.95, 0.88, 0.98)
	s.set_corner_radius_all(4)
	s.set_border_width_all(2)
	s.border_color = Color(0.55, 0.5, 0.4)
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)

	var head := Label.new()
	head.text = "冰箱上的便条"
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color(0.35, 0.3, 0.25))
	col.add_child(head)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 15)
	_date_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	col.add_child(_date_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 19)
	_text_label.add_theme_color_override("font_color", Color(0.25, 0.22, 0.18))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(500, 130)
	# 便条是手写体意象：斜一点。
	_text_label.rotation = 0.015
	col.add_child(_text_label)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
	col.add_child(_count_label)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(nav)
	var prev := Button.new()
	prev.text = "← 上一张"
	prev.pressed.connect(page.bind(-1))
	nav.add_child(prev)
	var next := Button.new()
	next.text = "下一张 →"
	next.pressed.connect(page.bind(1))
	nav.add_child(next)
	var close := Button.new()
	close.text = "合上冰箱门"
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	nav.add_child(close)

	visible = false


## 打开翻阅（从最新一张开始往回翻，符合「翻旧账」的演出）。
func open() -> void:
	_page = maxi(GameState.notes.size() - 1, 0)
	visible = true
	_render()


## 可编程翻页：delta = -1 / +1（冒烟/测试用）。
func page(delta: int) -> void:
	var n: int = GameState.notes.size()
	if n == 0:
		return
	_page = clampi(_page + delta, 0, n - 1)
	_render()


func get_page_index() -> int:
	return _page


func get_note_count() -> int:
	return GameState.notes.size()


# ============================================================
# 内部
# ============================================================

func _render() -> void:
	var notes: Array = GameState.notes
	if notes.is_empty():
		_date_label.text = "（还没有便条）"
		_text_label.text = "冰箱门上干干净净。"
		_count_label.text = ""
		return
	var note: Dictionary = notes[_page]
	_date_label.text = "第 %d 天" % int(note.get("date", 0))
	_text_label.text = String(note.get("text", ""))
	_count_label.text = "第 %d / %d 张" % [_page + 1, notes.size()]
