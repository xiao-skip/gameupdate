extends Control
## ============================================================
## Main —— 主控制器（B 独占：scripts/ui/main.gd + scenes/main.tscn）
##
## 第一幕状态机（分工文档 4.3-B）：
##   INTRO(S00 选熊猫+命名) → MORNING → DAY(派工/物件/房间)
##   → EVENING(S02b 委屈+安慰) → NIGHT(记忆沉淀) → restart(黑屏2秒) → MORNING…
##   can_proceed_act1 四条件满足 → S03 反转 → 第一幕完。
##
## 三种跑法：
##   godot --path panda_tomorrow                正常游戏
##   godot --headless --path . -- --data-test   数据层验收（test_act1，103 项）
##   godot --headless --path . -- --smoke       UI 冒烟（自动过完两天+幕完+退出码）
## ============================================================

enum Stage { INTRO, MORNING, DAY, EVENING, NIGHT, ACT1_END }

var _stage: int = Stage.INTRO

var _top_bar: TopBar
var _room_view: RoomView
var _task_panel: TaskPanel
var _dialog: DialogBox
var _night_memory: NightMemory
var _notes_browser: NotesBrowser
var _fade: ColorRect
var _day_ui: VBoxContainer     # 白天交互区（任务面板 + 侧栏）
var _act1_panel: PanelContainer

## 破局待播：夜里留了 M05 且四条件满足 → restart → 次日傍晚播 S04（A-Q5）。
var _breakthrough_pending := false

## 冒烟模式：打字机全关 + 对话自动推进。
var _smoke := false
var _smoke_passed := 0
var _smoke_failed := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--data-test" in args:
		_run_data_test()
		return
	if "--smoke" in args:
		_smoke = true
		_build_ui()
		_run_smoke()
		return
	_build_ui()
	_start_game()


# ============================================================
# 启动
# ============================================================

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	_top_bar = TopBar.new()
	_top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	_top_bar.offset_bottom = 44
	add_child(_top_bar)

	_room_view = RoomView.new()
	_room_view.set_anchors_preset(PRESET_FULL_RECT)
	_room_view.offset_top = 48
	_room_view.offset_bottom = -240
	add_child(_room_view)
	_room_view.object_clicked.connect(_on_object_clicked)
	_room_view.loop_completed.connect(func() -> void:
		_toast("房间快捷切换已解锁"))

	_day_ui = VBoxContainer.new()
	_day_ui.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_day_ui.offset_top = -236
	add_child(_day_ui)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	_day_ui.add_child(bottom_row)

	_task_panel = TaskPanel.new()
	_task_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(_task_panel)
	_task_panel.task_clicked.connect(_on_task_clicked)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 8)
	bottom_row.add_child(side)
	var dark_button := Button.new()
	dark_button.text = "天黑了，等它回家"
	dark_button.custom_minimum_size = Vector2(0, 52)
	dark_button.add_theme_font_size_override("font_size", 17)
	dark_button.pressed.connect(func() -> void: _evening())
	side.add_child(dark_button)
	var tips := Label.new()
	tips.text = "白天：派工、看房间、点物件。\n电量耗尽前把想做的做完。"
	tips.add_theme_font_size_override("font_size", 13)
	tips.add_theme_color_override("font_color", Color(0.55, 0.53, 0.5))
	side.add_child(tips)

	_dialog = DialogBox.new()
	_dialog.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_dialog.offset_top = -176
	if _smoke:
		_dialog.typing_speed = 0.0
		_dialog.auto_mode = true
		_dialog.auto_input_text = "团团"
	add_child(_dialog)

	_notes_browser = NotesBrowser.new()
	add_child(_notes_browser)

	_night_memory = NightMemory.new()
	add_child(_night_memory)
	_night_memory.night_confirmed.connect(_on_night_confirmed)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	GameState.day_restarted.connect(func() -> void:
		_fade.color = Color(0, 0, 0, 1))
	_refresh_all()


