extends Node
## ============================================================
## GameState —— 全局游戏状态（接口见分工文档第 2 节，文件归 A）
##
## 《熊猫，明天见》第一幕「它不是第一次说」
## 你（团圆，全屋智能总控）每天失忆，照看一只在邮局上班的普通熊猫。
##
## 分工约定（分工文档 4.1 / 第 5 节）：
##   - 本文件 + data/tasks.json + data/memories.json + project.godot 归 A 独占
##   - B（scenes/**、scripts/ui/*.gd）只调用本类函数，不改字段
##   - C（data/script.json、data/events.json、scripts/content/*.gd）只读字段 + 调剧情接口
##   - B/C 需要新字段或新函数 → 找 A 加，自己不改本文件
##
## 三域划分：
##   World  —— 跨天保留（家光、便条、推进标记、熊猫名……）
##   Day    —— 每日重置（电、水、当日完成、当夜记忆候选……）
##   Memory —— 跨天保留（留存记忆，单槽，空字符串 = 空槽）
##
## 扩展性（分工文档第 1 节）：加任务/记忆只改 JSON，不改本文件代码。
## ============================================================

## restart() 完成时发出。B 的 UI 收到后播「黑屏 2 秒」过渡（分工文档 4.2-A4）。
signal day_restarted
## submit_task 结算完成时发出，参数即 submit_task 的返回值（B 可选监听刷新任务卡）。
signal task_submitted(result)
## 湿脚印首现（leak_marked 从 false → true）时发出。C 用它播 S01 的免费教学场。
signal leak_first_seen

## 每日电量上限（分工文档：energy 初值 8；恰好归零允许结算，验收 A-Q7）。
const ENERGY_MAX: int = 8
## 每日净水初值（守恒不变量：clean_water + pending_water 恒为 2）。
const WATER_START: int = 2
## 当前检查点存档。
const SAVE_PATH: String = "user://save.json"
## 上一版检查点（当前档损坏时回退，分工文档 4.2-A6）。
const SAVE_PREV_PATH: String = "user://save_prev.json"

# ============================================================
# World 域（跨天保留）
# ============================================================

## 熊猫名 / 熊猫预设（S00 选择熊猫并命名后写入，替换台词里的〔熊猫名〕）。
var panda_name: String = ""
var panda_preset: String = ""

## 当前幕（第一幕 = 1；后续章节推进，B 的顶栏直接读）。
var phase: int = 1

## 三个推进标记（分工文档第 2 节）：
var leak_marked: bool = false     ## S01 湿脚印出现过
var lamp_named: bool = false      ## S02 给灯起过名
var comforted: bool = false       ## S02b 安慰过熊猫

## 完成过回水（A 补充的第四个推进标记：can_proceed_act1 的第 4 个条件）。
var water_returned: bool = false

## 家光（第一幕累计结算；验收 A-Q1：打扫+生活+微课+回水 合计 +8）。
var jg: int = 0

## 房间走完一圈（首尾传送）。B 的快捷切换解锁条件；跨天保留。
var looped_once: bool = false

## 便条数组，每条 { "date": 第几天(int), "text": 便条内容 }。
## 每次 restart 追加一张：日期递增、内容几乎一样（分工文档第 2 节：date+text）。
var notes: Array = []

# ---------- 预留（后续章节，第一幕不启用） ----------

## 设备链（密封 / 冷凝 / 晾布……），install_device() 打开；规则后续加段。
var device_flags: Dictionary = {"seal": false, "condenser": false, "rack": false}

## 兑换余额 / 收藏列表（家光兑换系统预留）。
var jg_balance: int = 0
var collectibles: Array = []

## 熊猫疲惫度 / 最近一次安慰选项（疲惫递减、幽灵选项手法预留）。
var fatigue: int = 0
var last_comfort_choice: String = ""

# ============================================================
# Day 域（每日重置，restart() 归位）
# ============================================================

