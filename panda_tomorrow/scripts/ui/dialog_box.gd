extends PanelContainer
class_name DialogBox
## ============================================================
## DialogBox —— 打字机对话框（B 独占：scripts/ui/dialog_box.gd）
##
## 三种交互（全部 await 调用）：
##   var line := await dialog.show_line("小咪", "咦……")
##   var choice := await dialog.show_options([{id,text},...])
##   var name := await dialog.show_input("给它起个名字", "花花")
##
## 自动化（冒烟测试）：auto_mode = true 时不等玩家——
##   行打完立刻返回、选项自动选 auto_option_index、输入自动填 auto_input_text。
## typing_speed = 0 表示关闭打字机（整段立刻显示，测试提速用）。
## ============================================================

## 玩家点了「继续」（正文全文显示后点才有效）。供打字中点击跳字实现。
signal advanced

var typing_speed: float = 0.03   ## 秒/字；0 = 不打字直接全文
var auto_mode: bool = false      ## 冒烟：跳过所有等待
var auto_option_index: int = 0   ## 冒烟：自动选第几个选项
var auto_input_text: String = "" ## 冒烟：自动提交的命名

var _speaker_label: Label
var _text_label: RichTextLabel
var _options_box: VBoxContainer
var _input_row: HBoxContainer
var _input_edit: LineEdit
var _input_ok: Button
var _continue_hint: Label

var _full_text := ""
var _shown_count := 0
var _typing := false
var _option_picked := false       ## show_options 的内部完成标记
var _option_result: Dictionary = {}
var _input_done_flag := false
var _input_result := ""


func _ready() -> void:
	custom_minimum_size = Vector2(0, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.48, 0.36, 0.7)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 17)
	_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	_speaker_label.custom_minimum_size = Vector2(180, 0)
	head.add_child(_speaker_label)
	_continue_hint = Label.new()
	_continue_hint.add_theme_font_size_override("font_size", 13)
	_continue_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_continue_hint.text = "点击继续 ▾"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_continue_hint)

	_text_label = RichTextLabel.new()
	_text_label.add_theme_font_size_override("normal_font_size", 18)
	_text_label.bbcode_enabled = false
	_text_label.fit_content = false
	_text_label.custom_minimum_size = Vector2(0, 78)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 6)
	col.add_child(_options_box)

	_input_row = HBoxContainer.new()
	_input_row.add_theme_constant_override("separation", 8)
	col.add_child(_input_row)
	var prompt := Label.new()
	prompt.text = "名字："
	prompt.add_theme_font_size_override("font_size", 17)
	_input_row.add_child(prompt)
	_input_edit = LineEdit.new()
	_input_edit.add_theme_font_size_override("font_size", 17)
	_input_edit.placeholder_text = "输入名字，回车确认"
	_input_edit.custom_minimum_size = Vector2(360, 0)
	_input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_edit.text_submitted.connect(_on_input_submitted)
	_input_row.add_child(_input_edit)
	_input_ok = Button.new()
	_input_ok.text = "就这样叫"
	_input_ok.pressed.connect(func() -> void: _on_input_submitted(_input_edit.text))
	_input_row.add_child(_input_ok)

	_clear_dynamic()
	gui_input.connect(_on_gui_input)


func _process(delta: float) -> void:
	if not _typing:
		return
	_shown_count += int(maxf(1.0, delta / maxf(typing_speed, 0.001)))
	_apply_typing()
	if _shown_count >= _full_text.length():
		_finish_typing()


# ============================================================
# 对外接口（全部可 await）
# ============================================================

## 打一行台词。返回时全文已显示（auto_mode 立即返回）。
func show_line(speaker: String, text: String) -> void:
	_clear_dynamic()
	_options_box.visible = false
	_input_row.visible = false
	_speaker_label.visible = true
	_speaker_label.text = speaker
	_continue_hint.visible = false
	_full_text = text
	if typing_speed <= 0.0 or auto_mode or _full_text.is_empty():
		_shown_count = _full_text.length()
		_apply_typing()
		_finish_typing()
		if auto_mode:
			return
		await advanced
		return
	_shown_count = 0
	_typing = true
	_apply_typing()
	await advanced


## 显示选项列表；await 返回被选中的那条 Dictionary（原样返回，含 id/text）。
func show_options(options: Array) -> Dictionary:
	_clear_dynamic()
	_options_box.visible = true
	_input_row.visible = false
	_speaker_label.visible = true
	_speaker_label.text = "选择"
	_continue_hint.visible = false
	_text_label.text = ""
	_option_picked = false
	_option_result = {}
	var i := 0
	for opt in options:
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, String(opt.get("text", ""))]
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_option.bind(opt))
		_options_box.add_child(b)
		i += 1
	if auto_mode:
		_on_option(options[clampi(auto_option_index, 0, options.size() - 1)])
	while not _option_picked:
		await get_tree().process_frame
	return _option_result


## 显示命名输入；await 返回输入文本（空输入回退 default）。
func show_input(prompt: String, default: String) -> String:
	_clear_dynamic()
	_options_box.visible = false
	_input_row.visible = true
	_speaker_label.visible = true
	_speaker_label.text = prompt
	_continue_hint.visible = false
	_text_label.text = ""
	_input_edit.text = default
	_input_done_flag = false
	_input_result = ""
	_input_edit.grab_focus()
	if auto_mode:
		_on_input_submitted(auto_input_text if auto_input_text != "" else default)
	while not _input_done_flag:
		await get_tree().process_frame
	return _input_result


## 纯旁白提示（不打字、不带说话人；轻量 toast 式）。
func show_note(text: String) -> void:
	await show_line("旁白", text)


# ============================================================
# 交互处理（含可编程入口，测试/自动化共用）
# ============================================================

## 可编程：直接选第 index 个选项（冒烟或键盘快捷）。
func pick_option_index(index: int) -> void:
	if _options_box.visible and index < _options_box.get_child_count():
		var btn: Button = _options_box.get_child(index)
		btn.pressed.emit()


func _on_option(opt: Dictionary) -> void:
	_option_result = opt
	_option_picked = true
	_clear_dynamic()


func _on_input_submitted(text: String) -> void:
	if not _input_row.visible:
		return
	var final := text.strip_edges()
	if final == "":
		final = _input_edit.text.strip_edges()
	_input_result = final
	_input_done_flag = true
	_clear_dynamic()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _typing:
			skip_typing()
		elif _continue_hint.visible:
			advanced.emit()


## 打字中点击 → 立即显示全文；再次点击 → 发 advanced。
func skip_typing() -> void:
	_shown_count = _full_text.length()
	_apply_typing()
	_finish_typing()


# ============================================================
# 内部
# ============================================================

func _apply_typing() -> void:
	var n: int = clampi(_shown_count, 0, _full_text.length())
	_text_label.text = _full_text.substr(0, n)


func _finish_typing() -> void:
	_typing = false
	_text_label.text = _full_text
	_continue_hint.visible = not auto_mode


func _clear_dynamic() -> void:
	for c in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()
	_options_box.visible = false
	_input_row.visible = false
