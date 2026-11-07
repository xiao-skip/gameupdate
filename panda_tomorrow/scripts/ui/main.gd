extends Node2D
## GameState 逻辑验收脚本（替换原 v0 骨架自检）。
## 逐条跑分工文档的 A-Q1 ~ A-Q8，外加数据层与占位符替换的断言。
## 打印完自动退出，方便 headless 跑：godot --headless --path .
##
## 注意：本文件是**临时验收用**，正式 UI 进来后 B 可直接删掉换实现。

var _pass := 0
var _fail := 0
var _fail_msgs: Array[String] = []


func _ready() -> void:
	print("========== GameState 逻辑验收 ==========")
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

	print("")
	print("========== 结果 ==========")
	print("通过 %d 项，失败 %d 项" % [_pass, _fail])
	for m in _fail_msgs:
		print("  [FAIL] ", m)

	# 清掉验收过程产生的存档，免得下次跑游戏读到测试留下的脏数据
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


# ============================================================
# [0] 数据层
# ============================================================

func _case_data_layer() -> void:
	print("\n[0] 数据层：四份 JSON 可读、索引齐全")
	_fresh()

	_ok(GameState.list_panda_presets().size() == 4, "pandas.json 四只熊猫",
		"实际=" + str(GameState.list_panda_presets().size()))

	for pid in ["huahua", "zhuangzhuang", "lingling", "keke"]:
		var prof := {}
		GameState.panda_preset = pid
		prof = GameState.get_panda_profile()
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


# ============================================================
# [1] 命名与占位符替换
# ============================================================

func _case_naming_and_format() -> void:
	print("\n[1] 命名与占位符替换")
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

	# 换一只熊猫，同一句台词应换皮
	GameState.set_names("keke", "可可", "")
	var out2 := GameState.format_text("{panda.mirror_line}")
	_ok(out2.contains("蹲下来"), "换皮生效：可可的镜像句", out2)
	_eq(GameState.controller_name, "念念", "空 controller 不覆盖原名")


# ============================================================
# [A-Q1] 派工耗电：全做 = 7，剩 1，家光（这里只验电量）
# ============================================================

func _case_aq1_dispatch_energy() -> void:
	print("\n[A-Q1] 派工 打扫2+生活2+微课2+回水1 → 耗电 7，剩 1")
	_fresh()
	_eq(GameState.energy, 8.0, "初始电量 8")

	_ok(GameState.submit_task("T01"), "派工 T01 打扫成功")
	_ok(GameState.submit_task("T02"), "派工 T02 生活成功")
	_ok(GameState.submit_task("T03"), "派工 T03 微课成功")
	_eq(GameState.energy, 2.0, "T01+T02+T03 后剩 2")

	# S01 应由 T01+T02 完成自动触发
	_eq(GameState.phase, "S01", "T01+T02 完成 → 自动推进 S01")

	GameState.unlock_task("T04")
	_ok(GameState.submit_task("T04"), "派工 T04 回水成功")
	_eq(GameState.energy, 1.0, "全做后剩 1 电")
	_eq(GameState.energy_spent_today, 7.0, "今日累计耗电 7")

	_ok(not GameState.submit_task("T01"), "重复派工被拒绝")


# ============================================================
# [A-Q2] 留 M01 次日首次回水不扣电（此处验：回水本身不额外扣电）
# ============================================================

func _case_aq2_fix_leak() -> void:
	print("\n[A-Q2] 回水完成后生成 M01 候选")
	_fresh()
	GameState.advance_phase("S01")
	GameState.fix_leak()

	_eq(GameState.leak_fixed, true, "leak_fixed = true")
	_eq(GameState.leak_found, true, "leak_found = true")
	_ok(GameState.memory_candidates.has("M01"), "M01 进入候选", str(GameState.memory_candidates))
	_ok(not GameState.has_kept_memory("M01"), "仅候选、尚未留存")

	# 重复回水不重复生成
	GameState.fix_leak()
	_eq(GameState.memory_candidates.count("M01"), 1, "重复回水不重复生成候选")