## 电（8 格；顶栏渲染 8 格，耗电格子变暗——B 的任务）。
var energy: int = ENERGY_MAX

## 净水 / 待回收（守恒：两者之和恒为 2；回水把待回收收回净水）。
var clean_water: int = WATER_START
var pending_water: int = 0

## 当日任务完成表（{"T01": true, ...}；当日重复提交拒绝，防重复发奖）。
var daily_done: Dictionary = {}

## 当夜记忆候选（夜间记忆界面渲染用；夜里选一条 save_memory，restart 清空）。
var memory_candidates: Array = []

## 天气（预留）。
var weather: String = "晴"

# ============================================================
# Memory 域（跨天保留）
# ============================================================

## 留存记忆（单槽；空字符串 = 空槽；验收 A-Q6：空槽重启也合法）。
var kept_id: String = ""

# ============================================================
# 内部（数据表缓存；不向 B/C 承诺格式）
# ============================================================

var _tasks: Dictionary = {}     ## {"T01": 任务定义, ...}，来自 data/tasks.json
var _memories: Dictionary = {}  ## 来自 data/memories.json
var _script: Dictionary = {}    ## 来自 data/script.json（daily_note 在里面，归 C）


func _ready() -> void:
	_load_tables()
	# 启动自动读检查点（有档续玩；无档保持初值。测试需要初值时先 reset_for_new_game）
	load_game()


# ============================================================
# Act1 函数（分工文档 2 节签名）
# ============================================================

## 扣电。电量不足返回 false（拒绝结算，防透支）；
## 恰好归零允许——本次照常结算、成果保留（验收 A-Q7）。
func spend_energy(n: int) -> bool:
	if n < 0 or energy < n:
		return false
	energy -= n
	return true


## 用 1 份净水：净水 -1，转入待回收 +1（「转移水」）。
## 守恒不变量：clean_water + pending_water 恒为 2。净水不足返回 false。
func use_water() -> bool:
	if clean_water < 1:
		return false
	clean_water -= 1
	pending_water += 1
	return true


## 回收全部待回收水 → 净水，返回回收份数。只做水的回收：不扣电、不发家光。
## 走任务结算（submit_task("T04")）才有家光与 water_returned 标记；
## B 的「回水阀」物件想省电省事可直接调本函数（验收 B4：点回水阀回收 2 份水）。
func return_water() -> int:
	var n: int = pending_water
	pending_water = 0
	clean_water += n
	return n


## 派工提交（分工文档 4.2-A2）：
## 读 data/tasks.json → 校验 → 扣电 / 转移水 → 发家光 → 记 daily_done → 返回结果。
## 返回 { "ok": bool, "reason": String, "id": String }，成功时附 "jg" / "water_returned"。
## reason：unknown_task / already_done / no_energy / no_water / no_pending_water
## 成本规则全走数据（加 T05/T06 只在 tasks.json 追加行，不改代码）：
##   cost_energy / cost_water / jg_reward —— 基础成本与奖励
##   surcharge_when_wet —— 湿脚印期间加价电（渗漏段：T01 由 2 → 3，验收 A3）
##   free_when_kept    —— 留了指定记忆则免电（留 M01 → 回水不扣电，验收 A-Q2）
##   effect: "return_water" —— 回收全部待回收水并置 water_returned（T04）
func submit_task(id: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "id": id}
	if not _tasks.has(id):
		result["reason"] = "unknown_task"
		return result
	if daily_done.has(id):
		result["reason"] = "already_done"
		return result
	var t: Dictionary = _tasks[id]
	var cost: Dictionary = get_task_cost(id)
	if energy < int(cost["energy"]):
		result["reason"] = "no_energy"
		return result
	if clean_water < int(cost["water"]):
		result["reason"] = "no_water"
		return result
	if String(t.get("effect", "")) == "return_water" and pending_water < 1:
		result["reason"] = "no_pending_water"
		return result
	# ---- 结算（电量恰好归零允许，验收 A-Q7：只结算本次，成果保留）----
	energy -= int(cost["energy"])
	for i in range(int(cost["water"])):
		use_water()
	jg += int(t.get("jg_reward", 0))
	result["jg"] = int(t.get("jg_reward", 0))
	if String(t.get("effect", "")) == "return_water":
		result["water_returned"] = return_water()
		water_returned = true
	daily_done[id] = true
	result["ok"] = true
	task_submitted.emit(result)
	return result


