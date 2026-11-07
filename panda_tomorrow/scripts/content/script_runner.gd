extends Node
## ============================================================
## ScriptRunner —— 剧本加载与推进器
##
## 职责单一：把 data/script.json 的静态数据变成可逐步推进的对话流。
##   - 按 phase 载入场景
##   - 把 lines / options / branches 摊平成一条可「下一步」的指令序列
##   - 玩家选选项时执行选项映射的动作（调 GameState）
##   - 所有对外文本已过 GameState.format_text()，换皮与占位符替换在这一层完成
##
## 本类**不碰 UI**：不建控件、不写布局。UI 层订阅信号或轮询 current() 渲染。
## 本类也**不写状态**：状态全在 GameState，本类只读取与调用。
##
## 用法（UI 层）：
##   var runner := ScriptRunner.new()
##   add_child(runner)
##   runner.line_advanced.connect(_on_line)
##   runner.awaiting_choice.connect(_on_choice)
##   runner.start_phase("S00")
##   runner.advance()        # 玩家点「继续」
##   runner.choose(0)        # 玩家点第 0 个选项
##
## 节点类型（current() 返回字典的 type 字段）：
##   say     一句台词   {speaker, text, tag?, note?}
##   stage   演出提示   {text}     —— UI 可作旁白显示，也可跳过
##   pause   停顿       {}         —— UI 自行处理（等点击或延时）
##   choice  等玩家选   {options:[{index,id,text,tone?,lamp_name?}]}
##   done    本场结束   {}
##
## 推进模型：内部是一条扁平的节点队列 + 游标。选项被选中时，
## 把该选项产生的后续节点（分支台词 / 收尾台词）**插入到游标之后**，
## 因此不会打断外层流程，也无需维护复杂的状态栈。
## ============================================================

signal line_advanced(node: Dictionary)              ## 推进到一个新节点
signal awaiting_choice(options: Array)              ## 进入选项等待
signal phase_started(phase: String, title: String)  ## 场景开始
signal phase_finished(phase: String)                ## 场景结束（收尾动作已执行）
signal script_finished()                            ## 第一幕全部走完
signal action_executed(action: String, ok: bool)    ## 选项动作执行结果

## 第一幕的阶段顺序。S03 是终点（下一阶段为空）。
const PHASE_ORDER := ["S00", "S01", "S02b", "S02", "S03"]

var _scene: Dictionary = {}     ## 当前场景原始数据
var _queue: Array = []          ## 扁平节点队列
var _cursor: int = -1           ## 当前节点下标（-1 = 未开始）
var _phase: String = ""
var _finished: bool = false


# ============================================================
# 生命周期
# ============================================================

## 载入并开始一个阶段。phase 不存在时返回 false 并 push_error。
func start_phase(phase: String) -> bool:
	var scene := GameState.get_scene(phase)
	if scene.is_empty():
		push_error("[ScriptRunner] 找不到场景: " + phase)
		return false

	_scene = scene
	_phase = phase
	_cursor = -1
	_finished = false

	# 场景入口的情绪预设：熊猫回家很晚时先把 mood 压到 low
	if phase == "S02b":
		GameState.set_panda_low()

	# 主台词 → 选项（若顶层有）→ 结束
	_queue = []
	for l in scene.get("lines", []):
		if l is Dictionary:
			_queue.append(l)

	var top_options: Array = scene.get("options", [])
	if not top_options.is_empty():
		_queue.append(_make_choice_node(top_options, scene.get("after_option", []), ""))

	phase_started.emit(phase, str(scene.get("title", "")))

	if _queue.is_empty():
		_finish_phase()
		return true

	return advance()


## 由当前 GameState.phase 启动（正常流程入口）。
func start_current_phase() -> bool:
	return start_phase(GameState.phase)


## 取下一个节点并发射 line_advanced。队列走完则收尾。
## 返回是否还有内容可播。
func advance() -> bool:
	if _finished:
		return false

	_cursor += 1

	if _cursor < _queue.size():
		var node := current()
		line_advanced.emit(node)
		if node.get("type", "") == "choice":
			awaiting_choice.emit(node.get("options", []))
		return true

	_finish_phase()
	return false


