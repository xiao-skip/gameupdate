extends Node
## ============================================================
## GameState —— 全局游戏状态（V2.0 四熊猫参数化 · 函数体已实现）
##
## 《熊猫，明天见》第一幕「它不是第一次说」
## 你（念念，来自 2046 年的超级人工智能 / 灵魂镜像）每天 0 点失忆，
## 只能把一件最重要的事写进「沉淀」。你照看的熊猫记得一切，一直在等你记住它。
## 这天它下班受了委屈，你安慰它、一起给灯起名；
## 夜里翻「树洞角落」那沓便条才发现——这不是它第一次受委屈，也不是它第一次告诉你。
##
## 角色：念念=玩家/灵魂镜像；多吉=教学与诊断；帕丁=生活；小咪=清洁；
##       熊猫=四选一（花花/壮壮/灵灵/可可，见 data/pandas.json）
##
## 通过 project.godot 的 [autoload] 注册为全局单例，任何脚本直接 GameState.xxx 访问。
##
## 设计原则：本类只管**状态**，不管演出。台词、选项、便条文案都在 data/*.json，
## 由 UI 层读取并替换占位符；本类只改状态位、发信号。加内容改 JSON，不改本文件。
##
## 数值（第一幕）：
##   日电量 8（早晨回满）／派工 T01-T03 各 2 电、T04 1 电（全做 = 7，剩 1）
##   留记忆 M01=2 / M03=1 / M05=3（情感最贵）
##   记忆槽 1 条／天 —— 所以第一天几乎必然留不下 M05，玩家自然进入「环」
## ============================================================

# ---------- 信号（UI 层监听，不轮询） ----------

## 某个状态字段发生变化，携带字段名。用于让 UI 局部刷新。
signal state_changed(field: String)
## 电量变化，携带当前值与上限。
signal energy_changed(current: float, max_value: float)
## 剧情阶段推进，携带新阶段 id。
signal phase_changed(next_phase: String)
## 任务状态变化，携带任务 id 与新状态。
signal task_changed(task_id: String, status: String)
## 记忆候选变化（新增候选 / 清空）。
signal memory_candidates_changed(candidates: Array)
## 一条记忆被留进沉淀。
signal memory_kept(memory_id: String)
## 新的一天开始（失忆已执行），携带新的 day_count。
signal new_day_started(day_count: int)
## 树洞角落多了一张便条，携带当前总张数。
signal note_added(note_count: int)
## 反转揭示。
signal loop_revealed()

# ---------- 常量 ----------

const PANDA_DATA_PATH := "res://data/pandas.json"
const MEMORY_DATA_PATH := "res://data/memories.json"
const TASK_DATA_PATH := "res://data/tasks.json"
const SCRIPT_DATA_PATH := "res://data/script.json"
const SAVE_PATH := "user://save_game.json"

## 第一幕阶段的规范顺序。start_new_day 用它决定「回到当日入口」是哪个阶段。
const ACT1_PHASES := ["S00", "S01", "S02b", "S02", "S03"]

## 每日满电。分工文档：电量 8/天，早晨回满。
const DAILY_ENERGY := 8.0

# ---------- 基础进度 ----------

## 当前天数。每日重启 +1，是整个游戏"环"的骨架。
var day_count: int = 1

## 当前剧情阶段，对应 data/script.json 里每条场景的 phase 字段。
## 第一幕顺序：S00 启用 → S01 湿脚印 → S02b 它回家很晚 → S02 给灯命名 → S03 反转
var phase: String = "S00"

## 当前章节号（第一幕 = 1；预留后续幕，手法见剧情第五节）。
var chapter: int = 1

# ---------- 总控（玩家） ----------

## 总控名。S00 命名后写入，运行时替换所有台词里的〔总控名〕。默认"念念"。
var controller_name: String = "念念"

## 剩余电量。主题是"留省电，还是留名字"——留住记忆要费电。
var energy: float = DAILY_ENERGY