# ============================================================
# [A-Q3] 安慰后夜里候选出现《它今天受委屈了》
# ============================================================

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

	# 安慰流程的换皮文案
	var line := GameState.format_text(str(m05.get("desc", "")))
	_ok(line.contains("改了七稿"), "M05 描述按熊猫职业换皮（花花的诉苦）", line.substr(0, 24) + "…")
	_ok(not line.contains("{panda."), "M05 描述占位已替换", line.substr(0, 24) + "…")

	# 换一只熊猫，同一条记忆的描述应该跟着换
	GameState.set_names("lingling", "灵灵", "")
	var m05_ling := GameState.format_text(str(GameState.get_memory_def("M05").get("desc", "")))
	_ok(m05_ling.contains("法条") or m05_ling.contains("案子"), "换灵灵后 M05 描述随之换皮",
		m05_ling.substr(0, 24) + "…")


# ============================================================
# [A-Q4] 翻便条：日期递增、内容几乎一样
# ============================================================

func _case_aq4_notes() -> void:
	print("\n[A-Q4] 树洞角落便条累积")
	_fresh()
	_eq(GameState.note_count, 0, "初始 0 张")

	GameState.add_daily_note()
	GameState.add_daily_note()
	GameState.add_daily_note()
	_eq(GameState.note_count, 3, "加 3 张后 note_count = 3")

	_eq(GameState.get_note_date_label(0), "今天", "最新一张 = 今天")
	_eq(GameState.get_note_date_label(1), "昨天", "第二张 = 昨天")
	_eq(GameState.get_note_date_label(2), "前天", "第三张 = 前天")
	_eq(GameState.get_note_date_label(5), "更早", "更早的 = 更早")

	var t0 := GameState.get_note_text(0)
	var t1 := GameState.get_note_text(1)
	_ok(t0 != t1, "今天与旧便条文案不同（几乎一样但可辨）")
	_ok(t0.contains("委屈"), "便条内容已换为「委屈」版", t0)
	_ok(not t0.contains("老板"), "旧版「老板/信」已清除", t0)

	# 便条载体按熊猫换皮
	var carrier: Variant = GameState.get_panda_profile().get("note_carrier", "")
	_eq(carrier, "废稿背面", "花花便条载体 = 废稿背面")


# ============================================================
# [A-Q5] 留 M05 重启 → 次日「你还记得」
# ============================================================

func _case_aq5_keep_m05_restart() -> void:
	print("\n[A-Q5] 留 M05 重启 → 次日走「记得」分支")
	_fresh()
	GameState.advance_phase("S02b")
	GameState.comfort_panda()

	var ok := GameState.keep_memory("M05")
	_ok(ok, "电量 8 足够留 M05（3 电）")
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


# ============================================================
# [A-Q6] 空槽重启 → 无记忆加成仍能继续
# ============================================================

func _case_aq6_empty_slot_restart() -> void:
	print("\n[A-Q6] 空槽重启 → 仍能继续，且疲惫 +1")
	_fresh()
	GameState.advance_phase("S02b")
	GameState.comfort_panda()
	# 故意不 keep

	GameState.start_new_day()
	_eq(GameState.kept_memory_ids.size(), 0, "沉淀为空")
	_eq(GameState.phase, "S01", "回到 S01 入口（环的起点）")
	_eq(GameState.day_count, 2, "day_count 正常推进")
	_eq(GameState.panda_fatigue, 1, "没留记忆 → 疲惫 +1")

	var nd := GameState.get_next_day_line()
	_eq(nd.get("kept"), false, "next_day 走 not_kept 分支")
	_ok(not str(nd.get("line", "")).is_empty(), "没留也有台词", str(nd.get("line", "")))

	# 第二天仍能正常派工
	_ok(GameState.submit_task("T01"), "次日仍可派工")
	_ok(GameState.energy < 8.0, "次日派工正常扣电")


# ============================================================
# [A-Q7] 电量恰好归零 → 只结算本次，成果保留
# ============================================================