func _start_game() -> void:
	if GameState.panda_name == "":
		await _intro()
	else:
		await _morning()


func _refresh_all() -> void:
	_top_bar.refresh()
	_task_panel.refresh()
	_room_view.refresh()


# ============================================================
# S00 降临（选熊猫 + 命名，只播一次）
# ============================================================

func _intro() -> void:
	_stage = Stage.INTRO
	_set_day_ui_visible(false)
	await _dialog.show_line("旁白", "【黑屏。2046 年数据流如星河流淌。一封《守护协议》缓缓展开：目的地竹城环巷 37 号；绑定期限终身。】")
	await _dialog.show_line("旁白", "灵魂镜像绑定开始——先看看你的熊猫是谁。")

	# 选熊猫：渲染任意档案列表（Dialogue 归 C，B 只调用）。
	var ids: Array = Dialogue.get_panda_ids()
	var options: Array = []
	for pid in ids:
		var p: Dictionary = Dialogue.get_profile(String(pid))
		options.append({
			"id": String(pid),
			"text": "%s · %s · %s" % [p.get("name", pid), p.get("job", ""), p.get("personality", "")],
		})
	var choice: Dictionary = await _dialog.show_options(options)
	var preset := String(choice.get("id", ""))
	GameState.panda_preset = preset

	# S00 正片（占位符已按所选熊猫换皮）。
	var scene: Dictionary = Dialogue.resolve_scene("S00", preset)
	for line in scene.get("lines", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))

	# 命名。
	var default_name := String(Dialogue.get_profile(preset).get("name", ""))
	var name_input := await _dialog.show_input("给它起个名字", default_name)
	GameState.panda_name = name_input
	GameState.save_game()
	_refresh_all()
	_toast("它叫%s。明早它去邮局上班，你照看这个家。" % name_input)
	await _morning()


# ============================================================
# 每日循环
# ============================================================

func _morning() -> void:
	_stage = Stage.MORNING
	_set_day_ui_visible(false)
	var day: int = GameState.day_number()
	await _dialog.show_line("旁白", "【第 %d 天。%s出门去邮局上班了。屋里安静下来。】" % [day, GameState.panda_name])
	if GameState.kept_id != "":
		var m: Dictionary = GameState.get_memory_info(GameState.kept_id)
		await _dialog.show_line("旁白", "……你还记得：《%s》。" % String(m.get("title", "")))
	await _day()


func _day() -> void:
	_stage = Stage.DAY
	_set_day_ui_visible(true)
	_refresh_all()


func _evening() -> void:
	_stage = Stage.EVENING
	_set_day_ui_visible(false)
	if _breakthrough_pending:
		# A-Q5 破局：念念带着《它被骂了》的记忆，不等它开口先说话（S04）。
		_breakthrough_pending = false
		await _play_s04()
		_act1_end(true)
		return
	if not GameState.comforted:
		await _play_s02b()
	else:
		await _dialog.show_line("旁白", "【门响。%s回来了，看起来和平常一样。】" % GameState.panda_name)
		await _dialog.show_line(GameState.panda_name, "我回来了。……今天也没什么特别的。")
		if GameState.kept_id != "":
			var m: Dictionary = GameState.get_memory_info(GameState.kept_id)
			await _dialog.show_line("旁白", "……你还记得：《%s》。" % String(m.get("title", "")))
	await _night()


func _night() -> void:
	_stage = Stage.NIGHT
	_night_memory.open()


## night_confirmed 信号驱动（kept_id = 最终留存；空串 = 空槽）。
func _on_night_confirmed(kept_id: String) -> void:
	if GameState.can_proceed_act1():
		await _play_s03()
		if GameState.kept_id == "M05":
			# A-Q5：留了《它被骂了》→ 次日 S04 破局（第一幕真结局线）。
			_breakthrough_pending = true
			_do_restart()
		else:
			_act1_end()
	else:
		_do_restart()