## 电量上限（预留：后续章节可调）。
var max_energy: float = DAILY_ENERGY

## 每天能稳定留下的记忆条数。多吉在 S00 说："你的记忆每天 0 点刷新，只能把一件最重要的事写进沉淀。"
var memory_capacity: int = 1

## 跨天留住的记忆 id（"M01"/"M03"/"M05"…）。总控失忆后，这是仅存的东西。
var kept_memory_ids: Array = []

## 今夜的记忆候选（S02b 之后出现《它今天受委屈了》等）。夜里选记忆界面用，次日失忆时清空。
var memory_candidates: Array = []

# ---------- 熊猫 ----------

## 熊猫名。S00 选择熊猫并命名后写入，替换台词里的〔熊猫名〕。
var panda_name: String = ""

## 熊猫预设 id（"huahua"/"zhuangzhuang"/"lingling"/"keke"）。
## 四只共用同一场景骨架，运行时按此 id 去 data/pandas.json 取换皮参数，不产生独立分支。
var panda_preset: String = ""

## 熊猫情绪："normal"（平常）/"low"（低落，回家很晚）/"calm"（被安慰后平复）。
var panda_mood: String = "normal"

## 熊猫疲惫度（预留：后续章节"疲惫递减"手法——没被记住的诉苦会一天比一天更累）。
var panda_fatigue: int = 0

## 今天是否安慰过熊猫（S02b 的安慰选项后置 true，当日有效）。
var comforted_today: bool = false

# ---------- 家宅状态 ----------

## 灯的名字（S02 给灯命名，如"不加班灯"）。命名后生成 M03。
var lamp_name: String = ""

## 最后一盏灯是否常亮。旧录音："最后一盏灯，留给还没回家的人。"
var lamp_lit: bool = true

## 小板凳是否搬到总控屏旁（S02 产出，"位置永久保留"，不吃失忆）。
var stool_placed: bool = false

## 漏水标记（S01 湿脚印发现后置 true）。
var leak_found: bool = false

## 回水是否完成（S01 的 A/B 选项都通向暖炉密封口；完成后生成 M01）。
var leak_fixed: bool = false

## 暖炉是否已启动（S01：地面"已打扫干净"后启动）。
var heater_on: bool = false

## 树洞角落的便条张数。每日重启自动 +1，日期递增、内容几乎一样；
## S03 玩家亲手翻看、自己数出"已经 N 张了"，反转由玩家拼出来，不靠旁白点破。
## 便条载体与不变细节按熊猫换皮，见 data/pandas.json 的 note_carrier / note_constant。
var note_count: int = 0

## 反转是否已揭示（S03 翻完那沓便条后置 true：它不是第一次受委屈）。
var revealed_loop: bool = false

# ---------- 任务派工 ----------

## 任务运行时状态：{"T01": "locked"/"available"/"done", …}。
## 任务定义见 data/tasks.json（T01–T04，结构支持追加 T05/T06）。
var tasks_status: Dictionary = {}

## 当日已耗电量（用于今日结算与调试显示）。
var energy_spent_today: float = 0.0

# ---------- 预留（后续章节，第一幕不启用） ----------

## 幽灵选项记录：{"选项文本": 次数}——见过/选过的选项留痕，后续章节手法。
var ghost_options_seen: Dictionary = {}

## 固定回家仪式已发生次数（后续章节手法：同一套回家动作每晚上演）。
var home_ritual_count: int = 0

## 后续章节的杂项开关位（占位，避免以后破坏存档结构）。
var chapter_flags: Dictionary = {}

# ---------- 数据缓存（首次访问时从 data/*.json 读入，只读） ----------

var _panda_profiles: Dictionary = {}   # id -> 该熊猫的整条参数
var _memories: Dictionary = {}         # id -> 记忆定义
var _tasks: Dictionary = {}            # id -> 任务定义
var _script: Dictionary = {}           # script.json 整份
var _data_loaded := false


