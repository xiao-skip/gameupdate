extends Node2D
## 第一幕核心测试：8电+3槽 + keep_cost + 派工 + 破局两步 + 存档序列化 + 重启 + 内容/换皮 + UI冒烟

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
	check("初始 energy = 8", GameState.energy == 8)
	check("初始 slots_left = 3", GameState.slots_left == 3)
	check("初始 jg = 0", GameState.jg == 0)
	check("初始 notes 空", GameState.notes.is_empty())
	check("初始 can_break = false", not GameState.can_break_loop())

	# --- spend_energy / spend_slot ---
	check("spend 3 成功", GameState.spend_energy(3))
	check("energy = 5", GameState.energy == 5)
	check("spend 6 失败", not GameState.spend_energy(6))
	check("失败不扣 energy = 5", GameState.energy == 5)
	check("spend_slot x3 全成功", GameState.spend_slot() and GameState.spend_slot() and GameState.spend_slot())
	check("slots_left = 0", GameState.slots_left == 0)
	check("spend_slot 第4次失败", not GameState.spend_slot())

	# --- keep / delete 记忆 ---
	GameState.reset_for_new_game()
	GameState.add_memory_candidate("M05")
	check("留 M05 成功", GameState.keep_memory("M05"))
	check("留 M05 后 energy = 5", GameState.energy == 5)
	check("has_kept(M05)", GameState.has_kept_memory("M05"))
	GameState.add_memory_candidate("M03")
	check("capacity=1 拒绝第二条", not GameState.keep_memory("M03"))
	GameState.delete_memory("M05")
	check("删除后 has_kept(M05)=false", not GameState.has_kept_memory("M05"))
	check("删除后 M05 回到候选", GameState.memory_candidates.has("M05"))
	check("留 M03 成功（换）", GameState.keep_memory("M03"))
	check("留 M03 后 energy = 4", GameState.energy == 4)

	# --- submit_task：耗电 + 耗槽 ---
	GameState.reset_for_new_game()
	check("未解锁 T02 被拒", not GameState.submit_task("T02"))
	GameState.unlock_task("T01")
	GameState.unlock_task("T02")
	GameState.unlock_task("T03")
	GameState.unlock_task("T04")
	check("T01 提交成功", GameState.submit_task("T01"))
	check("T01 后 energy = 6", GameState.energy == 6)
	check("T01 后 slots_left = 2", GameState.slots_left == 2)
	check("T01 后 jg = 2", GameState.jg == 2)
	check("T01 重复提交被拒", not GameState.submit_task("T01"))
	check("T02 提交成功", GameState.submit_task("T02"))
	check("T03 提交成功", GameState.submit_task("T03"))
	check("三任务后 energy = 2", GameState.energy == 2)
	check("三任务后 slots_left = 0", GameState.slots_left == 0)
	check("三任务后 jg = 6", GameState.jg == 6)
	check("T04 因没槽被拒", not GameState.submit_task("T04"))
	check("T04 被拒不扣电 energy = 2", GameState.energy == 2)

	# --- 破局两步 ---
	GameState.reset_for_new_game()
	GameState.comfort_panda()
	check("第1天安慰后 comforted=true", GameState.comforted_today)
	check("第1天 can_break=false（还没留 M05 过夜）", not GameState.can_break_loop())
	GameState.keep_memory("M05")
	check("第1天留了 M05 仍 can_break=false", not GameState.can_break_loop())
	GameState.start_new_day()
	check("过夜 day = 2", GameState.day_count == 2)
	check("过夜 m05_remembered_today = true", GameState.m05_remembered_today)
	check("过夜 comforted 清空", not GameState.comforted_today)
	check("过夜 can_break=false（还没再安慰）", not GameState.can_break_loop())
	GameState.comfort_panda()
	check("第2天再安慰 can_break=true", GameState.can_break_loop())

	# --- 存档序列化 ---
	var snap: Dictionary = GameState.serialize()
	GameState.reset_for_new_game()
	check("重置后 jg = 0", GameState.jg == 0)
	GameState.deserialize(snap)
	check("恢复 day = 2", GameState.day_count == 2)
	check("恢复 kept 含 M05", GameState.has_kept_memory("M05"))
	check("恢复 m05_remembered_today", GameState.m05_remembered_today)
	check("恢复 can_break=true", GameState.can_break_loop())

	# --- 便条与重启 ---
	GameState.reset_for_new_game()
	GameState.add_daily_note()
	check("便条 +1", GameState.notes.size() == 1)
	GameState.start_new_day()
	check("重启 day = 2", GameState.day_count == 2)
	check("重启便条 = 2", GameState.notes.size() == 2)
	check("重启 energy 回满 = 8", GameState.energy == 8)
	check("重启 slots 回满 = 3", GameState.slots_left == 3)
	check("重启候选清空", GameState.memory_candidates.is_empty())
	check("重启 comforted 清空", not GameState.comforted_today)

	# --- 内容 / 换皮 ---
	var ids: Array = Dialogue.get_panda_ids()
	check("加载 4 只熊猫", ids.size() == 4)
	var need: Array = ["name", "gender", "job", "subspecies", "color", "color_rgb", "personality", "late_return", "grievance", "self_doubt", "comfort_c", "note_carrier", "next_day_react"]
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

	# --- S04 破局场景 ---
	var s04: Dictionary = Dialogue.resolve_scene("S04", "huahua")
	var s04_name: bool = false
	var s04_comfort: bool = false
	for ln: Dictionary in s04.get("lines", []):
		var t: String = str(ln.get("text", ""))
		if "花花" in t:
			s04_name = true
		if "我看得见" in t:
			s04_comfort = true
	check("S04 替换 花花名 + comfort_c", s04_name and s04_comfort)

	# --- 选角字段 ---
	GameState.reset_for_new_game()
	GameState.select_panda("huahua", "花花")
	check("select_panda 写 selected_panda", GameState.selected_panda == "huahua")
	check("select_panda 写 panda_name", GameState.panda_name == "花花")
	var snap2: Dictionary = GameState.serialize()
	GameState.reset_for_new_game()
	GameState.deserialize(snap2)
	check("selected_panda 随存档恢复", GameState.selected_panda == "huahua")

	# --- UI 冒烟 ---
	var ui_scene: PackedScene = load("res://scenes/main.tscn")
	if ui_scene != null:
		var ui: Node = ui_scene.instantiate()
		add_child(ui)
		check("主界面脚本加载", ui != null and ui.has_method("_on_select_panda"))
		ui.queue_free()
	else:
		check("主界面脚本加载", false)

	# --- 汇总 ---
	print("")
	if failures == 0:
		print("=== 全部通过 ===")
		get_tree().quit(0)
	else:
		print("=== 失败 ", failures, " 项 ===")
		get_tree().quit(1)
