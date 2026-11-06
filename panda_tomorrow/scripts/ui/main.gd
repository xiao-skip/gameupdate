extends Node2D
## 临时验收入口（A 维护到 B 接手为止，B 可整体替换成正式 UI；
## A 的验收测试在 scripts/core/test_act1.gd，属于 A 的独占文件）。
## 跑三件事：
##   1. 打印 GameState 初值（分工文档第 2 节；如显示非初值 = 读到了存档）
##   2. 跑 4.2 A 任务 + 验收清单的测试套件
##   3. data/ 三个 JSON 解析检查
## 全部通过退出码 0，有失败退出码 1，方便 headless 自动化。

const TestAct1 := preload("res://scripts/core/test_act1.gd")

func _ready() -> void:
	print("=== [1] GameState 初值（分工文档第 2 节） ===")
	print("panda_name = ", GameState.panda_name)
	print("panda_preset = ", GameState.panda_preset)
	print("phase = ", GameState.phase)
	print("leak_marked = ", GameState.leak_marked)
	print("lamp_named = ", GameState.lamp_named)
	print("comforted = ", GameState.comforted)
	print("water_returned = ", GameState.water_returned)
	print("jg = ", GameState.jg)
	print("notes = ", GameState.notes)
	print("device_flags = ", GameState.device_flags)
	print("jg_balance = ", GameState.jg_balance)
	print("collectibles = ", GameState.collectibles)
	print("fatigue = ", GameState.fatigue)
	print("last_comfort_choice = ", GameState.last_comfort_choice)
	print("energy = ", GameState.energy)
	print("clean_water = ", GameState.clean_water, " / pending_water = ", GameState.pending_water)
	print("daily_done = ", GameState.daily_done)
	print("memory_candidates = ", GameState.memory_candidates)
	print("weather = ", GameState.weather)
	print("kept_id = ", GameState.kept_id)

	print("\n=== [2] 分工文档 4.2（A 的任务）验收测试 ===")
	var t = TestAct1.new()
	var r: Dictionary = t.run()

	print("\n=== [3] data/ JSON 解析 ===")
	_check_json("res://data/tasks.json")
	_check_json("res://data/memories.json")
	_check_json("res://data/script.json")

	var total: int = int(r["passed"]) + int(r["failed"])
	print("\n===== 验收汇总：", r["passed"], " / ", total, " 项通过 =====")
	if int(r["failed"]) > 0:
		print("失败项：")
		for item in r["failures"]:
			print("  - ", item)
		get_tree().quit(1)
	else:
		print("全部通过，退出")
		get_tree().quit(0)


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