func _ready() -> void:
	_ensure_data_loaded()
	_init_task_status()


# ============================================================
# 数据装载（内部）：只读缓存，不改 JSON
# ============================================================

## 载入 data/ 四份 JSON。幂等，重复调用不会重复解析。
## 任一文件读取或解析失败会 push_error 并返回 false，方便在验收脚本里断言。
func _ensure_data_loaded() -> bool:
	if _data_loaded:
		return true

	var pandas := _read_json(PANDA_DATA_PATH)
	var memories := _read_json(MEMORY_DATA_PATH)
	var tasks := _read_json(TASK_DATA_PATH)
	var script := _read_json(SCRIPT_DATA_PATH)
	if pandas.is_empty() or memories.is_empty() or tasks.is_empty() or script.is_empty():
		return false

	for p in pandas.get("presets", []):
		if p is Dictionary and p.has("id"):
			_panda_profiles[p["id"]] = p
	for m in memories.get("memories", []):
		if m is Dictionary and m.has("id"):
			_memories[m["id"]] = m
	for t in tasks.get("tasks", []):
		if t is Dictionary and t.has("id"):
			_tasks[t["id"]] = t
	_script = script

	_data_loaded = true
	return true


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("[GameState] 读取失败或文件为空: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("[GameState] JSON 解析失败: " + path)
		return {}
	return parsed


## 按 unlock_phase 初始化所有任务为 locked / available（S00 解锁 T01-T03）。
func _init_task_status() -> void:
	for id in _tasks.keys():
		var unlock: String = _tasks[id].get("unlock_phase", "S00")
		tasks_status[id] = "available" if unlock == "S00" else "locked"


# ============================================================
# 命名与熊猫参数
# ============================================================

## S00：选择熊猫并命名。preset 写入 panda_preset（决定换皮参数，见 data/pandas.json），
## panda 写入 panda_name（替换〔熊猫名〕），
## controller 写入 controller_name（替换〔总控名〕，默认"念念"）。
## 空字符串视为「不改」，便于只覆盖其中一项。
func set_names(preset: String, panda: String, controller: String) -> void:
	_ensure_data_loaded()
	if not preset.is_empty():
		if _panda_profiles.has(preset):
			panda_preset = preset
		else:
			push_warning("[GameState] 未知熊猫预设: " + preset + "，已忽略")
	if not panda.is_empty():
		panda_name = panda
	if not controller.is_empty():
		controller_name = controller
	state_changed.emit("names")


## 取当前熊猫的换皮参数（data/pandas.json 里该 preset 的整条记录）。
## 剧本里 {panda.xxx} 占位即由本函数返回的字典取值。未选熊猫时返回空字典。
func get_panda_profile() -> Dictionary:
	_ensure_data_loaded()
	if panda_preset.is_empty():
		return {}
	return _panda_profiles.get(panda_preset, {}).duplicate(true)


## 列出全部可选熊猫（主页面选角用），返回 [{id, name, job, personality, ...}]。
func list_panda_presets() -> Array:
	_ensure_data_loaded()
	return _panda_profiles.values().duplicate()


## 取某条记忆定义（UI 渲染记忆卡片用）。未定义返回空字典。
func get_memory_def(memory_id: String) -> Dictionary:
	_ensure_data_loaded()
	return _memories.get(memory_id, {}).duplicate(true)


## 取某条任务定义（UI 渲染任务卡用）。未定义返回空字典。
func get_task_def(task_id: String) -> Dictionary:
	_ensure_data_loaded()
	return _tasks.get(task_id, {}).duplicate(true)


## 取整份剧本数据（UI 层按 phase 过滤）。
func get_script_data() -> Dictionary:
	_ensure_data_loaded()
	return _script.duplicate(true)


## 取某一场（按 phase）。未找到返回空字典。
func get_scene(scene_phase: String) -> Dictionary:
	_ensure_data_loaded()
	for sc in _script.get("scenes", []):
		if sc is Dictionary and sc.get("phase", "") == scene_phase:
			return sc.duplicate(true)
	return {}


## 取便条模板（树洞角落用）。
func get_daily_note_template() -> Dictionary:
	_ensure_data_loaded()
	return _script.get("daily_note", {}).duplicate(true)


## 把台词里的占位符替换成实际值：
##   〔熊猫名〕〔总控名〕 → 当前命名
##   {panda.xxx}        → data/pandas.json 该 preset 的字段
## UI 层所有要显示给玩家的文本都应先过这一层。
func format_text(raw: String) -> String:
	var out := raw
	out = out.replace("〔熊猫名〕", panda_name)
	out = out.replace("〔总控名〕", controller_name)

	var prof := get_panda_profile()
	if not prof.is_empty():
		for key in prof.keys():
			out = out.replace("{" + "panda." + str(key) + "}", str(prof[key]))
	return out


# ============================================================
# 每日循环
# ============================================================

## 每日重启，"环"的闭合点：day_count +1；执行失忆——清空当天状态
## （memory_candidates、comforted_today、panda_mood 回落），kept_memory_ids 原样保留；
## 树洞角落自动多一张便条（note_count +1，内容模板见 data/script.json 的 daily_note）；
## phase 回到当日入口，等待熊猫"又从头说起"。
func start_new_day() -> void:
	day_count += 1

	# 失忆：当天的一切都刷新，只有 kept_memory_ids 和永久物件留下。
	memory_candidates.clear()
	comforted_today = false
	panda_mood = "normal"
	leak_found = false
	leak_fixed = false
	energy_spent_today = 0.0

	# 早晨回满电。
	energy = max_energy
	energy_changed.emit(energy, max_energy)

	# 没被记住的诉苦，一天比一天更累（第一幕只累积、不消费，留给后续章节）。
	if not has_kept_memory("M05"):
		panda_fatigue += 1

	# 树洞角落自动多一张便条——这个是玩家亲手数的那个「N」。
	add_daily_note()

	# 任务回到可派工（RL 里每日清零，已完成的成果由永久物件体现）。
	_init_task_status()

	# 回到当日入口。第一幕的"环"从 S01 重新开始（S00 只在开局演一次）。
	advance_phase("S01")

	new_day_started.emit(day_count)
	memory_candidates_changed.emit(memory_candidates.duplicate())


## 树洞角落加一张便条：note_count +1。内容取 data/script.json 的 daily_note 模板，
## 日期递增、内容几乎一样（"今天又在外面受了委屈。可那不是我该受的。"）。
## 载体与不变细节按熊猫换皮（note_carrier / note_constant）。
func add_daily_note() -> void:
	note_count += 1
	note_added.emit(note_count)


## 取一张便条的展示文案（按张数从新到旧）。UI 翻便条界面用。
## index 0 = 最新一张（今天），1 = 昨天，2 = 前天…越往后越含糊，符合"内容几乎一样"。
func get_note_text(index: int) -> String:
	var tpl := get_daily_note_template()
	if index == 0:
		return str(tpl.get("template", "今天又在外面受了委屈。可那不是我该受的。"))
	return str(tpl.get("variant", "今天又受了委屈。"))


## 取一张便条的日期标签（昨天／前天／更早…）。
func get_note_date_label(index: int) -> String:
	if index == 0:
		return "今天"
	if index == 1:
		return "昨天"
	if index == 2:
		return "前天"
	return "更早"


# ============================================================
# 任务派工
# ============================================================

## 解锁任务：tasks_status[task_id] 置为 "available"（如 S00 结束解锁 T01，进入自由派工）。
func unlock_task(task_id: String) -> void:
	_ensure_data_loaded()
	if not _tasks.has(task_id):
		push_warning("[GameState] 未知任务: " + task_id)
		return
	if tasks_status.get(task_id, "") == "done":
		return
	tasks_status[task_id] = "available"
	task_changed.emit(task_id, "available")


## 完成任意任务：tasks_status[task_id] 置为 "done"，并推进 S01 触发条件检查。
## 耗电请在派工时用 submit_task()，本函数只翻状态位（兼容旧接口）。
func complete_task(task_id: String) -> void:
	_ensure_data_loaded()
	if not _tasks.has(task_id):
		push_warning("[GameState] 未知任务: " + task_id)
		return
	tasks_status[task_id] = "done"
	task_changed.emit(task_id, "done")
	_check_s01_trigger()


## 派工：扣该任务的 energy_cost，电量不足返回 false（不做任何改动）。
## 成功则置为 done，并检查 S01 触发条件（T01 清洁 + T02 生活 均完成）。
## 这是 UI「派工」按钮的唯一入口。
func submit_task(task_id: String) -> bool:
	_ensure_data_loaded()
	if not _tasks.has(task_id):
		push_warning("[GameState] 未知任务: " + task_id)
		return false
	if tasks_status.get(task_id, "") == "done":
		return false
	if tasks_status.get(task_id, "locked") == "locked":
		return false

	var cost: float = float(_tasks[task_id].get("energy_cost", 0))
	if not spend_energy(cost):
		return false

	tasks_status[task_id] = "done"
	task_changed.emit(task_id, "done")
	_check_s01_trigger()
	return true


## S01 触发条件：完成清洁与生活（T01、T02 均为 done）。
## 只在当前还停在 S00 时推进，避免玩家回到旧阶段。
func _check_s01_trigger() -> bool:
	var ok: bool = tasks_status.get("T01", "") == "done" and tasks_status.get("T02", "") == "done"
	if ok and phase == "S00":
		advance_phase("S01")
		return true
	return false


## 任务是否已完成。
func is_task_done(task_id: String) -> bool:
	return tasks_status.get(task_id, "") == "done"


## 当前可派工的任务 id 列表（available 且当日电量够）。
func list_available_tasks() -> Array:
	var out: Array = []
	for id in tasks_status.keys():
		if tasks_status[id] == "available":
			out.append(id)
	return out


# ============================================================
# 电量
# ============================================================

## 扣电量。电量不足返回 false——"留省电还是留名字"的取舍入口。
## 注意：不足时**不扣**（不做部分扣除），避免出现扣干净却办不成事的尴尬状态。
func spend_energy(amount: float) -> bool:
	if amount < 0.0:
		return false
	if energy < amount:
		return false
	energy -= amount
	energy_spent_today += amount
	energy_changed.emit(energy, max_energy)
	return true


## 加电（预留：后续章节的回收机制）。
func gain_energy(amount: float) -> void:
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)


