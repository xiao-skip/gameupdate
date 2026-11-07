extends Node2D
## GameState + ScriptRunner 联合验收脚本（替换原 v0 自检）。
##   Part A：GameState 状态逻辑（A-Q1 ~ A-Q8 + 数据层 + 换皮）
##   Part B：ScriptRunner 剧本推进（S00 → S01 → S02b → S02 → S03 全流程）
##   Part C：两天的环 + 破环路径（端到端）
##
## 跑法：godot --headless --path panda_tomorrow
## 打印完自动退出；退出码 0 = 全通过，1 = 有失败。
## 注意：本文件是临时验收用，正式 UI 进来后可直接删掉换实现。

const ScriptRunnerScript = preload("res://scripts/content/script_runner.gd")

var _pass := 0
var _fail := 0
var _fail_msgs: Array[String] = []


func _ready() -> void:
	print("========== 联合验收（GameState + ScriptRunner） ==========")

	_case_data_layer()
	_case_naming_and_format()
	_case_aq1_dispatch_energy()
	_case_aq2_fix_leak()
	_case_aq3_comfort_candidate()
	_case_aq4_notes()
	_case_aq5_keep_m05_restart()
	_case_aq6_empty_slot_restart()
	_case_aq7_energy_exact_zero()
	_case_aq8_save_load()
	_case_loop_never_breaks_day1()
	_case_panda_swapping()

	_case_runner_s00()
	_case_runner_s01()
	_case_runner_s02b()
	_case_runner_s02()
	_case_runner_s03()
	_case_runner_full_playthrough()
	_case_runner_two_day_loop()
	_case_runner_all_pandas_full_play()

	print("")
	print("========== 结果 ==========")
	print("通过 %d 项，失败 %d 项" % [_pass, _fail])
	for m in _fail_msgs:
		print("  [FAIL] ", m)

	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
		print("已清理测试存档")

	print("========== 验收结束 ==========")
	get_tree().quit(0 if _fail == 0 else 1)


# ============================================================
# 断言工具
# ============================================================