## 夜里选记忆：从当夜候选中选一条留住（单槽；重复调用 = 改选；不在候选返回 false）。
## 空槽（什么都不留）也合法，直接 restart 即可（验收 A-Q6）。
func save_memory(id: String) -> bool:
	if not memory_candidates.has(id):
		return false
	kept_id = id
	return true


## 每日重启（分工文档 4.2-A4）：
## 追加当日便条 → 重置 Day → 保留 World 与 Memory → 写存档检查点 → 发信号。
## 玩家流程：夜里先 save_memory（或留空），再调 restart。
## 「黑屏 2 秒」由 B 的 UI 监听 day_restarted 实现。
func restart() -> void:
	add_note(_pick_daily_note_text())
	_reset_day()
	save_game()
	day_restarted.emit()


## 第一幕推进条件（分工文档 4.2-A5）：四个条件全真才 true：
## 漏已标记 + 灯已起名 + 安慰过 + 完成过回水。
func can_proceed_act1() -> bool:
	return leak_marked and lamp_named and comforted and water_returned


## 向冰箱便条堆追加一张：{ "date": 第几天, "text": text }。
## 日期 = 追加后的张数（一天一张、递增），B 的翻阅 UI 按此渲染（验收 A-Q4）。
func add_note(text: String) -> void:
	notes.append({"date": notes.size() + 1, "text": text})


# ============================================================
# 剧情推进接口（A 补充：C 的事件系统调这些，不直接改字段）
# ============================================================

## S01 湿脚印：标记漏水。首现（false → true）时发 leak_first_seen，
## C 用它播 S01 教学场（免费教学）；此后 T01 成本 +1（渗漏段），回水后解除。
func mark_leak() -> void:
	if not leak_marked:
		leak_marked = true
		leak_first_seen.emit()


## S02 给灯命名：置标记。灯名文案（如「不加班灯」）在 C 的 script.json 里，
## 状态只存这个布尔（分工文档第 2 节：lamp_named）。
func name_lamp() -> void:
	lamp_named = true


## S02b 安慰熊猫：置标记并记录安慰选项（last_comfort_choice 为幽灵选项手法预留）。
func set_comforted(choice: String = "") -> void:
	comforted = true
	last_comfort_choice = choice


## 生成当夜记忆候选（S01 回水后 M01 / S02 命名后 M03 / S02b 安慰后 M05，由 C 触发）。
## id 不在 memories.json 里只警告不崩溃。
func add_memory_candidate(id: String) -> void:
	if not _memories.has(id):
		push_warning("memories.json 里没有这条记忆: " + id)
		return
	if not memory_candidates.has(id):
		memory_candidates.append(id)


## 查询某任务的当前有效成本与奖励（B 的任务卡可直接读来显示）：
## { "energy": int, "water": int, "jg": int }——含渗漏加价与留记忆减免。
func get_task_cost(id: String) -> Dictionary:
	var t: Dictionary = _tasks.get(id, {})
	var e: int = int(t.get("cost_energy", 0))
	if t.has("surcharge_when_wet") and has_wet_footprints():
		e += int(t["surcharge_when_wet"])
	if t.has("free_when_kept") and kept_id == String(t["free_when_kept"]):
		e = 0
	return {"energy": e, "water": int(t.get("cost_water", 0)), "jg": int(t.get("jg_reward", 0))}


## 湿脚印是否在场：漏已标记且回水未完成（S01 之后、T04 之前）。
func has_wet_footprints() -> bool:
	return leak_marked and not water_returned


