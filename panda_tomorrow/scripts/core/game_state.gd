extends Node
## ============================================================
## GameState —— 全局游戏状态（第一幕核心逻辑已实现）
##
## 《熊猫，明天见》第一幕「它不是第一次说」
## 能量模型：int 整数单位 + 数据驱动 keep_cost（留记忆 = 花电）+ 第一幕无水
## 通过 project.godot 的 [autoload] 注册为全局单例，任何脚本直接 GameState.xxx。
## ============================================================

# ---------- 基础进度 ----------
var day_count: int = 1
var phase: String = "S00"
var chapter: int = 1

# ---------- 玩家（总控 / 念念） ----------
var controller_name: String = "念念"
var energy: int = 100
var max_energy: int = 100
var memory_capacity: int = 1
var kept_memory_ids: Array = []
var memory_candidates: Array = []

# ---------- 熊猫 ----------
var panda_name: String = ""
var panda_mood: String = "normal"
var panda_fatigue: int = 0
var comforted_today: bool = false

# ---------- 家宅 ----------
var lamp_name: String = ""
var lamp_lit: bool = true
var stool_placed: bool = false
var leak_found: bool = false
var leak_fixed: bool = false
var heater_on: bool = false
var revealed_loop: bool = false

# ---------- 家光与便条 ----------
var jg: int = 0
var notes: Array = []

# ---------- 任务 ----------
var tasks_status: Dictionary = {}

# ---------- 预留（后续章节，第一幕不启用） ----------
var ghost_options_seen: Dictionary = {}
var home_ritual_count: int = 0
var chapter_flags: Dictionary = {}

# ---------- 缓存 ----------
var _memories_data: Dictionary = {}
var _tasks_data: Dictionary = {}
var _script_data: Dictionary = {}


func _get_memories() -> Dictionary:
	if _memories_data.is_empty():
		var text: String = FileAccess.get_file_as_string("res://data/memories.json")
		if not text.is_empty():
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_memories_data = parsed
	return _memories_data


func _get_tasks() -> Dictionary:
	if _tasks_data.is_empty():
		var text: String = FileAccess.get_file_as_string("res://data/tasks.json")
		if not text.is_empty():
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_tasks_data = parsed
	return _tasks_data


func _get_script() -> Dictionary:
	if _script_data.is_empty():
		var text: String = FileAccess.get_file_as_string("res://data/script.json")
		if not text.is_empty():
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				_script_data = parsed
	return _script_data


func _get_memory_keep_cost(memory_id: String) -> int:
	var data: Dictionary = _get_memories()
	var memories: Array = data.get("memories", [])
	for entry: Dictionary in memories:
		if entry.get("id", "") == memory_id:
			return int(entry.get("keep_cost", 0))
	return 0


func _get_task(task_id: String) -> Dictionary:
	var data: Dictionary = _get_tasks()
	var tasks: Array = data.get("tasks", [])
	for entry: Dictionary in tasks:
		if entry.get("id", "") == task_id:
			return entry
	return {}


func _get_daily_note_text() -> String:
	var data: Dictionary = _get_script()
	var note: Dictionary = data.get("daily_note", {})
	return str(note.get("template", "今天……又是这样。"))


# ---------- 命名 ----------
func set_names(panda: String, controller: String) -> void:
	panda_name = panda
	controller_name = controller


# ---------- 电 ----------
func spend_energy(amount: int) -> bool:
	if amount < 0:
		amount = 0
	if energy >= amount:
		energy -= amount
		return true
	return false


# ---------- 记忆 ----------
func add_memory_candidate(memory_id: String) -> void:
	if not memory_candidates.has(memory_id):
		memory_candidates.append(memory_id)


func keep_memory(memory_id: String) -> bool:
	if kept_memory_ids.size() >= memory_capacity:
		return false
	var cost: int = _get_memory_keep_cost(memory_id)
	if not spend_energy(cost):
		return false
	kept_memory_ids.append(memory_id)
	memory_candidates.erase(memory_id)
	return true


func has_kept_memory(memory_id: String) -> bool:
	return kept_memory_ids.has(memory_id)


# ---------- 任务 ----------
func unlock_task(task_id: String) -> void:
	tasks_status[task_id] = "available"