## 当前节点（已做占位符替换）。越界时返回 {"type":"done"}。
func current() -> Dictionary:
	if _cursor < 0 or _cursor >= _queue.size():
		return { "type": "done" }
	return _render_node(_queue[_cursor])


## 是否正在等待玩家选择。
func is_awaiting_choice() -> bool:
	if _cursor < 0 or _cursor >= _queue.size():
		return false
	return _queue[_cursor].get("type", "") == "choice"


## 本场是否已结束。
func is_finished() -> bool:
	return _finished

func get_phase() -> String:
	return _phase

func remaining_count() -> int:
	return maxi(_queue.size() - _cursor - 1, 0)


# ============================================================
# 选项
# ============================================================

## 玩家选择第 option_index 个选项。仅当 current() 是 choice 时有效。
## 流程：执行动作 → 把后续节点（分支台词/收尾台词）插到游标后 → 推进。
func choose(option_index: int) -> bool:
	if not is_awaiting_choice():
		push_warning("[ScriptRunner] 当前不在选项状态，choose 被忽略")
		return false

	var node: Dictionary = _queue[_cursor]
	var options: Array = node.get("options", [])
	if option_index < 0 or option_index >= options.size():
		push_warning("[ScriptRunner] 选项下标越界: " + str(option_index))
		return false

	var opt: Dictionary = options[option_index]

	# 1. 执行选项动作（回水 / 安慰 / 给灯命名 / 派工 …）
	_run_action(opt)

	# 2. 计算该选项产生的后续节点
	var follow: Array = []

	# 2a. 有 next 则进入该分支：分支台词 + 分支内的选择
	var next_branch := str(opt.get("next", ""))
	if next_branch != "":
		follow = _build_branch_nodes(next_branch)
	else:
		# 2b. 没有分支，走本层收尾台词（after_option / after_comfort）
		for l in node.get("after", []):
			if l is Dictionary:
				follow.append(l)

	_insert_after_cursor(follow)
	return advance()


## 把一批节点插到游标之后，保持后续队列不变。
func _insert_after_cursor(nodes: Array) -> void:
	if nodes.is_empty():
		return
	var head := _queue.slice(0, _cursor + 1)
	var tail := _queue.slice(_cursor + 1)
	_queue = head + nodes + tail


## 按分支名生成后续节点：分支台词，尾随一个分支内的选择节点（若有 comfort_options）。
func _build_branch_nodes(branch_name: String) -> Array:
	var branches: Dictionary = _scene.get("branches", {})
	if not branches.has(branch_name):
		push_error("[ScriptRunner] 找不到分支: " + branch_name)
		return []

	var branch: Dictionary = branches[branch_name]
	var out: Array = []

	for l in branch.get("lines", []):
		if l is Dictionary:
			out.append(l)

	var opts: Array = branch.get("comfort_options", [])
	if not opts.is_empty():
		# 分支内选择：收尾台词取 after_comfort
		out.append(_make_choice_node(opts, branch.get("after_comfort", []), branch_name))

	return out


## 构造一个 choice 节点。after 为该选择选完后要播的台词。
func _make_choice_node(options: Array, after: Array, branch: String) -> Dictionary:
	return {
		"type": "choice",
		"options": options,
		"after": after,
		"branch": branch,
	}


# ============================================================
# 收尾
# ============================================================

func _finish_phase() -> void:
	if _finished:
		return
	_finished = true

	_run_on_finish(_scene.get("on_finish", []))
	phase_finished.emit(_phase)

	var next_phase := next_phase_of(_phase)

	# 只在玩家还没手动推进过时才自动推进，避免覆盖外部状态
	if next_phase != "" and GameState.phase == _phase:
		GameState.advance_phase(next_phase)

	if next_phase == "":
		script_finished.emit()


## 给定阶段返回下一阶段；S03 返回 ""（第一幕终点）。
func next_phase_of(phase: String) -> String:
	var i := PHASE_ORDER.find(phase)
	if i < 0 or i >= PHASE_ORDER.size() - 1:
		return ""
	return PHASE_ORDER[i + 1]