func _ok(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		_pass += 1
		print("  [OK]   ", label, ("  " + detail) if detail != "" else "")
	else:
		_fail += 1
		_fail_msgs.append(label + ("  " + detail if detail != "" else ""))
		print("  [FAIL] ", label, ("  " + detail) if detail != "" else "")


func _eq(a: Variant, b: Variant, label: String) -> void:
	_ok(str(a) == str(b), label, "实际=%s 期望=%s" % [str(a), str(b)])


func _fresh() -> void:
	GameState.reset_for_new_game()
	GameState.set_names("huahua", "花花", "念念")


func _new_runner() -> Node:
	var r := ScriptRunnerScript.new()
	add_child(r)
	return r


## 把当前场景一口气推到下一个 choice 或结束，返回播出的节点列表。
func _play_to_choice(runner: Node) -> Array:
	var log: Array = []
	var guard := 0
	while guard < 200:
		guard += 1
		var node: Dictionary = runner.current()
		if node.get("type", "") == "choice":
			break
		if runner.is_finished():
			break
		log.append(node)
		if not runner.advance():
			break
	return log


## 把整场推完（遇到 choice 自动选 first_pick 指定的下标，默认 0）。
func _play_whole(runner: Node, picks: Array = []) -> Array:
	var log: Array = []
	var pick_i := 0
	var guard := 0
	while guard < 500:
		guard += 1
		if runner.is_finished():
			break
		var node: Dictionary = runner.current()
		log.append(node)
		if node.get("type", "") == "choice":
			var pick: int = 0
			if pick_i < picks.size():
				pick = picks[pick_i]
			pick_i += 1
			runner.choose(pick)
			continue
		if not runner.advance():
			break
	return log


# ============================================================
# Part A — GameState 状态逻辑
# ============================================================

func _case_data_layer() -> void:
	print("\n[A0] 数据层：四份 JSON 可读、索引齐全")
	_fresh()

	_ok(GameState.list_panda_presets().size() == 4, "pandas.json 四只熊猫",
		"实际=" + str(GameState.list_panda_presets().size()))

	for pid in ["huahua", "zhuangzhuang", "lingling", "keke"]:
		GameState.panda_preset = pid
		var prof: Dictionary = GameState.get_panda_profile()
		_ok(not prof.is_empty() and prof.has("mirror_line"), "预设字段完整: " + pid)

	GameState.panda_preset = "huahua"
	_eq(GameState.get_memory_cost("M01"), 2.0, "M01 耗电 = 2")
	_eq(GameState.get_memory_cost("M03"), 1.0, "M03 耗电 = 1")
	_eq(GameState.get_memory_cost("M05"), 3.0, "M05 耗电 = 3（情感最贵）")

	var sc := GameState.get_scene("S02b")
	_ok(not sc.is_empty(), "能按 phase 取到 S02b 场景")
	_ok(sc.get("branches", {}).has("confession"), "S02b 有诉苦分支 confession")

	var scenes_phases: Array = []
	for s in GameState.get_script_data().get("scenes", []):
		scenes_phases.append(s.get("phase", ""))
	_eq(str(scenes_phases), str(["S00", "S01", "S02b", "S02", "S03"]), "五场齐全且顺序正确")


func _case_naming_and_format() -> void:
	print("\n[A1] 命名与占位符替换")
	_fresh()
	_eq(GameState.panda_name, "花花", "panda_name 写入")
	_eq(GameState.controller_name, "念念", "controller_name 写入")
	_eq(GameState.panda_preset, "huahua", "panda_preset 写入")

	var raw := "〔熊猫名〕，我是〔总控名〕。{panda.mirror_line}"
	var out := GameState.format_text(raw)
	_ok(not out.contains("〔"), "〔〕占位已全部替换", out)
	_ok(not out.contains("{panda."), "{panda.x} 占位已全部替换", out)
	_ok(out.contains("花花") and out.contains("念念"), "替换内容正确", out)
	_ok(out.contains("第七稿"), "花花的镜像句正确注入", out)

	GameState.set_names("keke", "可可", "")
	var out2 := GameState.format_text("{panda.mirror_line}")
	_ok(out2.contains("蹲下来"), "换皮生效：可可的镜像句", out2)
	_eq(GameState.controller_name, "念念", "空 controller 不覆盖原名")


func _case_aq1_dispatch_energy() -> void:
	print("\n[A-Q1] 派工 打扫2+生活2+微课2+回水1 → 耗电 7，剩 1")
	_fresh()
	_eq(GameState.energy, 8.0, "初始电量 8")

	_ok(GameState.submit_task("T01"), "派工 T01 打扫成功")
	_ok(GameState.submit_task("T02"), "派工 T02 生活成功")
	_ok(GameState.submit_task("T03"), "派工 T03 微课成功")
	_eq(GameState.energy, 2.0, "T01+T02+T03 后剩 2")
	_eq(GameState.phase, "S01", "T01+T02 完成 → 自动推进 S01")

	GameState.unlock_task("T04")
	_ok(GameState.submit_task("T04"), "派工 T04 回水成功")
	_eq(GameState.energy, 1.0, "全做后剩 1 电")
	_eq(GameState.energy_spent_today, 7.0, "今日累计耗电 7")
	_ok(not GameState.submit_task("T01"), "重复派工被拒绝")


func _case_aq2_fix_leak() -> void:
	print("\n[A-Q2] 回水完成后生成 M01 候选")
	_fresh()
	GameState.advance_phase("S01")
	GameState.fix_leak()

	_eq(GameState.leak_fixed, true, "leak_fixed = true")
	_eq(GameState.leak_found, true, "leak_found = true")
	_ok(GameState.memory_candidates.has("M01"), "M01 进入候选", str(GameState.memory_candidates))
	_ok(not GameState.has_kept_memory("M01"), "仅候选、尚未留存")

	GameState.fix_leak()
	_eq(GameState.memory_candidates.count("M01"), 1, "重复回水不重复生成候选")


func _case_aq3_comfort_candidate() -> void:
	print("\n[A-Q3] 安慰熊猫后候选出现 M05《它今天受委屈了》")
	_fresh()
	GameState.advance_phase("S02b")
	GameState.set_panda_low()
	_eq(GameState.panda_mood, "low", "回家时 mood = low")

	GameState.comfort_panda()
	_eq(GameState.comforted_today, true, "comforted_today = true")
	_eq(GameState.panda_mood, "calm", "安慰后 mood = calm")
	_ok(GameState.memory_candidates.has("M05"), "M05 进入候选")
	_ok(GameState.has_grievance_candidate(), "has_grievance_candidate = true")

	var m05 := GameState.get_memory_def("M05")
	_eq(m05.get("title", ""), "它今天受委屈了", "M05 标题已改名（不再是「被骂了」）")

	var line := GameState.format_text(str(m05.get("desc", "")))
	_ok(line.contains("改了七稿"), "M05 描述按熊猫职业换皮（花花的诉苦）", line.substr(0, 24) + "…")
	_ok(not line.contains("{panda."), "M05 描述占位已替换", line.substr(0, 24) + "…")

	GameState.set_names("lingling", "灵灵", "")
	var m05_ling := GameState.format_text(str(GameState.get_memory_def("M05").get("desc", "")))
	_ok(m05_ling.contains("法条") or m05_ling.contains("案子"), "换灵灵后 M05 描述随之换皮",
		m05_ling.substr(0, 24) + "…")


func _case_aq4_notes() -> void:
	print("\n[A-Q4] 树洞角落便条累积")
	_fresh()
	# 第一幕只演一天，但玩家早已被绑定、已经循环过很多天：
	# 开场时树洞角落不是空的，而是一沓旧便条，S03 才有东西可翻。
	var init_notes := GameState.get_initial_note_count()
	_ok(init_notes >= 3, "开场已有旧便条（不是空树洞），S03 才有「一沓」可翻",
		"initial_count = %d" % init_notes)
	_eq(GameState.note_count, init_notes, "初始 note_count = daily_note.initial_count")

	GameState.add_daily_note()
	GameState.add_daily_note()
	GameState.add_daily_note()
	_eq(GameState.note_count, init_notes + 3, "加 3 张后 note_count = 初值 + 3")

	_eq(GameState.get_note_date_label(0), "今天", "最新一张 = 今天")
	_eq(GameState.get_note_date_label(1), "昨天", "第二张 = 昨天")
	_eq(GameState.get_note_date_label(2), "前天", "第三张 = 前天")
	_eq(GameState.get_note_date_label(5), "更早", "更早的 = 更早")

	var t0 := GameState.get_note_text(0)
	var t1 := GameState.get_note_text(1)
	_ok(t0 != t1, "今天与旧便条文案不同（几乎一样但可辨）")
	_ok(t0.contains("委屈"), "便条内容已换为「委屈」版", t0)
	_ok(not t0.contains("老板"), "旧版「老板/信」已清除", t0)

	var carrier: Variant = GameState.get_panda_profile().get("note_carrier", "")
	_eq(carrier, "废稿背面", "花花便条载体 = 废稿背面")


func _case_aq5_keep_m05_restart() -> void:
	print("\n[A-Q5] 留 M05 重启 → 次日走「记得」分支")
	_fresh()
	GameState.advance_phase("S02b")
	GameState.comfort_panda()

	_ok(GameState.keep_memory("M05"), "电量 8 足够留 M05（3 电）")
	_ok(GameState.has_kept_memory("M05"), "M05 已留在沉淀")
	_eq(GameState.energy, 5.0, "留 M05 后剩 5 电")
	_ok(not GameState.memory_candidates.has("M05"), "候选里已移除 M05")

	var before := GameState.note_count
	GameState.start_new_day()
	_eq(GameState.day_count, 2, "day_count = 2")
	_eq(GameState.note_count, before + 1, "便条 +1")
	_ok(GameState.has_kept_memory("M05"), "失忆后 M05 仍保留")
	_eq(GameState.comforted_today, false, "comforted_today 已清空")
	_eq(GameState.panda_mood, "normal", "panda_mood 回落 normal")
	_eq(GameState.energy, 8.0, "早晨回满 8 电")
	_eq(GameState.memory_candidates.size(), 0, "候选已清空")
	_eq(GameState.panda_fatigue, 0, "留了记忆 → 疲惫不累加")

	var nd := GameState.get_next_day_line()
	_eq(nd.get("kept"), true, "next_day 走 kept 分支")
	_ok(str(nd.get("line", "")).contains("记这个干嘛"), "花花换皮台词正确", str(nd.get("line", "")))


func _case_aq6_empty_slot_restart() -> void:
	print("\n[A-Q6] 空槽重启 → 仍能继续，且疲惫 +1")
	_fresh()
	GameState.advance_phase("S02b")
	GameState.comfort_panda()

	GameState.start_new_day()
	_eq(GameState.kept_memory_ids.size(), 0, "沉淀为空")
	_eq(GameState.phase, "S01", "回到 S01 入口（环的起点）")
	_eq(GameState.day_count, 2, "day_count 正常推进")
	_eq(GameState.panda_fatigue, 1, "没留记忆 → 疲惫 +1")

	var nd := GameState.get_next_day_line()
	_eq(nd.get("kept"), false, "next_day 走 not_kept 分支")
	_ok(not str(nd.get("line", "")).is_empty(), "没留也有台词", str(nd.get("line", "")))

	_ok(GameState.submit_task("T01"), "次日仍可派工")
	_ok(GameState.energy < 8.0, "次日派工正常扣电")


func _case_aq7_energy_exact_zero() -> void:
	print("\n[A-Q7] 电量恰好归零的边界")
	_fresh()

	_ok(GameState.spend_energy(8.0), "一次花光 8 电成功")
	_eq(GameState.energy, 0.0, "电量 = 0")
	_eq(GameState.energy_spent_today, 8.0, "累计耗电 8")

	_ok(not GameState.spend_energy(1.0), "电量不足时拒绝扣电")
	_eq(GameState.energy, 0.0, "拒绝后电量未被扣成负数")

	GameState.add_memory_candidate("M01")
	_ok(not GameState.keep_memory("M01"), "0 电留不下 M01")
	_ok(not GameState.has_kept_memory("M01"), "M01 未进沉淀")
	_eq(GameState.phase, "S00", "阶段未被电量归零影响")


func _case_aq8_save_load() -> void:
	print("\n[A-Q8] 存档 / 读档")
	_fresh()
	GameState.set_lamp_name("不加班灯")
	GameState.add_daily_note()
	GameState.advance_phase("S03")
	GameState.reveal_loop()
	GameState.keep_memory("M03")
	var saved_energy := GameState.energy
	var saved_notes := GameState.note_count

	_ok(GameState.has_kept_memory("M03"), "M03 已留存")
	_ok(not GameState.memory_candidates.has("M03"), "留存后已移出候选")
	_ok(GameState.save_game(), "存档成功")

	GameState.reset_for_new_game()
	_eq(GameState.kept_memory_ids.size(), 0, "reset 后沉淀已清空")

	_ok(GameState.load_game(), "读档成功")
	_eq(GameState.lamp_name, "不加班灯", "灯名恢复")
	_eq(GameState.stool_placed, true, "小板凳位置恢复")
	_eq(GameState.kept_memory_ids.size(), 1, "沉淀恢复")
	_eq(GameState.kept_memory_ids[0], "M03", "M03 恢复")
	_ok(not GameState.memory_candidates.has("M03"), "读档后候选与留存不自相矛盾")
	_eq(GameState.note_count, saved_notes, "便条数恢复")
	_eq(GameState.revealed_loop, true, "反转标记恢复")
	_eq(GameState.phase, "S03", "阶段恢复")
	_eq(GameState.energy, saved_energy, "电量恢复")
	_eq(GameState.panda_name, "花花", "熊猫名恢复")
	_eq(GameState.controller_name, "念念", "总控名恢复")

	# 损坏存档自愈
	GameState.kept_memory_ids = ["M99", "M03", "M05"]
	GameState.memory_candidates = ["M03", "M77"]
	GameState.energy = -5.0
	GameState.save_game()
	var ok2 := GameState.load_game()
	_ok(ok2, "损坏存档仍能读")
	_eq(GameState.kept_memory_ids.size(), 1, "超容量被截断到 1 条")
	_ok(not GameState.kept_memory_ids.has("M99"), "未知记忆 id 被剔除")
	_ok(not GameState.memory_candidates.has("M03"), "候选里的已留存记忆被剔除")
	_ok(not GameState.memory_candidates.has("M77"), "候选里的未知 id 被剔除")
	_eq(GameState.energy, 0.0, "负电量被夹到 0")


func _case_loop_never_breaks_day1() -> void:
	print("\n[A-设计] 第一天把电花在任务上 → 留不下 M05 → 自然进环")
	_fresh()
	GameState.advance_phase("S01")
	GameState.submit_task("T01")
	GameState.submit_task("T02")
	GameState.submit_task("T03")
	GameState.unlock_task("T04")
	GameState.submit_task("T04")
	_eq(GameState.energy, 1.0, "全派工后只剩 1 电")

	GameState.advance_phase("S02b")
	GameState.comfort_panda()
	_ok(GameState.has_grievance_candidate(), "M05 进入候选")

	var kept := GameState.keep_memory("M05")
	_ok(not kept, "1 电留不下 3 电的 M05 —— 环成立")
	_ok(not GameState.has_kept_memory("M05"), "M05 未进沉淀")

	GameState.start_new_day()
	_eq(GameState.panda_fatigue, 1, "次日疲惫 +1")
	_eq(GameState.get_next_day_line().get("kept"), false, "走「从头再说」分支")

	_fresh()
	GameState.advance_phase("S02b")
	GameState.comfort_panda()
	_ok(GameState.keep_memory("M05"), "第二天不派工 → 留得下 M05，破环路径成立")


func _case_panda_swapping() -> void:
	print("\n[A-换皮] 四只熊猫的镜像句与便条载体")
	var expect := {
		"huahua": ["第七稿", "废稿背面"],
		"zhuangzhuang": ["十圈", "训练计划表角落"],
		"lingling": ["庭上", "工整便签"],
		"keke": ["蹲下来", "备课本页脚"],
	}
	for pid in expect.keys():
		_fresh()
		GameState.set_names(pid, pid, "")
		var prof: Dictionary = GameState.get_panda_profile()
		var mirror := str(prof.get("mirror_line", ""))
		var carrier := str(prof.get("note_carrier", ""))
		_ok(mirror.contains(expect[pid][0]), "%s 镜像句正确" % pid, mirror)
		_eq(carrier, expect[pid][1], "%s 便条载体正确" % pid)
		_ok(not str(prof.get("late_home_action", "")).is_empty(), "%s 晚归动作非空" % pid)
		_ok(not str(prof.get("next_day_kept", "")).is_empty(), "%s 次日反应非空" % pid)


# ============================================================
# Part B — ScriptRunner 剧本推进
# ============================================================

func _case_runner_s00() -> void:
	print("\n[B-S00] 降临：12 个节点全部播出，无选项，收尾解锁任务")
	_fresh()
	var r := _new_runner()
	_ok(r.start_phase("S00"), "start_phase(S00) 成功")
	_eq(r.get_phase(), "S00", "当前阶段 = S00")

	var log := _play_whole(r)
	_ok(log.size() >= 12, "S00 播出台词 ≥ 12 条", "实际=" + str(log.size()))
	_ok(r.is_finished(), "S00 已结束")

	# 第一句应该是多吉的画外音
	var first: Dictionary = log[0]
	_eq(first.get("type", ""), "stage", "首节点是演出提示（黑屏数据流）")
	_ok(str(first.get("text", "")).contains("2046"), "首条提示含 2046 年份",
		str(first.get("text", "")).substr(0, 20))

	# 找到多吉那句
	var found_duoji := false
	var found_niannian := false
	for n in log:
		if n.get("type", "") == "say" and str(n.get("speaker", "")) == "多吉":
			found_duoji = true
		if n.get("type", "") == "say" and str(n.get("text", "")).contains("念念不忘"):
			found_niannian = true
	_ok(found_duoji, "多吉的绑定台词已播出")
	_ok(found_niannian, "熊猫命名台词「念念不忘」已播出")

	# 占位符必须已替换
	var leaks := 0
	for n in log:
		var txt := str(n.get("text", ""))
		if txt.contains("〔") or txt.contains("{panda."):
			leaks += 1
	_eq(leaks, 0, "S00 全部台词占位符已替换")

	# 收尾动作：T01-T03 应 available
	_eq(GameState.tasks_status.get("T01", ""), "available", "收尾解锁 T01")
	_eq(GameState.tasks_status.get("T02", ""), "available", "收尾解锁 T02")
	_eq(GameState.tasks_status.get("T03", ""), "available", "收尾解锁 T03")
	_eq(GameState.tasks_status.get("T04", ""), "locked", "T04 仍未解锁")
	_eq(GameState.phase, "S01", "自动推进到 S01")

	r.queue_free()


func _case_runner_s01() -> void:
	print("\n[B-S01] 湿脚印：2 + 2 选项，两个选项都通到回水")
	for pick in [0, 1]:
		_fresh()
		GameState.advance_phase("S01")
		var r := _new_runner()
		r.start_phase("S01")

		var log := _play_to_choice(r)
		_ok(log.size() >= 2, "S01 选项前播出 ≥2 条（pick=%d）" % pick, "实际=" + str(log.size()))
		_ok(r.is_awaiting_choice(), "S01 进入选项等待（pick=%d）" % pick)

		var cur: Dictionary = r.current()
		var opts: Array = cur.get("options", [])
		_eq(opts.size(), 2, "S01 有 2 个选项")
		_ok(str(opts[0].get("text", "")).contains("水从哪里来"), "选项 A 文案正确", str(opts[0].get("text", "")))
		_ok(str(opts[1].get("text", "")).contains("一起看看"), "选项 B 文案正确", str(opts[1].get("text", "")))

		var ok_choose: bool = r.choose(pick)
		_ok(ok_choose, "选择选项 %d 成功" % pick)

		# 两个选项都触发 fix_leak
		_eq(GameState.leak_fixed, true, "选项 %d 都通向回水（leak_fixed）" % pick)
		_ok(GameState.memory_candidates.has("M01"), "回水后 M01 进入候选（pick=%d）" % pick)

		# 选项后有收尾台词（多吉那句）
		var after := _play_to_choice(r)
		var has_duoji := false
		for n in after:
			if str(n.get("text", "")).contains("送到了别处"):
				has_duoji = true
		_ok(has_duoji, "after_option 里多吉的台词已播出（pick=%d）" % pick)

		_eq(GameState.phase, "S02b", "S01 结束自动推进到 S02b（pick=%d）" % pick)
		r.queue_free()


func _case_runner_s02b() -> void:
	print("\n[B-S02b] 它回家很晚：晚归 → 选项 → 诉苦 → 安慰三选项")
	_fresh()
	GameState.advance_phase("S02b")
	var r := _new_runner()
	r.start_phase("S02b")

	# 一进来 mood 应变 low
	_eq(GameState.panda_mood, "low", "场景入口自动设 mood = low")

	var log := _play_to_choice(r)
	_ok(log.size() >= 2, "S02b 选项前播出 ≥2 条", "实际=" + str(log.size()))

	# 晚归动作应已换皮注入
	var has_action := false
	for n in log:
		if str(n.get("text", "")).contains("摔门"):
			has_action = true
	_ok(has_action, "花花晚归动作已换皮注入", str(log[-1].get("text", "")))

	_ok(r.is_awaiting_choice(), "S02b 进入第一层选项")
	var opts: Array = r.current().get("options", [])
	_eq(opts.size(), 2, "第一层 2 个选项（你脸色不对 / 先坐下）")

	# 选 A，应进入 confession 分支
	_ok(r.choose(0), "选择「你脸色不对」")

	var branch_log := _play_to_choice(r)
	_ok(branch_log.size() >= 2, "分支台词 ≥2（诉苦 + 自我怀疑）", "实际=" + str(branch_log.size()))

	var has_grievance := false
	var has_doubt := false
	for n in branch_log:
		var t := str(n.get("text", ""))
		if t.contains("改了七稿") or t.contains("灵气"):
			has_grievance = true
		if t.contains("我是不是"):
			has_doubt = true
	_ok(has_grievance, "诉苦台词按花花换皮", "")
	_ok(has_doubt, "自我怀疑台词已播出")

	_ok(r.is_awaiting_choice(), "诉苦后进入安慰选项")
	var comfort: Array = r.current().get("options", [])
	_eq(comfort.size(), 3, "安慰有 3 个选项")
	_ok(str(comfort[2].get("text", "")).contains("第七稿"), "安慰 C 是花花的灵魂镜像句",
		str(comfort[2].get("text", "")))

	# 选 C
	_ok(r.choose(2), "选择灵魂镜像句 C")
	_eq(GameState.comforted_today, true, "安慰标记置位")
	_eq(GameState.panda_mood, "calm", "安慰后 mood = calm")
	_ok(GameState.memory_candidates.has("M05"), "M05 进入候选")

	var after := _play_to_choice(r)
	var has_thanks := false
	for n in after:
		if str(n.get("text", "")).contains("谢谢你听我说"):
			has_thanks = true
	_ok(has_thanks, "after_comfort 里熊猫道谢台词已播出")

	_eq(GameState.phase, "S02", "S02b 结束自动推进到 S02")
	r.queue_free()


func _case_runner_s02() -> void:
	print("\n[B-S02] 给灯命名：2 个选项，命名后生成 M03 + 小板凳")
	for pick in [0, 1]:
		_fresh()
		GameState.advance_phase("S02")
		var r := _new_runner()
		r.start_phase("S02")

		var log := _play_to_choice(r)
		_ok(log.size() >= 1, "S02 播出熊猫提问（pick=%d）" % pick, "实际=" + str(log.size()))
		_ok(str(log[0].get("text", "")).contains("也在上班"), "熊猫问「灯是不是也在上班」（pick=%d）" % pick)

		_ok(r.is_awaiting_choice(), "S02 进入选项（pick=%d）" % pick)
		var opts: Array = r.current().get("options", [])
		_eq(opts.size(), 2, "S02 有 2 个选项")

		_ok(r.choose(pick), "选择选项 %d" % pick)
		_eq(GameState.lamp_name, "不加班灯", "灯命名成功（pick=%d）" % pick)
		_eq(GameState.stool_placed, true, "小板凳搬到屏旁（pick=%d）" % pick)
		_ok(GameState.memory_candidates.has("M03"), "M03 进入候选（pick=%d）" % pick)

		var after := _play_to_choice(r)
		var has_line := false
		for n in after:
			if str(n.get("text", "")).contains("灯负责亮"):
				has_line = true
		_ok(has_line, "熊猫「灯负责亮，我们负责休息」已播出（pick=%d）" % pick)
		r.queue_free()


func _case_runner_s03() -> void:
	print("\n[B-S03] 反转：无选项，收尾揭示反转")
	_fresh()
	GameState.advance_phase("S03")
	var init_notes := GameState.get_initial_note_count()
	var r := _new_runner()
	r.start_phase("S03")

	_eq(r.get_phase(), "S03", "当前阶段 = S03")

	var prop: Dictionary = r.get_note_prop()
	_eq(prop.get("name", ""), "树洞角落", "道具名 = 树洞角落")
	_eq(prop.get("carrier", ""), "废稿背面", "花花便条载体 = 废稿背面")
	_ok(str(prop.get("constant_detail", "")).contains("同一盏小灯"), "不变细节正确", str(prop.get("constant_detail", "")))
	_eq(prop.get("total", 0), init_notes, "便条总张数取自 GameState（非空树洞）")
	_ok(init_notes >= 3, "S03 能翻出「一沓」而不是孤零零一张", "total = %d" % init_notes)

	var log := _play_whole(r)
	_ok(log.size() >= 2, "S03 播出 ≥2 条演出提示", "实际=" + str(log.size()))
	_ok(r.is_finished(), "S03 已结束")
	_eq(GameState.revealed_loop, true, "收尾揭示反转")

	# S03 是终点，不应再推进 phase
	_eq(GameState.phase, "S03", "S03 是终点，phase 不再前进")
	r.queue_free()


func _case_runner_full_playthrough() -> void:
	print("\n[B-全流程] S00 → S01 → S02b → S02 → S03 一口气走完")
	_fresh()

	var order: Array = []
	var r := _new_runner()
	r.phase_started.connect(func(p, t): order.append(p))
	r.script_finished.connect(func(): order.append("END"))

	# 逐场推进，每场选第一个选项
	for phase in ["S00", "S01", "S02b", "S02", "S03"]:
		if phase != "S00":
			r.start_phase(phase)
		else:
			r.start_phase("S00")
		_play_whole(r, [0, 0, 0, 0])

	_ok(str(order) == str(["S00", "S01", "S02b", "S02", "S03", "END"]),
		"五个阶段 + 结束信号顺序正确", str(order))

	# 走完后状态汇总
	_ok(GameState.revealed_loop, "全流程走完已揭示反转")
	_ok(not GameState.lamp_name.is_empty(), "灯已命名", GameState.lamp_name)
	_ok(GameState.comforted_today, "安慰过熊猫")
	_ok(not GameState.memory_candidates.is_empty(), "有记忆候选可留",
		str(GameState.memory_candidates))

	r.queue_free()


func _case_runner_two_day_loop() -> void:
	print("\n[B-两天的环] 第一天全派工留不下 M05，第二天省电留住 M05")
	_fresh()

	# -- 第一天：全派工 --
	GameState.phase = "S00"
	var r1 := _new_runner()
	r1.start_phase("S00")
	_play_whole(r1)
	r1.queue_free()

	for tid in ["T01", "T02", "T03"]:
		GameState.submit_task(tid)
	GameState.unlock_task("T04")
	GameState.submit_task("T04")
	_eq(GameState.energy, 1.0, "第一天全派工后剩 1 电")

	GameState.advance_phase("S02b")
	var r2 := _new_runner()
	r2.start_phase("S02b")
	_play_whole(r2, [0, 2])   # 选 A 引诉苦，再选 C 灵魂镜像句
	r2.queue_free()
	_eq(GameState.comforted_today, true, "第一天安慰过")
	_ok(GameState.has_grievance_candidate(), "第一天 M05 进入候选")

	var kept_day1 := GameState.keep_memory("M05")
	_ok(not kept_day1, "第一天 1 电留不下 M05 —— 环闭合")

	GameState.advance_phase("S03")
	var r3 := _new_runner()
	r3.start_phase("S03")
	_play_whole(r3)
	r3.queue_free()
	_ok(GameState.revealed_loop, "夜里翻便条，反转已揭示")

	# -- 隔夜 --
	var notes_day1 := GameState.note_count
	GameState.start_new_day()
	_eq(GameState.day_count, 2, "进入第 2 天")
	_eq(GameState.note_count, notes_day1 + 1, "便条多了一张")
	_eq(GameState.panda_fatigue, 1, "没留住 → 熊猫更累")
	_eq(GameState.energy, 8.0, "第 2 天满电")
	_eq(GameState.get_next_day_line().get("kept"), false, "第 2 天熊猫还是从头说起")

	# -- 第二天：不派工，直接留 M05 --
	var r4 := _new_runner()
	r4.start_phase("S02b")
	_play_whole(r4, [1, 2])   # 选 B 倒杯水，再选 C
	r4.queue_free()
	_ok(GameState.has_grievance_candidate(), "第 2 天 M05 再次进入候选")

	var kept_day2 := GameState.keep_memory("M05")
	_ok(kept_day2, "第 2 天省下电 → 留得住 M05，破环")
	_ok(GameState.has_kept_memory("M05"), "M05 已进沉淀")
	_eq(GameState.energy, 5.0, "留 M05 花 3 电，剩 5")

	GameState.start_new_day()
	_eq(GameState.panda_fatigue, 1, "留住记忆 → 疲惫不再累加（保持 1）")
	_eq(GameState.get_next_day_line().get("kept"), true, "第 3 天走「记得」分支")
	_ok(str(GameState.get_next_day_line().get("line", "")).contains("记这个干嘛"),
		"花花「……记这个干嘛。」已换皮", str(GameState.get_next_day_line().get("line", "")))


# ============================================================
# Part C — 四只熊猫全流程换皮回归
# ============================================================

func _case_runner_all_pandas_full_play() -> void:
	print("\n[B-四只熊猫] 每只都能走完整幕，换皮不破坏分支")
	var expect := {
		"huahua":     ["摔门", "改了七稿", "第七稿", "废稿背面"],
		"zhuangzhuang": ["护腕", "加罚", "十圈", "训练计划表角落"],
		"lingling":   ["围巾", "案子", "庭上", "工整便签"],
		"keke":       ["教案", "家长会", "蹲下来", "备课本页脚"],
	}

	for pid in expect.keys():
		_fresh()
		GameState.set_names(pid, pid, "")

		var collected: Array = []   # 本只熊猫播出的所有文本（台词+选项+道具）
		var r := _new_runner()
		r.line_advanced.connect(func(n):
			if n.has("text"):
				collected.append(str(n["text"]))
			# 选项文案也要收：灵魂镜像句在 choice.options 里
			for o in n.get("options", []):
				if o is Dictionary and o.has("text"):
					collected.append(str(o["text"]))
		)

		for phase in ["S00", "S01", "S02b", "S02", "S03"]:
			r.start_phase(phase)
			_play_whole(r, [0, 2, 0])   # 每场选 A，S02b 第二层选 C 灵魂镜像句

		# S03 的便条道具不走 line_advanced，单独取
		var prop: Dictionary = r.get_note_prop()
		collected.append(str(prop.get("name", "")))
		collected.append(str(prop.get("carrier", "")))
		collected.append(str(prop.get("constant_detail", "")))

		var blob := "\n".join(collected)

		for kw in expect[pid]:
			_ok(blob.contains(kw), "%s 流程内出现「%s」" % [pid, kw])

		# 反证：不该出现别的熊猫的专属词
		for other in expect.keys():
			if other == pid:
				continue
			var other_kw: String = expect[other][2]   # 灵魂镜像句的关键词
			_ok(not blob.contains(other_kw), "%s 流程内不含 %s 的镜像句「%s」" % [pid, other, other_kw])

		# 占位符泄漏检查
		_ok(not blob.contains("〔"), "%s 台词无〔〕残留" % pid)
		_ok(not blob.contains("{panda."), "%s 台词无 {panda.} 残留" % pid)

		# 状态一致性
		_ok(GameState.revealed_loop, "%s 走完后反转已揭示" % pid)
		_eq(GameState.lamp_name, "不加班灯", "%s 灯已命名" % pid)
		_ok(GameState.has_grievance_candidate(), "%s M05 在候选里" % pid)

		r.queue_free()