func _case_aq7_energy_exact_zero() -> void:
	print("\n[A-Q7] 电量恰好归零的边界")
	_fresh()

	_ok(GameState.spend_energy(8.0), "一次花光 8 电成功")
	_eq(GameState.energy, 0.0, "电量 = 0")
	_eq(GameState.energy_spent_today, 8.0, "累计耗电 8")

	_ok(not GameState.spend_energy(1.0), "电量不足时拒绝扣电")
	_eq(GameState.energy, 0.0, "拒绝后电量未被扣成负数")

	# 连 2 电的 M01 也留不下——正是「留省电还是留名字」的取舍
	GameState.add_memory_candidate("M01")
	_ok(not GameState.keep_memory("M01"), "0 电留不下 M01")
	_ok(not GameState.has_kept_memory("M01"), "M01 未进沉淀")

	# 但已完成的成果（阶段/任务状态）不该被回滚
	_eq(GameState.phase, "S00", "阶段未被电量归零影响")


# ============================================================
# [A-Q8] 退出重进：不丢东西、不重复发奖
# ============================================================

func _case_aq8_save_load() -> void:
	print("\n[A-Q8] 存档 / 读档")
	_fresh()
	GameState.set_lamp_name("不加班灯")
	GameState.add_daily_note()
	GameState.advance_phase("S03")
	GameState.reveal_loop()
	GameState.keep_memory("M03")   # 走正规流程，顺带验证候选会从候选里移除
	var saved_energy := GameState.energy
	var saved_notes := GameState.note_count

	_ok(GameState.has_kept_memory("M03"), "M03 已留存")
	_ok(not GameState.memory_candidates.has("M03"), "留存后已移出候选")
	_ok(GameState.save_game(), "存档成功")

	# 打乱内存状态，模拟重开进程
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

	# 损坏存档自愈：手塞一个非法状态再读档
	GameState.kept_memory_ids = ["M99", "M03", "M05"]   # M99 不存在；超容量
	GameState.memory_candidates = ["M03", "M77"]        # M03 已留存；M77 不存在
	GameState.energy = -5.0
	GameState.save_game()
	var ok2 := GameState.load_game()
	_ok(ok2, "损坏存档仍能读")
	_eq(GameState.kept_memory_ids.size(), 1, "超容量被截断到 1 条")
	_ok(not GameState.kept_memory_ids.has("M99"), "未知记忆 id 被剔除")
	_ok(not GameState.memory_candidates.has("M03"), "候选里的已留存记忆被剔除")
	_ok(not GameState.memory_candidates.has("M77"), "候选里的未知 id 被剔除")
	_eq(GameState.energy, 0.0, "负电量被夹到 0")


# ============================================================
# [核心设计] 第一天几乎必然留不下 M05
# ============================================================

func _case_loop_never_breaks_day1() -> void:
	print("\n[设计] 第一天把电花在任务上 → 留不下 M05 → 自然进环")
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

	# 第二天省下派工、直接留 M05 → 可以破环
	_fresh()
	GameState.advance_phase("S02b")
	GameState.comfort_panda()
	_ok(GameState.keep_memory("M05"), "第二天不派工 → 留得下 M05，破环路径成立")


# ============================================================
# [换皮] 四只熊猫各自台词正确
# ============================================================

func _case_panda_swapping() -> void:
	print("\n[换皮] 四只熊猫的镜像句与便条载体")
	var expect := {
		"huahua": ["第七稿", "废稿背面"],
		"zhuangzhuang": ["十圈", "训练计划表角落"],
		"lingling": ["庭上", "工整便签"],
		"keke": ["蹲下来", "备课本页脚"],
	}
	for pid in expect.keys():
		_fresh()
		GameState.set_names(pid, pid, "")
		var prof := GameState.get_panda_profile()
		var mirror := str(prof.get("mirror_line", ""))
		var carrier := str(prof.get("note_carrier", ""))
		_ok(mirror.contains(expect[pid][0]), "%s 镜像句正确" % pid, mirror)
		_eq(carrier, expect[pid][1], "%s 便条载体正确" % pid)
		_ok(not str(prof.get("late_home_action", "")).is_empty(), "%s 晚归动作非空" % pid)
		_ok(not str(prof.get("next_day_kept", "")).is_empty(), "%s 次日反应非空" % pid)
