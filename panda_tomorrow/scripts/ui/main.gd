extends Node2D
## 第一幕核心测试：int 能量 + keep_cost + 派工 + 进度 + 存档序列化 + 重启 + 内容/换皮

var failures: int = 0


func check(label: String, condition: bool) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		failures += 1
		print("[FAIL] ", label)


func _ready() -> void:
	print("=== 第一幕核心测试 ===")

	# --- 初始 ---
	GameState.reset_for_new_game()
	check("初始 energy = 100", GameState.energy == 100)
	check("初始 jg = 0", GameState.jg == 0)
	check("初始 notes 空", GameState.notes.is_empty())
	check("初始 can_proceed = false", not GameState.can_proceed_act1())

	# --- spend_energy ---
	check("spend 30 成功", GameState.spend_energy(30))
	check("energy = 70", GameState.energy == 70)
	check("spend 80 失败", not GameState.spend_energy(80))
	check("失败不扣 energy = 70", GameState.energy == 70)

	# --- keep_memory ---
	GameState.reset_for_new_game()
	GameState.add_memory_candidate("M05")
	check("留 M05 成功", GameState.keep_memory("M05"))
	check("留 M05 后 energy = 95", GameState.energy == 95)
	check("has_kept(M05)", GameState.has_kept_memory("M05"))
	GameState.add_memory_candidate("M03")
	check("capacity=1 拒绝第二条", not GameState.keep_memory("M03"))

	# --- submit_task ---
	GameState.reset_for_new_game()
	check("未解锁 T02 被拒", not GameState.submit_task("T02"))
	GameState.unlock_task("T01")
	GameState.unlock_task("T02")
	GameState.unlock_task("T03")
	GameState.unlock_task("T04")
	check("T01 提交成功", GameState.submit_task("T01"))
	check("T01 后 energy = 80", GameState.energy == 80)
	check("T01 后 jg = 2", GameState.jg == 2)
	check("T01 重复提交被拒", not GameState.submit_task("T01"))
	check("T02 提交成功", GameState.submit_task("T02"))
	check("T03 提交成功", GameState.submit_task("T03"))
	check("T04 提交成功", GameState.submit_task("T04"))
	check("四任务后 energy = 35", GameState.energy == 35)
	check("四任务后 jg = 8", GameState.jg == 8)
	check("T04 设 leak_fixed", GameState.leak_fixed)
	check("T04 解锁 M01 候选", GameState.memory_candidates.has("M01"))

	# --- can_proceed_act1 ---
	check("缺 leak_found 时 false", not GameState.can_proceed_act1())
	GameState.leak_found = true
	GameState.set_lamp_name("不加班灯")
	GameState.comfort_panda()
	check("四条件齐 = true", GameState.can_proceed_act1())

	# --- 存档序列化 ---
	var snap: Dictionary = GameState.serialize()
	GameState.reset_for_new_game()
	check("重置后 jg = 0", GameState.jg == 0)
	GameState.deserialize(snap)
	check("恢复 jg = 8", GameState.jg == 8)
	check("恢复 energy = 35", GameState.energy == 35)
	check("恢复 leak_fixed", GameState.leak_fixed)
	check("恢复 lamp_name", GameState.lamp_name == "不加班灯")

	# --- 便条与重启 ---
	GameState.reset_for_new_game()
	GameState.add_memory_candidate("M01")
	check("留 M01 成功", GameState.keep_memory("M01"))
	GameState.add_daily_note()
	check("便条 +1", GameState.notes.size() == 1)
	GameState.start_new_day()
	check("重启 day = 2", GameState.day_count == 2)
	check("重启便条 = 2", GameState.notes.size() == 2)
	check("重启后 kept 保留 M01", GameState.has_kept_memory("M01"))
	check("重启后候选清空", GameState.memory_candidates.is_empty())
	check("重启后 comforted 清空", not GameState.comforted_today)

	# --- 内容 / 换皮（C） ---
	var ids: Array = Dialogue.get_panda_ids()
	check("加载 4 只熊猫", ids.size() == 4)
	var need: Array = ["name", "gender", "job", "subspecies", "color", "personality", "late_return", "grievance", "self_doubt", "comfort_c", "note_carrier", "next_day_react"]
	var fields_ok: bool = true
	for pid in ids:
		var prof: Dictionary = Dialogue.get_profile(pid)
		for f in need:
			if str(prof.get(f, "")) == "":
				fields_ok = false
	check("4 只熊猫字段齐全", fields_ok)

	var s00: Dictionary = Dialogue.resolve_scene("S00", "huahua")
	var name_ok: bool = false
	for ln: Dictionary in s00.get("lines", []):
		if str(ln.get("speaker", "")) == "小咪" and "花花" in str(ln.get("text", "")):
			name_ok = true
	check("S00 替换熊猫名=花花", name_ok)

	var comforts: Array = []
	for pid in ids:
		var s02b: Dictionary = Dialogue.resolve_scene("S02b", pid)
		for c: Dictionary in s02b.get("comfort_choices", []):
			if str(c.get("id", "")) == "C":
				comforts.append(str(c.get("text", "")))
	check("4 只熊猫 comfort_c 各异", comforts.size() == 4 and comforts[0] != comforts[1] and comforts[1] != comforts[2] and comforts[2] != comforts[3])

	var s03: Dictionary = Dialogue.resolve_scene("S03", "keke")
	var note_ok: bool = false
	for ln: Dictionary in s03.get("lines", []):
		if "备课本" in str(ln.get("text", "")):
			note_ok = true
	check("S03 替换便条载体=备课本", note_ok)

	# --- 汇总 ---
	print("")
	if failures == 0:
		print("=== 全部通过 ===")
		get_tree().quit(0)
	else:
		print("=== 失败 ", failures, " 项 ===")
		get_tree().quit(1)