## 电量是否够做某件事（按钮置灰判断用）。
func can_afford(amount: float) -> bool:
	return energy >= amount


## 把电量补满（每日重启内部用，也可给调试）。
func refill_energy() -> void:
	energy = max_energy
	energy_changed.emit(energy, max_energy)


# ============================================================
# 记忆
# ============================================================

## 生成记忆候选：把 memory_id 追加进 memory_candidates，供夜里选记忆。
## 例：S01 回水后生成 M01；S02 给灯命名后生成 M03；S02b 安慰后生成 M05《它今天受委屈了》。
func add_memory_candidate(memory_id: String) -> void:
	_ensure_data_loaded()
	if not _memories.has(memory_id):
		push_warning("[GameState] 未知记忆: " + memory_id)
		return
	if memory_candidates.has(memory_id) or kept_memory_ids.has(memory_id):
		return
	memory_candidates.append(memory_id)
	memory_candidates_changed.emit(memory_candidates.duplicate())


## 夜里选记忆（S03 之前的抉择点）：把 memory_id 从候选挪进 kept_memory_ids
## （受 memory_capacity 上限约束），并按 data/memories.json 的 keep_cost 扣电——
## 留名字，就不省电。返回是否成功。
## 失败原因（容量满 / 不在候选 / 电量不足）都不改动状态，由 UI 提示玩家。
func keep_memory(memory_id: String) -> bool:
	_ensure_data_loaded()
	if not memory_candidates.has(memory_id):
		return false
	if kept_memory_ids.size() >= memory_capacity:
		return false

	var cost: float = float(_memories.get(memory_id, {}).get("keep_cost", 0.0))
	if not spend_energy(cost):
		return false

	memory_candidates.erase(memory_id)
	kept_memory_ids.append(memory_id)
	memory_kept.emit(memory_id)
	memory_candidates_changed.emit(memory_candidates.duplicate())
	return true