## restart：便条 + Day 重置 + 检查点（GameState 全做），UI 播黑屏 2 秒过渡。
func _do_restart() -> void:
	GameState.restart()
	await _fade_sequence()
	_refresh_all()
	await _morning()


# ============================================================
# 剧情场（读 C 的 script.json，B 只编排交互与状态接线）
# ============================================================

## S01 湿脚印：发现漏 → 标记 → M01 候选。
func _play_s01() -> void:
	var scene: Dictionary = Dialogue.resolve_scene("S01", GameState.panda_preset)
	for line in scene.get("lines", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))
	await _dialog.show_options(scene.get("choices", []))
	GameState.mark_leak()
	GameState.add_memory_candidate("M01")
	_toast("你记下：用掉的水，会从暖炉密封口回来。（今晚可留《水会回家》）")
	_refresh_all()


## S02 给灯命名：温馨收尾 → M03 候选。
func _play_s02() -> void:
	var scene: Dictionary = Dialogue.resolve_scene("S02", GameState.panda_preset)
	for line in scene.get("lines", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))
	var _choice: Dictionary = await _dialog.show_options(scene.get("choices", []))
	GameState.name_lamp()
	GameState.add_memory_candidate("M03")
	_toast("灯有了名字。小板凳挪到了总控屏旁。（今晚可留《不加班灯》）")
	_refresh_all()


## S02b 它回家很晚：approach → grievance → comfort → after_comfort。
func _play_s02b() -> void:
	var scene: Dictionary = Dialogue.resolve_scene("S02b", GameState.panda_preset)
	for line in scene.get("lines", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))
	await _dialog.show_options(scene.get("approach_choices", []))
	for line in scene.get("grievance_lines", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))
	var comfort: Dictionary = await _dialog.show_options(scene.get("comfort_choices", []))
	for line in scene.get("after_comfort", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))
	GameState.set_comforted(String(comfort.get("id", "")))
	GameState.add_memory_candidate("M05")
	_toast("它睡了。今晚的候选里多了一条……")
	_refresh_all()


## S03 反转：翻便条演出（玩家亲手翻，数出「已经第 N 张了」）。
func _play_s03() -> void:
	var scene: Dictionary = Dialogue.resolve_scene("S03", GameState.panda_preset)
	var lines: Array = scene.get("lines", [])
	for i in range(mini(3, lines.size())):
		await _dialog.show_line(String(lines[i].get("speaker", "")), String(lines[i].get("text", "")))
	# 玩家亲手翻便条（A-Q4：日期递增、内容几乎一样）。
	_notes_browser.open()
	await _notes_browser.closed
	if lines.size() > 3:
		await _dialog.show_line(String(lines[3].get("speaker", "")), String(lines[3].get("text", "")))
	await _dialog.show_line("旁白", "它不是第一次受委屈，也不是第一次告诉你。而你，每天都忘。")


## S04 破局（队友 Junsheng-Wang2026 撰写，C 的 script.json）：
## 念念带着《它被骂了》的记忆，次日不等它开口先说话——跳出循环，第一幕真结局。
func _play_s04() -> void:
	var scene: Dictionary = Dialogue.resolve_scene("S04", GameState.panda_preset)
	for line in scene.get("lines", []):
		await _dialog.show_line(String(line.get("speaker", "")), String(line.get("text", "")))


# ============================================================
# 第一幕完
# ============================================================