func complete_task(task_id: String) -> void:
	tasks_status[task_id] = "done"


## 派工：读 tasks.json 校验/扣电/记 done/发家光/解锁记忆。
func submit_task(task_id: String) -> bool:
	var task: Dictionary = _get_task(task_id)
	if task.is_empty():
		return false
	if tasks_status.get(task_id, "locked") != "available":
		return false
	var cost: int = int(task.get("energy", 0))
	if not spend_energy(cost):
		return false
	tasks_status[task_id] = "done"
	jg += int(task.get("jg", 0))
	var memory_id: String = str(task.get("memory", ""))
	if memory_id != "":
		add_memory_candidate(memory_id)
	if task_id == "T04":
		leak_fixed = true
	return true


# ---------- 剧情推进 ----------
func comfort_panda() -> void:
	comforted_today = true
	panda_mood = "calm"
	add_memory_candidate("M05")


func set_lamp_name(new_name: String) -> void:
	lamp_name = new_name
	stool_placed = true
	add_memory_candidate("M03")


func advance_phase(next_phase: String) -> void:
	phase = next_phase


func reveal_loop() -> void:
	revealed_loop = true


func can_proceed_act1() -> bool:
	return leak_found and leak_fixed and lamp_name != "" and comforted_today


# ---------- 便条与重启 ----------
func add_daily_note() -> void:
	notes.append({"day": day_count, "text": _get_daily_note_text()})


func start_new_day() -> void:
	day_count += 1
	memory_candidates = []
	comforted_today = false
	panda_mood = "normal"
	add_daily_note()
	phase = "S00"


# ---------- 存档（第一幕字段；预留字段暂不持久化） ----------
func serialize() -> Dictionary:
	return {
		"day_count": day_count,
		"phase": phase,
		"chapter": chapter,
		"controller_name": controller_name,
		"energy": energy,
		"kept_memory_ids": kept_memory_ids,
		"memory_candidates": memory_candidates,
		"panda_name": panda_name,
		"panda_mood": panda_mood,
		"comforted_today": comforted_today,
		"lamp_name": lamp_name,
		"stool_placed": stool_placed,
		"leak_found": leak_found,
		"leak_fixed": leak_fixed,
		"heater_on": heater_on,
		"revealed_loop": revealed_loop,
		"jg": jg,
		"notes": notes,
		"tasks_status": tasks_status,
	}


func deserialize(data: Dictionary) -> void:
	day_count = int(data.get("day_count", 1))
	phase = str(data.get("phase", "S00"))
	chapter = int(data.get("chapter", 1))
	controller_name = str(data.get("controller_name", "念念"))
	energy = int(data.get("energy", 100))
	kept_memory_ids = data.get("kept_memory_ids", [])
	memory_candidates = data.get("memory_candidates", [])
	panda_name = str(data.get("panda_name", ""))
	panda_mood = str(data.get("panda_mood", "normal"))
	comforted_today = bool(data.get("comforted_today", false))
	lamp_name = str(data.get("lamp_name", ""))
	stool_placed = bool(data.get("stool_placed", false))
	leak_found = bool(data.get("leak_found", false))
	leak_fixed = bool(data.get("leak_fixed", false))
	heater_on = bool(data.get("heater_on", false))
	revealed_loop = bool(data.get("revealed_loop", false))
	jg = int(data.get("jg", 0))
	notes = data.get("notes", [])
	tasks_status = data.get("tasks_status", {})


func save_game() -> bool:
	var f: FileAccess = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(serialize()))
	f.close()
	return true


func load_game() -> bool:
	var f: FileAccess = FileAccess.open("user://savegame.json", FileAccess.READ)
	if f == null:
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		deserialize(parsed)
		return true
	return false


func reset_for_new_game() -> void:
	day_count = 1
	phase = "S00"
	chapter = 1
	controller_name = "念念"
	energy = 100
	kept_memory_ids = []
	memory_candidates = []
	panda_name = ""
	panda_mood = "normal"
	panda_fatigue = 0
	comforted_today = false
	lamp_name = ""
	lamp_lit = true
	stool_placed = false
	leak_found = false
	leak_fixed = false
	heater_on = false
	revealed_loop = false
	jg = 0
	notes = []
	tasks_status = {}