## 查询某条记忆是否已留住。次日分支用：留了 M05 → 熊猫轻声（按性格换皮）；
## 没留 → 它又要从头说起，这一次语气更疲惫。
func has_kept_memory(memory_id: String) -> bool:
	return kept_memory_ids.has(memory_id)


## 留这条记忆要多少电（UI 在按钮上显示代价）。
func get_memory_cost(memory_id: String) -> float:
	_ensure_data_loaded()
	return float(_memories.get(memory_id, {}).get("keep_cost", 0.0))


## 当前记忆槽是否还有空位。
func has_memory_slot() -> bool:
	return kept_memory_ids.size() < memory_capacity


## 今夜候选里，哪一条是「它今天受委屈了」——破环关键。
func has_grievance_candidate() -> bool:
	return memory_candidates.has("M05")


# ============================================================
# 情感场
# ============================================================

## 安慰熊猫（S02b 安慰选项 A/B/C 之后）：comforted_today = true，
## panda_mood 由 low 转为 calm（"……谢谢你听我说。"），
## 并生成经历记忆候选 M05《它今天受委屈了》。
## 重复安慰不会重复生成候选（add_memory_candidate 内部去重）。
func comfort_panda() -> void:
	comforted_today = true
	panda_mood = "calm"
	add_memory_candidate("M05")
	state_changed.emit("comforted")