func _act1_end(true_end: bool = false) -> void:
	_stage = Stage.ACT1_END
	_act1_panel = PanelContainer.new()
	_act1_panel.set_anchors_preset(PRESET_FULL_RECT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.05, 0.96)
	_act1_panel.add_theme_stylebox_override("panel", s)
	add_child(_act1_panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	_act1_panel.add_child(col)

	var title := Label.new()
	title.text = "第一幕 完"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	col.add_child(title)

	var sub := Label.new()
	if true_end:
		sub.text = "「它不是第一次说这句话。可念念第一次，真的记住了。」"
	else:
		sub.text = "「它不是第一次说。」"
	sub.add_theme_font_size_override("font_size", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	col.add_child(sub)

	var stats := Label.new()
	var kept_title := "空"
	if GameState.kept_id != "":
		kept_title = String(GameState.get_memory_info(GameState.kept_id).get("title", "空"))
	stats.text = "家光 ✦ %d   ·   便条 %d 张   ·   记忆槽【%s】" % [
		GameState.jg, GameState.notes.size(), kept_title]
	stats.add_theme_font_size_override("font_size", 17)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.65, 0.63, 0.58))
	col.add_child(stats)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	col.add_child(actions)
	if not true_end:
		var cont := Button.new()
		cont.text = "继续下一天"
		cont.custom_minimum_size = Vector2(160, 48)
		cont.pressed.connect(func() -> void:
			_act1_panel.queue_free()
			_do_restart())
		actions.add_child(cont)
	else:
		var stay := Button.new()
		stay.text = "留在这个家"
		stay.custom_minimum_size = Vector2(160, 48)
		stay.pressed.connect(func() -> void:
			_act1_panel.queue_free()
			_day())
		actions.add_child(stay)
	var fresh := Button.new()
	fresh.text = "从头开始"
	fresh.custom_minimum_size = Vector2(160, 48)
	fresh.pressed.connect(func() -> void:
		_act1_panel.queue_free()
		GameState.reset_for_new_game()
		_intro())
	actions.add_child(fresh)

	if _smoke and not true_end:
		# 冒烟：循环结局不停留在按钮，直接走「继续下一天」；真结局是终局，停住由冒烟断言接管。
		_act1_panel.queue_free()
		_do_restart()


# ============================================================
# 白天交互（任务 / 物件）
# ============================================================

func _on_task_clicked(id: String) -> void:
	_do_task(id)


func _do_task(id: String) -> void:
	if _stage != Stage.DAY:
		return
	var result: Dictionary = GameState.submit_task(id)
	if bool(result.get("ok", false)):
		var extra := ""
		if result.has("water_returned"):
			extra = "，回收了 %d 份水" % int(result["water_returned"])
		_toast("%s 完成：家光 +✦%d%s" % [id, int(result.get("jg", 0)), extra])
	else:
		var why: String = {
			"unknown_task": "没这个任务。",
			"already_done": "今天已经派过了。",
			"no_energy": "电不够了……等明天吧。",
			"no_water": "净水不够。先回水？",
			"no_pending_water": "还没有待回收的水。",
		}.get(String(result.get("reason", "")), "现在做不了。")
		_toast("%s：%s" % [id, why])
	_refresh_all()


func _on_object_clicked(obj_id: String) -> void:
	if _stage != Stage.DAY:
		return
	match obj_id:
		"footprint":
			await _play_s01()
		"lamp":
			await _play_s02()
		"fridge":
			_notes_browser.open()
			# 翻便条的领悟（破局路径）：安慰过它 + 冰箱上有便条 → 重新意识到
			# 「它不是第一次受委屈」→ M05 重新进今晚候选（走 A 的公共接口）。
			if GameState.comforted and GameState.notes.size() >= 1:
				GameState.add_memory_candidate("M05")
				_toast("一沓几乎一样的便条。它不是第一次受委屈，也不是第一次告诉你。")
		"valve":
			_do_task("T04")


# ============================================================
# UI 辅助
# ============================================================

func _set_day_ui_visible(v: bool) -> void:
	_day_ui.visible = v


func _toast(text: String) -> void:
	print("[UI] ", text)


## 黑屏过渡（day_restarted 契约：黑 2 秒；冒烟/测试时快速）。
func _fade_sequence() -> void:
	var duration := 2.0 if not _smoke else 0.05
	_fade.color = Color(0, 0, 0, 1)
	await get_tree().create_timer(duration).timeout
	_fade.color = Color(0, 0, 0, 0)


