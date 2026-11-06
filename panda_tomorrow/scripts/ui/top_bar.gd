extends PanelContainer
class_name TopBar
## ============================================================
## TopBar —— 顶栏（B 独占：scripts/ui/top_bar.gd）
##
## 一行显示：第 N 天 · 电 8 格 · 净水/待回收 · 家光 · 便条数 · 幕。
## 耗掉的电格子变暗（▮→▯）；数据全部读 GameState（只调用不改）。
## refresh() 全量重绘；main.gd 在资源变动后调用。
## ============================================================

var _info: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 44)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.13, 0.92)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.32, 0.28, 0.6)
	add_theme_stylebox_override("panel", style)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_info)
	refresh()


## 全量刷新（读 GameState；任何资源变动后由 main 调用）。
func refresh() -> void:
	var gs := GameState
	# 电 8 格：前 energy 格亮、其余暗。
	var cells := ""
	for i in range(gs.ENERGY_MAX):
		cells += "▮" if i < gs.energy else "▯"
	# 水：净水亮蓝格 + 待回收灰格（守恒：合计恒 2）。
	var water := ""
	for i in range(gs.clean_water):
		water += "▓"
	for i in range(gs.pending_water):
		water += "░"
	# 记忆槽：单槽。留了显示标题，空槽显示「空」。
	var kept := "空"
	if gs.kept_id != "":
		var m: Dictionary = gs.get_memory_info(gs.kept_id)
		kept = String(m.get("title", gs.kept_id))
	var phase_name := "第 %d 幕" % gs.phase
	_info.text = "  第 %d 天  ·  电 %s %d/%d  ·  水 %s 净%d 待%d  ·  家光 ✦ %d  ·  便条 %d 张  ·  记忆槽【%s】  ·  %s  " % [
		gs.day_number(),
		cells, gs.energy, gs.ENERGY_MAX,
		water, gs.clean_water, gs.pending_water,
		gs.jg, gs.notes.size(), kept, phase_name,
	]


## 冒烟/测试断言用：返回当前显示文本。
func get_display_text() -> String:
	return _info.text