## 熊猫回家很晚：mood 置 low（S02b 开场调用）。
func set_panda_low() -> void:
	panda_mood = "low"
	state_changed.emit("panda_mood")


## 给灯命名（S02）：写入 lamp_name，生成 M03，
## 小板凳搬到总控屏旁（stool_placed = true，位置永久保留）。
func set_lamp_name(new_name: String) -> void:
	if new_name.strip_edges().is_empty():
		return
	lamp_name = new_name
	stool_placed = true
	add_memory_candidate("M03")
	state_changed.emit("lamp_name")


# ============================================================
# 家宅 / 阶段
# ============================================================

## 回水完成（S01 的 A/B 选项都通向暖炉密封口）：leak_fixed = true，
## 生成记忆候选 M01《暖炉漏水了》。重复调用不重复生成。
func fix_leak() -> void:
	leak_found = true
	leak_fixed = true
	add_memory_candidate("M01")
	state_changed.emit("leak")


## 推进剧情阶段：phase 切到 next_phase（S00 → S01 → S02b → S02 → S03）。
func advance_phase(next_phase: String) -> void:
	if next_phase == phase:
		return
	phase = next_phase
	phase_changed.emit(phase)


## 揭示反转（S03）：revealed_loop = true。
## 翻便条、数张数的演出由 UI 层做，本函数只翻状态位。
func reveal_loop() -> void:
	if revealed_loop:
		return
	revealed_loop = true
	loop_revealed.emit()


## 次日该说哪一句：留了 M05 → 按性格换皮的那句；没留 → 从头再说，语气更疲惫。
## 返回 {line, note, kept}，line/note 已做占位符替换。
func get_next_day_line() -> Dictionary:
	var sc := get_scene("S03")
	var branch: Dictionary = sc.get("next_day", {}).get("kept_m05" if has_kept_memory("M05") else "not_kept", {})
	return {
		"kept": has_kept_memory("M05"),
		"line": format_text(str(branch.get("line", ""))),
		"note": format_text(str(branch.get("note", ""))),
	}


