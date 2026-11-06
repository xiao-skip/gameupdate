extends Node2D
## 临时验收脚本（v0-skeleton 专用，后续由正式 UI 替换，B/C 可直接删改）。
## 只做三件事，对应第 0 步的验收标准：
##   1. GameState 能被全局访问 → 打印字段初值
##   2. 存根函数能调用不报错
##   3. data/ 三个 JSON 能被 JSON.parse_string 解析
## 打印完自动退出，方便 headless 跑验收。

func _ready() -> void:
	print("=== [1] GameState autoload 可全局访问，字段初值 ===")
	print("day_count = ", GameState.day_count)
	print("phase = ", GameState.phase)
	print("chapter = ", GameState.chapter)
	print("controller_name = ", GameState.controller_name)
	print("energy = ", GameState.energy, " / ", GameState.max_energy)
	print("memory_capacity = ", GameState.memory_capacity)
	print("kept_memory_ids = ", GameState.kept_memory_ids)
	print("memory_candidates = ", GameState.memory_candidates)
	print("panda_name = ", GameState.panda_name)
	print("panda_mood = ", GameState.panda_mood)
	print("panda_fatigue = ", GameState.panda_fatigue)
	print("comforted_today = ", GameState.comforted_today)
	print("lamp_name = ", GameState.lamp_name)
	print("lamp_lit = ", GameState.lamp_lit)
	print("stool_placed = ", GameState.stool_placed)
	print("leak_found = ", GameState.leak_found)
	print("leak_fixed = ", GameState.leak_fixed)
	print("heater_on = ", GameState.heater_on)
	print("note_count = ", GameState.note_count)
	print("revealed_loop = ", GameState.revealed_loop)
	print("tasks_status = ", GameState.tasks_status)
	print("ghost_options_seen = ", GameState.ghost_options_seen)
	print("home_ritual_count = ", GameState.home_ritual_count)
	print("chapter_flags = ", GameState.chapter_flags)

	print("=== [2] 存根函数调用不报错 ===")
	GameState.set_names("团团", "团圆")
	GameState.start_new_day()
	GameState.unlock_task("T01")
	GameState.complete_task("T01")
	GameState.add_memory_candidate("M05")
	print("keep_memory 返回默认值: ", GameState.keep_memory("M05"))
	print("has_kept_memory 返回默认值: ", GameState.has_kept_memory("M05"))
	print("spend_energy 返回默认值: ", GameState.spend_energy(5.0))
	GameState.comfort_panda()
	GameState.set_lamp_name("不加班灯")
	GameState.add_daily_note()
	GameState.advance_phase("S01")
	GameState.reveal_loop()
	print("save_game 返回默认值: ", GameState.save_game())
	print("load_game 返回默认值: ", GameState.load_game())
	GameState.reset_for_new_game()
	print("全部存根函数调用完毕，无报错")

	print("=== [3] data/ JSON 解析 ===")
	_check_json("res://data/tasks.json")
	_check_json("res://data/memories.json")
	_check_json("res://data/script.json")

	print("=== v0 骨架验收跑完，退出 ===")
	get_tree().quit()


func _check_json(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		print("[FAIL] 读取失败: ", path)
		return
	var data: Variant = JSON.parse_string(text)
	if data == null:
		print("[FAIL] JSON 解析失败: ", path)
		return
	var keys: int = 0
	if data is Dictionary and data.has("tasks"):
		keys = (data["tasks"] as Array).size()
	elif data is Dictionary and data.has("memories"):
		keys = (data["memories"] as Array).size()
	elif data is Dictionary and data.has("scenes"):
		keys = (data["scenes"] as Array).size()
	print("[OK] ", path, " 解析成功，条目数 = ", keys)
