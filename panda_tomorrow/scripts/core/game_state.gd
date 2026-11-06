extends Node
## ============================================================
## GameState —— 全局游戏状态存根（v0 骨架，不含任何游戏逻辑）
##
## 《熊猫，明天见》第一幕「它不是第一次说」
## 你（团圆，全屋智能总控）每天失忆，照看一只在邮局上班的普通熊猫。
## 这天它下班被老板当众骂了，你安慰它、一起给灯起名；
## 夜里翻冰箱便条才发现——这不是它第一次被骂，也不是它第一次告诉你。
##
## 角色：团圆=玩家/总控；多吉=教师机器人；帕丁=生活管家；小咪=清洁机器人；熊猫=被选择的那只
##
## 通过 project.godot 的 [autoload] 注册为全局单例，任何脚本直接 GameState.xxx 访问。
## 本阶段：只声明字段（含预留）+ 函数签名与注释 + 默认返回值。
## ============================================================

# ---------- 基础进度 ----------

## 当前天数。每日重启 +1，是整个游戏"环"的骨架。
var day_count: int = 1

## 当前剧情阶段，对应 data/script.json 里每条场景的 phase 字段。
## 第一幕顺序：S00 启用 → S01 湿脚印 → S02b 它回家很晚 → S02 给灯命名 → S03 反转
var phase: String = "S00"

## 当前章节号（第一幕 = 1；预留后续幕，手法见剧情第五节）。
var chapter: int = 1

# ---------- 总控（玩家） ----------

## 总控名。S00 命名后写入，运行时替换所有台词里的〔总控名〕。默认"团圆"。
var controller_name: String = "团圆"

## 剩余电量。主题是"留省电，还是留名字"——留住记忆要费电。
var energy: float = 100.0

## 电量上限（预留：后续章节可调）。
var max_energy: float = 100.0

## 每天能稳定留下的记忆条数。多吉在 S00 说："今天能稳定留下一件事。其他的，我们慢慢来。"
var memory_capacity: int = 1

## 跨天留住的记忆 id（"M01"/"M03"/"M05"…）。总控失忆后，这是仅存的东西。
var kept_memory_ids: Array = []

## 今夜的记忆候选（S02b 之后出现《它今天被骂了》等）。夜里选记忆界面用，次日失忆时清空。
var memory_candidates: Array = []

# ---------- 熊猫 ----------

## 熊猫名。S00 选择熊猫并命名后写入，替换台词里的〔熊猫名〕。
var panda_name: String = ""

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

## 冰箱便条张数。每日重启自动 +1，日期递增、内容几乎一样；
## S03 玩家亲手翻看、自己数出"已经 N 张了"，反转由玩家拼出来，不靠旁白点破。
var note_count: int = 0

## 反转是否已揭示（S03 翻完那沓便条后置 true：它不是第一次被骂）。
var revealed_loop: bool = false

# ---------- 任务派工 ----------

## 任务运行时状态：{"T01": "locked"/"available"/"done", …}。
## 任务定义见 data/tasks.json（T01–T04，结构支持追加 T05/T06）。
var tasks_status: Dictionary = {}

# ---------- 预留（后续章节，第一幕不启用） ----------

## 幽灵选项记录：{"选项文本": 次数}——见过/选过的选项留痕，后续章节手法。
var ghost_options_seen: Dictionary = {}

## 固定回家仪式已发生次数（后续章节手法：同一套回家动作每晚上演）。
var home_ritual_count: int = 0

## 后续章节的杂项开关位（占位，避免以后破坏存档结构）。
var chapter_flags: Dictionary = {}


# ============================================================
# 函数存根：只写签名 + 注释 + 默认返回值，逻辑由 B/C 补齐
# ============================================================

## S00：选择熊猫并命名。panda 写入 panda_name（替换〔熊猫名〕），
## controller 写入 controller_name（替换〔总控名〕，默认"团圆"）。
func set_names(panda: String, controller: String) -> void:
	pass


## 每日重启，"环"的闭合点：day_count +1；执行失忆——清空当天状态
## （memory_candidates、comforted_today、panda_mood 回落），kept_memory_ids 原样保留；
## 冰箱自动多一张便条（note_count +1，内容模板见 data/script.json 的 daily_note）；
## phase 回到当日入口，等待熊猫"又从头说起"。
func start_new_day() -> void:
	pass


## 解锁任务：tasks_status[task_id] 置为 "available"（如 S00 结束解锁 T01，进入自由派工）。
func unlock_task(task_id: String) -> void:
	pass


## 完成任务：tasks_status[task_id] 置为 "done"。
## 注意 S01 的触发条件是"完成清洁与生活"，需要检查 T01、T02 均为 done。
func complete_task(task_id: String) -> void:
	pass


## 生成记忆候选：把 memory_id 追加进 memory_candidates，供夜里选记忆。
## 例：S01 回水后生成 M01；S02 给灯命名后生成 M03；S02b 安慰后生成 M05《它今天被骂了》。
func add_memory_candidate(memory_id: String) -> void:
	pass


## 夜里选记忆（S03 之前的抉择点）：把 memory_id 从候选挪进 kept_memory_ids
## （受 memory_capacity 上限约束），并按 data/memories.json 的 keep_cost 扣电——
## 留名字，就不省电。返回是否成功。
func keep_memory(memory_id: String) -> bool:
	return false


## 查询某条记忆是否已留住。次日分支用：留了 M05 → 熊猫轻声"……你还记得。"；
## 没留 → 它又要从头说起，这一次语气更疲惫。
func has_kept_memory(memory_id: String) -> bool:
	return false


## 扣电量。电量不足返回 false——"留省电还是留名字"的取舍入口。
func spend_energy(amount: float) -> bool:
	return false


## 安慰熊猫（S02b 安慰选项 A/B/C 之后）：comforted_today = true，
## panda_mood 由 low 转为 calm（"……谢谢你听我说。"），
## 并生成经历记忆候选 M05《它今天被骂了》。
func comfort_panda() -> void:
	pass


## 给灯命名（S02）：写入 lamp_name，生成 M03，
## 小板凳搬到总控屏旁（stool_placed = true，位置永久保留）。
func set_lamp_name(new_name: String) -> void:
	pass


## 冰箱加一张便条：note_count +1。内容取 data/script.json 的 daily_note 模板，
## 日期递增、内容几乎一样（"今天老板又骂我，把信弄丢了。可那不是我弄丢的。"）。
func add_daily_note() -> void:
	pass


## 推进剧情阶段：phase 切到 next_phase（S00 → S01 → S02b → S02 → S03）。
func advance_phase(next_phase: String) -> void:
	pass


## 揭示反转（S03）：revealed_loop = true。
## 翻便条、数张数的演出由 UI 层做，本函数只翻状态位。
func reveal_loop() -> void:
	pass


## 存档。返回是否成功（存档格式后续定，字段已含预留，避免破坏结构）。
func save_game() -> bool:
	return false


## 读档。返回是否成功。
func load_game() -> bool:
	return false


## 重开一局：全部字段回到本文件顶部的初值。
func reset_for_new_game() -> void:
	pass