# ============================================================
# 存档 / 读档 / 重开
# ============================================================

## 需要持久化的字段清单。新增字段只要加进来，存档结构不用动。
const _SAVE_FIELDS := [
	"day_count", "phase", "chapter",
	"controller_name", "energy", "max_energy", "memory_capacity",
	"kept_memory_ids", "memory_candidates",
	"panda_name", "panda_preset", "panda_mood", "panda_fatigue", "comforted_today",
	"lamp_name", "lamp_lit", "stool_placed",
	"leak_found", "leak_fixed", "heater_on",
	"note_count", "revealed_loop",
	"tasks_status", "energy_spent_today",
	"ghost_options_seen", "home_ritual_count", "chapter_flags",
]


## 存档。返回是否成功。
func save_game() -> bool:
	var data := {}
	for f in _SAVE_FIELDS:
		data[f] = get(f)
	data["_version"] = 1

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameState] 存档打开失败: " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## 读档。返回是否成功。字段缺失时保留当前值，不把存档结构变化变成崩溃。
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("[GameState] 存档解析失败")
		return false

	var data: Dictionary = parsed
	for f in _SAVE_FIELDS:
		if data.has(f):
			set(f, data[f])

	_repair_consistency()

	# 读档后统一刷一遍信号，UI 重新对齐。
	energy_changed.emit(energy, max_energy)
	phase_changed.emit(phase)
	memory_candidates_changed.emit(memory_candidates.duplicate())
	new_day_started.emit(day_count)
	return true


## 修正存档里可能存在的自相矛盾（手改存档、旧版本结构、异常退出都能造出来）：
##   - 已留存的记忆不该同时留在候选里
##   - 候选 / 留存里出现的未知记忆 id 剔除
##   - 留存超过 memory_capacity 的截断（保前面）
##   - 电量夹在 [0, max_energy]
func _repair_consistency() -> void:
	_ensure_data_loaded()

	var kept_clean: Array = []
	for mid in kept_memory_ids:
		if _memories.has(mid) and not kept_clean.has(mid):
			kept_clean.append(mid)
	if kept_clean.size() > memory_capacity:
		kept_clean = kept_clean.slice(0, memory_capacity)
	kept_memory_ids = kept_clean

	var cand_clean: Array = []
	for mid in memory_candidates:
		if _memories.has(mid) and not kept_memory_ids.has(mid) and not cand_clean.has(mid):
			cand_clean.append(mid)
	memory_candidates = cand_clean

	energy = clampf(energy, 0.0, max_energy)

	for tid in tasks_status.keys():
		if not _tasks.has(tid):
			tasks_status.erase(tid)


## 重开一局：全部字段回到本文件顶部的初值。
func reset_for_new_game() -> void:
	day_count = 1
	phase = "S00"
	chapter = 1

	controller_name = "念念"
	energy = DAILY_ENERGY
	max_energy = DAILY_ENERGY
	memory_capacity = 1
	kept_memory_ids = []
	memory_candidates = []

	panda_name = ""
	panda_preset = ""
	panda_mood = "normal"
	panda_fatigue = 0
	comforted_today = false

	lamp_name = ""
	lamp_lit = true
	stool_placed = false
	leak_found = false
	leak_fixed = false
	heater_on = false
	note_count = 0
	revealed_loop = false

	tasks_status = {}
	energy_spent_today = 0.0

	ghost_options_seen = {}
	home_ritual_count = 0
	chapter_flags = {}

	_init_task_status()

	energy_changed.emit(energy, max_energy)
	phase_changed.emit(phase)
	memory_candidates_changed.emit(memory_candidates.duplicate())