# ============================================================
# 数据层验收（test_act1：A 的 103 项，入口保持不变）
# ============================================================

func _run_data_test() -> void:
	var test = load("res://scripts/core/test_act1.gd").new()
	var summary: Dictionary = test.run()
	var ok: int = int(summary.get("passed", 0))
	var total: int = int(summary.get("total", 0))
	var failures: Array = summary.get("failures", [])
	print("数据层验收：%d/%d 通过" % [ok, total])
	for f in failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if failures.size() > 0 or ok < total else 0)


# ============================================================
# UI 冒烟（自动过完第一天 → 第二天回水 → 反转 → 幕完）
# ============================================================

func _run_smoke() -> void:
	print("===== UI 冒烟开始（auto 模式）=====")
	GameState.reset_for_new_game()

	# ---- S00 降临（选熊猫 + 命名 → 早上 → 白天）----
	await _intro()
	_smoke_check("S00：熊猫已命名（名字+预设写入）", GameState.panda_name != "" and GameState.panda_preset != "")
	_smoke_check("S00 后进入白天", _stage == Stage.DAY)
	# 走完一圈房间（首尾传送 + 快捷解锁，B4）。
	for i in range(4):
		_room_view.go_next()
		await get_tree().process_frame
	_smoke_check("B4：走完一圈解锁快捷切换", GameState.looped_once)

	# 派工 T01+T02+T03。
	_do_task("T01")
	_do_task("T02")
	_do_task("T03")
	_smoke_check("派 T01-03 后：电=2 净水=0 待回收=2 家光=6",
		GameState.energy == 2 and GameState.clean_water == 0 and GameState.pending_water == 2 and GameState.jg == 6)

	# S01 湿脚印（物件驱动剧情）。
	await _play_s01()
	_smoke_check("S01：漏已标记 + M01 进候选", GameState.leak_marked and GameState.memory_candidates.has("M01"))

	# S02 灯命名。
	await _play_s02()
	_smoke_check("S02：灯已命名 + M03 进候选", GameState.lamp_named and GameState.memory_candidates.has("M03"))

	# ---- 第 1 天傍晚（S02b 完整链）→ 夜 ----
	await _evening()
	_smoke_check("A-Q3：安慰后夜里候选出现《它被骂了》", GameState.comforted and GameState.memory_candidates.has("M05"))
	_smoke_check("夜里界面已打开且有 3 条候选", _night_memory.visible and GameState.memory_candidates.size() == 3)
	# 留 M01 → 改留 M03 → 撤回 → 再留 M01（覆盖「留存/改选/撤回」语义）→ 睡。
	_night_memory.keep("M01")
	_night_memory.keep("M03")
	_night_memory.revoke()
	_smoke_check("夜间撤回：pending 回到进夜初值（空槽）", _night_memory.get_pending() == "")
	_night_memory.keep("M01")
	_night_memory.confirm()
	# confirm → night_confirmed → restart → 黑屏快速 → 早上 → 白天。
	_smoke_check("A-Q2 前置：留了 M01《水会回家》", GameState.kept_id == "M01")
	var to_day1: bool = await _wait_stage(Stage.DAY)
	_smoke_check("restart 黑屏过渡后回到白天", to_day1)
	_smoke_check("restart 后：第 2 天、电量回满、家光保留", GameState.day_number() == 2 and GameState.energy == 8 and GameState.jg == 6)

	# A-Q4 前半：第 2 天便条 1 张。
	_notes_browser.open()
	_smoke_check("A-Q4 前半：便条堆 1 张", _notes_browser.get_note_count() == 1)
	_notes_browser.closed.emit()

	# ---- 第 2 天白天：T01 用水（渗漏段加价）→ T04 回水（留 M01 → 免电，A-Q2）----
	await get_tree().process_frame
	_do_task("T01")
	_smoke_check("第 2 天 T01：湿脚印加价后耗电 3（2+1）", GameState.energy == 5 and GameState.pending_water == 1)
	var e_before := GameState.energy
	_do_task("T04")
	_smoke_check("A-Q2：留 M01 后回水不扣电（%d→%d）" % [e_before, GameState.energy], GameState.energy == e_before)
	_smoke_check("家光结算：第 1 天 6 + 第 2 天 T01/T04 各 +2 = 10", GameState.jg == 10)
	_smoke_check("回水后：净水 2 / 待回收 0（守恒）", GameState.clean_water == 2 and GameState.pending_water == 0)
	_smoke_check("water_returned 已置位（湿脚印解除）", GameState.water_returned and not GameState.has_wet_footprints())

	# ---- 第 2 天傍晚（简短版）→ 夜 → 反转 → 破局线 ----
	# 翻冰箱便条（A-Q4 + 破局领悟：M05 重新进候选）。
	_on_object_clicked("fridge")
	await get_tree().process_frame
	_notes_browser.closed.emit()
	_smoke_check("翻便条领悟：M05 重新进候选", GameState.memory_candidates.has("M05"))
	await _evening()
	# 夜里改留 M05《它被骂了》（A-Q5：次日触发「你还记得」）→ can_proceed → S03。
	_night_memory.keep("M05")
	_smoke_check("夜间改选：pending 从 M01 改到 M05", _night_memory.get_pending() == "M05")
	_night_memory.confirm()
	_smoke_check("A-Q5：留了 M05《它被骂了》", GameState.kept_id == "M05")
	# S03 播到「翻便条」处等玩家合上冰箱门——冒烟替玩家关。
	await get_tree().process_frame
	await get_tree().process_frame
	_notes_browser.closed.emit()
	# S03 完 → 破局待播 → restart → 第 3 天白天。
	var to_day3: bool = await _wait_stage(Stage.DAY)
	_smoke_check("S03 反转后 restart 进入第 3 天", to_day3 and GameState.can_proceed_act1())

	# ---- 第 3 天傍晚：S04 破局（念念带记忆主动开口）→ 第一幕真结局 ----
	await _evening()
	var to_end: bool = await _wait_stage(Stage.ACT1_END)
	_smoke_check("A-Q5：次日 S04 破局 → 第一幕真结局", to_end and GameState.kept_id == "M05")
	_smoke_check("A-Q4：便条 2 张、日期 1→2 递增", GameState.notes.size() == 2
		and int(GameState.notes[0].get("date", 0)) == 1 and int(GameState.notes[1].get("date", 0)) == 2)

	# ---- A-Q8：退出重进（家光/便条/槽不丢）----
	var jg_before := GameState.jg
	var notes_before: int = GameState.notes.size()
	var kept_before := GameState.kept_id
	GameState.save_game()
	GameState.jg = 999
	GameState.notes = []
	GameState.kept_id = ""
	GameState.load_game()
	_smoke_check("A-Q8：重进后家光/便条/记忆槽不丢",
		GameState.jg == jg_before and GameState.notes.size() == notes_before and GameState.kept_id == kept_before)

	# ---- 汇总 ----
	print("===== UI 冒烟：%d 通过 / %d 失败 =====" % [_smoke_passed, _smoke_failed])
	get_tree().quit(1 if _smoke_failed > 0 else 0)


func _smoke_check(name: String, cond: bool) -> void:
	if cond:
		_smoke_passed += 1
		print("  PASS  ", name)
	else:
		_smoke_failed += 1
		print("  FAIL  ", name)


## 轮询等待状态机到达目标阶段（超时返回 false）。
func _wait_stage(target: int, timeout: float = 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while _stage != target:
		if Time.get_ticks_msec() - t0 > int(timeout * 1000):
			return false
		await get_tree().process_frame
	return true