# ============================================================
# 动作执行
# ============================================================

## 执行一个选项的 action。动作名 → GameState 方法。
## 加新动作时：在 data/script.json 里写 action，在这里加一个 match 分支。
func _run_action(opt: Dictionary) -> void:
	var action := str(opt.get("action", ""))
	if action == "":
		return

	var ok := false
	match action:
		"fix_leak":
			GameState.fix_leak()
			ok = true
		"comfort_panda":
			GameState.comfort_panda()
			ok = true
		"set_lamp_name":
			GameState.set_lamp_name(str(opt.get("lamp_name", "不加班灯")))
			ok = true
		"submit_task":
			ok = GameState.submit_task(str(opt.get("task_id", "")))
		"keep_memory":
			ok = GameState.keep_memory(str(opt.get("memory_id", "")))
		"start_new_day":
			GameState.start_new_day()
			ok = true
		_:
			push_warning("[ScriptRunner] 未知动作: " + action)

	action_executed.emit(action, ok)


## 场景收尾动作（S00 解锁任务、S03 揭示反转）。
func _run_on_finish(actions: Array) -> void:
	for a in actions:
		match str(a):
			"unlock_t01":
				for tid in ["T01", "T02", "T03"]:
					GameState.unlock_task(tid)
			"reveal_loop":
				GameState.reveal_loop()
			_:
				pass


# ============================================================
# 文本渲染（所有对外文本在此过 format_text）
# ============================================================

func _render_node(node: Dictionary) -> Dictionary:
	var t := str(node.get("type", "say"))

	match t:
		"say":
			var out := {
				"type": "say",
				"speaker": GameState.format_text(str(node.get("speaker", ""))),
				"text": GameState.format_text(str(node.get("text", ""))),
			}
			if node.has("tag"):
				out["tag"] = GameState.format_text(str(node["tag"]))
			if node.has("note"):
				out["note"] = GameState.format_text(str(node["note"]))
			return out

		"stage":
			return { "type": "stage", "text": GameState.format_text(str(node.get("text", ""))) }

		"pause":
			return { "type": "pause" }

		"choice":
			return {
				"type": "choice",
				"options": _render_choice_options(node.get("options", [])),
				"branch": str(node.get("branch", "")),
			}

		_:
			return { "type": "done" }


func _render_choice_options(options: Array) -> Array:
	var out: Array = []
	for i in options.size():
		var o: Dictionary = options[i]
		var item := {
			"index": i,
			"id": str(o.get("id", str(i))),
			"text": GameState.format_text(str(o.get("text", ""))),
		}
		if o.has("tone"):
			item["tone"] = o["tone"]
		if o.has("lamp_name"):
			item["lamp_name"] = o["lamp_name"]
		out.append(item)
	return out


# ============================================================
# 便捷查询（UI 建菜单、调试、编剧校验用）
# ============================================================

## 当前场景的标题与触发条件（已换皮）。
func get_scene_info() -> Dictionary:
	return {
		"phase": _phase,
		"title": GameState.format_text(str(_scene.get("title", ""))),
		"trigger": GameState.format_text(str(_scene.get("trigger", ""))),
	}


## 场景里所有演出提示（已换皮）。编剧校验台词完整性时用。
func get_stage_notes() -> Array:
	var out: Array = []
	for l in _scene.get("lines", []):
		if l is Dictionary and l.get("type", "") == "stage":
			out.append(GameState.format_text(str(l.get("text", ""))))
	return out


## S03 的便条道具数据（载体、不变细节、当前张数），已换皮。
func get_note_prop() -> Dictionary:
	var prop: Dictionary = _scene.get("prop", {})
	if prop.is_empty():
		return {}
	return {
		"name": GameState.format_text(str(prop.get("name", "树洞角落"))),
		"carrier": GameState.format_text(str(prop.get("carrier", ""))),
		"constant_detail": GameState.format_text(str(prop.get("constant_detail", ""))),
		"total": GameState.note_count,
	}


## 整场台词条数（含选项与分支），用于进度显示。
func total_node_count() -> int:
	return _queue.size()