# ============================================================
# B 的 UI 查询接口（只读；渲染任务卡 / 记忆界面 / 顶栏用）
# ============================================================

## 全部任务 id（按 tasks.json 顺序）。任务卡「渲染任意列表」直接遍历这个。
func get_task_ids() -> Array:
	return _tasks.keys()


## 任务展示信息 + 当前有效成本：
## { "id", "name", "robot", "type", "desc", "energy", "water", "jg", "done" }。
## 成本含渗漏加价与留记忆减免（get_task_cost），done = 当日已派工。
func get_task_info(id: String) -> Dictionary:
	var t: Dictionary = _tasks.get(id, {})
	if t.is_empty():
		return {}
	var cost: Dictionary = get_task_cost(id)
	return {
		"id": id,
		"name": String(t.get("name", id)),
		"robot": String(t.get("robot", "")),
		"type": String(t.get("type", "")),
		"desc": String(t.get("desc", "")),
		"energy": int(cost["energy"]),
		"water": int(cost["water"]),
		"jg": int(cost["jg"]),
		"done": daily_done.has(id),
	}


## 记忆展示信息：{ "id", "title", "desc", "type" }。id 不存在返回空字典。
func get_memory_info(id: String) -> Dictionary:
	var m: Dictionary = _memories.get(id, {})
	if m.is_empty():
		return {}
	return {
		"id": id,
		"title": String(m.get("title", id)),
		"desc": String(m.get("desc", "")),
		"type": String(m.get("type", "")),
	}


## 第几天：一天一张便条，便条数 + 1（B 的顶栏 / 便条翻阅按此显示）。
func day_number() -> int:
	return notes.size() + 1


## 房间走完一圈（B 在首尾传送发生时调用一次）。
func mark_loop_completed() -> void:
	looped_once = true


# ============================================================
# 预留函数（后续章节，第一幕不启用）
# ============================================================

## 安装设备（密封 / 冷凝 / 晾布……）。设备链规则后续在数据表加段。
func install_device(id: String) -> void:
	device_flags[id] = true


## 家光兑换（预留）：从兑换余额扣，余额不足返回 false。
func spend_jg(n: int) -> bool:
	if n < 0 or jg_balance < n:
		return false
	jg_balance -= n
	return true


## 收藏（预留）。
func add_collectible(id: String) -> void:
	if not collectibles.has(id):
		collectibles.append(id)


# ============================================================
# 存档检查点（分工文档 4.2-A6：保存/读取 World+Memory，损坏回退上一版）
# 约定：restart() 时自动写检查点；启动时自动读。
## Day 域不存档——读档即回到当日清晨，当日已入账的奖励不会重复发（验收 A-Q8）。
# ============================================================

func save_game() -> bool:
	var data: Dictionary = {
		"version": 1,
		"world": {
			"panda_name": panda_name,
			"panda_preset": panda_preset,
			"phase": phase,
			"leak_marked": leak_marked,
			"lamp_named": lamp_named,
			"comforted": comforted,
			"water_returned": water_returned,
			"jg": jg,
			"looped_once": looped_once,
			"notes": notes,
			"device_flags": device_flags,
			"jg_balance": jg_balance,
			"collectibles": collectibles,
			"fatigue": fatigue,
			"last_comfort_choice": last_comfort_choice,
		},
		"memory": {"kept_id": kept_id},
	}
	# 旧档轮换成「上一版」（损坏回退用）。
	# 不用 DirAccess.copy：相对名在 user:// 上下文里解析不稳（实测打不开源文件），
	# 手动读旧档写上一版路径，行为确定。
	if FileAccess.file_exists(SAVE_PATH):
		var old_text := FileAccess.get_file_as_string(SAVE_PATH)
		var fp := FileAccess.open(SAVE_PREV_PATH, FileAccess.WRITE)
		if fp != null:
			fp.store_string(old_text)
			fp.close()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("存档写入失败: " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_game() -> bool:
	# 先试当前档；解析失败或结构不对 → 回退上一版（验收 A6：损坏回退）
	for path in [SAVE_PATH, SAVE_PREV_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (data is Dictionary) or not data.has("world") or not data.has("memory"):
			push_warning("存档损坏，回退上一版: " + path)
			continue
		_apply_save(data)
		return true
	return false


## 重开一局：全部字段回初值，并清掉检查点文件。
func reset_for_new_game() -> void:
	panda_name = ""
	panda_preset = ""
	phase = 1
	leak_marked = false
	lamp_named = false
	comforted = false
	water_returned = false
	jg = 0
	looped_once = false
	notes = []
	device_flags = {"seal": false, "condenser": false, "rack": false}
	jg_balance = 0
	collectibles = []
	fatigue = 0
	last_comfort_choice = ""
	_reset_day()
	kept_id = ""
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("save.json")
		dir.remove("save_prev.json")


# ============================================================
# 内部函数
# ============================================================

func _reset_day() -> void:
	energy = ENERGY_MAX
	clean_water = WATER_START
	pending_water = 0
	daily_done = {}
	memory_candidates = []


func _apply_save(data: Dictionary) -> void:
	var w: Dictionary = data["world"]
	panda_name = String(w.get("panda_name", ""))
	panda_preset = String(w.get("panda_preset", ""))
	phase = int(w.get("phase", 1))
	leak_marked = bool(w.get("leak_marked", false))
	lamp_named = bool(w.get("lamp_named", false))
	comforted = bool(w.get("comforted", false))
	water_returned = bool(w.get("water_returned", false))
	jg = int(w.get("jg", 0))
	looped_once = bool(w.get("looped_once", false))
	notes = []
	for n in w.get("notes", []):
		if n is Dictionary:
			notes.append({"date": int(n.get("date", 0)), "text": String(n.get("text", ""))})
	var df: Variant = w.get("device_flags", {})
	if df is Dictionary:
		device_flags = df
	jg_balance = int(w.get("jg_balance", 0))
	collectibles = []
	for c in w.get("collectibles", []):
		collectibles.append(String(c))
	fatigue = int(w.get("fatigue", 0))
	last_comfort_choice = String(w.get("last_comfort_choice", ""))
	var m: Variant = data["memory"]
	if m is Dictionary:
		kept_id = String(m.get("kept_id", ""))
	_reset_day()


## 当日便条内容：读 data/script.json 的 daily_note（数据归 C）。
## template 为主；每逢第 3 的倍数天用 variant（「内容几乎一样」，验收 A-Q4）。
## script.json 缺 daily_note 时退回剧情文档原句。
func _pick_daily_note_text() -> String:
	var dn: Variant = _script.get("daily_note", {})
	if dn is Dictionary:
		var day: int = notes.size() + 1
		if day % 3 == 0 and String(dn.get("variant", "")) != "":
			return String(dn["variant"])
		var text := String(dn.get("template", ""))
		if text != "":
			return text
	return "今天老板又骂我，把信弄丢了。可那不是我弄丢的。"


func _load_tables() -> void:
	var tj: Variant = _read_json("res://data/tasks.json")
	if tj is Dictionary and tj.has("tasks"):
		for t in tj["tasks"]:
			if t is Dictionary and t.has("id"):
				_tasks[String(t["id"])] = t
	var mj: Variant = _read_json("res://data/memories.json")
	if mj is Dictionary and mj.has("memories"):
		for m in mj["memories"]:
			if m is Dictionary and m.has("id"):
				_memories[String(m["id"])] = m
	var sj: Variant = _read_json("res://data/script.json")
	if sj is Dictionary:
		_script = sj


func _read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("读取失败（空文件）: " + path)
		return null
	var data: Variant = JSON.parse_string(text)
	if data == null:
		push_warning("JSON 解析失败: " + path)
	return data
