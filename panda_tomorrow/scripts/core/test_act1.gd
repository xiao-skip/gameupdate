extends RefCounted
## TestAct1 —— 分工文档 4.2（A 的任务）+ 第 6 节验收清单（可在数据层验证的条目）。
## 文件归 A（scripts/core/）。入口：main.gd 调 run()；无头跑法：
##   godot --headless --path panda_tomorrow
## 约定：测试会真实改写 GameState 与 user:// 下的存档文件，跑完自动清理还原。

var _passed: int = 0
var _failed: int = 0
var _failures: Array = []


func run() -> Dictionary:
	var gs = GameState

	# 干净起点：清历史存档，全部回初值
	gs.reset_for_new_game()

	_section("初值（分工文档第 2 节）")
	_check("panda_name == \"\"", gs.panda_name == "")
	_check("panda_preset == \"\"", gs.panda_preset == "")
	_check("phase == 1", gs.phase == 1)
	_check("leak_marked == false", not gs.leak_marked)
	_check("lamp_named == false", not gs.lamp_named)
	_check("comforted == false", not gs.comforted)
	_check("water_returned == false", not gs.water_returned)
	_check("jg == 0", gs.jg == 0)
	_check("notes == []", gs.notes.is_empty())
	_check("device_flags 三键全 false", not gs.device_flags["seal"] and not gs.device_flags["condenser"] and not gs.device_flags["rack"])
	_check("jg_balance == 0", gs.jg_balance == 0)
	_check("collectibles == []", gs.collectibles.is_empty())
	_check("fatigue == 0", gs.fatigue == 0)
	_check("last_comfort_choice == \"\"", gs.last_comfort_choice == "")
	_check("energy == 8", gs.energy == 8)
	_check("clean_water == 2 / pending_water == 0", gs.clean_water == 2 and gs.pending_water == 0)
	_check("daily_done == {}", gs.daily_done.is_empty())
	_check("memory_candidates == []", gs.memory_candidates.is_empty())
	_check("weather == \"晴\"", gs.weather == "晴")
	_check("kept_id == \"\"（空槽）", gs.kept_id == "")

	_section("A1 资源结算（验收：spend 7 后 energy=1；用 2 水再回水，守恒成立）")
	_check("spend_energy(7) 成功", gs.spend_energy(7))
	_check("spend 7 后 energy == 1", gs.energy == 1)
	_check("只剩 1 电时 spend_energy(2) 拒绝", not gs.spend_energy(2))
	_check("拒绝后 energy 仍为 1（未透支）", gs.energy == 1)
	_check("use_water() 第 1 次", gs.use_water())
	_check("use_water() 第 2 次", gs.use_water())
	_check("净水 0 / 待回收 2", gs.clean_water == 0 and gs.pending_water == 2)
	_check("净水空时 use_water() 拒绝", not gs.use_water())
	_check("return_water() 回收 2 份", gs.return_water() == 2)
	_check("守恒：clean + pending == 2", gs.clean_water + gs.pending_water == 2)

	_section("A2 submit_task（验收：提交 T01 后扣 2 电 1 水、+2 家光）")
	gs._reset_day()
	var r1: Dictionary = gs.submit_task("T01")
	_check("T01 提交成功", bool(r1["ok"]))
	_check("扣 2 电（8 → 6）", gs.energy == 6)
	_check("扣 1 水（净水 1 / 待回收 1）", gs.clean_water == 1 and gs.pending_water == 1)
	_check("+2 家光", gs.jg == 2)
	_check("daily_done 记了 T01", gs.daily_done.has("T01"))
	var r2: Dictionary = gs.submit_task("T01")
	_check("当日重复提交拒绝（already_done）", not bool(r2["ok"]) and String(r2["reason"]) == "already_done")
	_check("不重复发奖：家光仍为 2", gs.jg == 2)
	var r3: Dictionary = gs.submit_task("T99")
	_check("未知任务拒绝（unknown_task）", not bool(r3["ok"]) and String(r3["reason"]) == "unknown_task")
	gs._reset_day()
	gs.clean_water = 0
	var r4: Dictionary = gs.submit_task("T02")
	_check("净水不足拒绝（no_water）", not bool(r4["ok"]) and String(r4["reason"]) == "no_water")
	gs._reset_day()
	var rnp: Dictionary = gs.submit_task("T04")
	_check("没水可回时 T04 拒绝（no_pending_water）", not bool(rnp["ok"]) and String(rnp["reason"]) == "no_pending_water")

	_section("A-Q1 全流程（派工 打扫+生活+微课+回水 → 耗电 7，剩 1，家光 +8）")
	gs.reset_for_new_game()
	for tid in ["T01", "T02", "T03", "T04"]:
		var r: Dictionary = gs.submit_task(tid)
		_check(tid + " 提交成功", bool(r["ok"]))
	_check("耗电 7，剩 1", gs.energy == 1)
	_check("家光 +8", gs.jg == 8)
	_check("回水完成：净水 2 / 待回收 0", gs.clean_water == 2 and gs.pending_water == 0)
	_check("water_returned 置位", gs.water_returned)

	_section("A3 渗漏段（验收：有湿脚印时 T01 成本 2→3）")
	# 完整重置：water_returned 是 World 域标记，上一节的回水结果不能漏到渗漏段场景
	gs.reset_for_new_game()
	gs.mark_leak()
	_check("湿脚印在场", gs.has_wet_footprints())
	_check("T01 有效成本 3（2+1）", int(gs.get_task_cost("T01")["energy"]) == 3)
	var rl: Dictionary = gs.submit_task("T01")
	_check("渗漏期提交 T01 扣 3 电（8 → 5）", bool(rl["ok"]) and gs.energy == 5)
	var rt: Dictionary = gs.submit_task("T04")
	_check("回水任务成功", bool(rt["ok"]))
	_check("回水后湿脚印解除", not gs.has_wet_footprints())
	_check("解除后 T01 成本回 2", int(gs.get_task_cost("T01")["energy"]) == 2)

	_section("A-Q2（留 M01 → 回水不扣电）")
	gs._reset_day()
	_check("无 M01 时回水基础成本 1 电", int(gs.get_task_cost("T04")["energy"]) == 1)
	gs.add_memory_candidate("M01")
	_check("留 M01 成功", gs.save_memory("M01"))
	gs.use_water()
	var rm: Dictionary = gs.submit_task("T04")
	_check("留 M01 后回水不扣电（energy 仍 8）", bool(rm["ok"]) and gs.energy == 8)

	_section("A4 restart + 便条（验收：重启后家光保留、notes 长度 +1）")
	gs.reset_for_new_game()
	gs.jg = 8
	gs.lamp_named = true
	gs.add_memory_candidate("M05")
	_check("save_memory(\"M05\") 成功", gs.save_memory("M05"))
	_check("kept_id == M05", gs.kept_id == "M05")
	var notes_before: int = gs.notes.size()
	gs.restart()
	_check("Day 重置：energy == 8", gs.energy == 8)
	_check("Day 重置：净水 2 / 待回收 0", gs.clean_water == 2 and gs.pending_water == 0)
	_check("daily_done 清空", gs.daily_done.is_empty())
	_check("当夜候选清空", gs.memory_candidates.is_empty())
	_check("家光保留 == 8", gs.jg == 8)
	_check("kept_id 保留 == M05（A-Q5 数据层）", gs.kept_id == "M05")
	_check("notes 长度 +1", gs.notes.size() == notes_before + 1)
	_check("便条日期递增（第 1 张 date == 1）", int(gs.notes[0]["date"]) == 1)
	gs.restart()
	_check("第二次重启 notes 再 +1，第 2 张 date == 2", gs.notes.size() == 2 and int(gs.notes[1]["date"]) == 2)
	_check("两张便条内容非空且几乎一样", String(gs.notes[0]["text"]) != "" and String(gs.notes[1]["text"]) == String(gs.notes[0]["text"]))

	_section("A-Q3 数据层（安慰后当夜候选出现《它被骂了》）")
	gs.reset_for_new_game()
	gs.set_comforted("A「你做得够好了。」")
	_check("set_comforted 置位 comforted", gs.comforted)
	_check("安慰选项被记录（幽灵选项预留）", gs.last_comfort_choice != "")
	gs.add_memory_candidate("M05")
	_check("M05 出现在当夜候选", gs.memory_candidates.has("M05"))
	_check("M05 标题对得上（memories.json）", String(gs._memories["M05"]["title"]) == "它被骂了")

	_section("A5 can_proceed_act1（四条件全真才 true）")
	gs.reset_for_new_game()
	_check("全 false → false", not gs.can_proceed_act1())
	gs.mark_leak()
	_check("只 leak_marked → false", not gs.can_proceed_act1())
	gs.name_lamp()
	_check("leak + lamp → false", not gs.can_proceed_act1())
	gs.set_comforted("B「错不在你。」")
	_check("leak + lamp + comforted → false", not gs.can_proceed_act1())
	gs.use_water()
	gs.submit_task("T04")
	_check("四条件全真 → true", gs.can_proceed_act1())

	_section("A-Q6（空槽重启：无记忆加成仍能继续）")
	gs.reset_for_new_game()
	gs.kept_id = ""
	gs.restart()
	_check("空槽重启合法，kept_id 仍为空", gs.kept_id == "")
	_check("无加成：回水成本回基础价 1 电", int(gs.get_task_cost("T04")["energy"]) == 1)
	gs.use_water()
	var rq: Dictionary = gs.submit_task("T04")
	_check("无加成仍能回水推进", bool(rq["ok"]))

	_section("A-Q7（电量恰好归零：只结算本次，成果保留）")
	gs._reset_day()
	gs.jg = 0
	_check("先花 7 电剩 1", gs.spend_energy(7) and gs.energy == 1)
	gs.use_water()
	var rz: Dictionary = gs.submit_task("T04")
	_check("剩 1 电时 1 电任务照常结算", bool(rz["ok"]))
	_check("energy 恰好归零", gs.energy == 0)
	_check("成果保留：家光已入账（+2）", gs.jg == 2)
	gs._reset_day()
	gs.energy = 1
	var ry: Dictionary = gs.submit_task("T01")
	_check("电量不足（1 < 2）拒绝结算（no_energy）", not bool(ry["ok"]) and String(ry["reason"]) == "no_energy")
	_check("拒绝后家光不变", gs.jg == 2)

	_section("A6 存档检查点（验收：退出重进不丢家光、不丢便条、不重复发奖；损坏回退）")
	gs.reset_for_new_game()
	gs.panda_name = "团团"
	gs.jg = 6
	gs.restart()
	gs.jg = 8
	gs.lamp_named = true
	gs.restart()
	_check("连续两次检查点后 notes == 2", gs.notes.size() == 2)
	# 模拟「退出重进」：内存清空后读档
	gs.jg = 0
	gs.panda_name = ""
	gs.lamp_named = false
	gs.notes = []
	gs.kept_id = "临时污染"
	_check("load_game() 成功", gs.load_game())
	_check("读档后家光不丢（== 8）", gs.jg == 8)
	_check("读档后便条不丢（2 张、日期递增）", gs.notes.size() == 2 and int(gs.notes[1]["date"]) == 2)
	_check("读档后熊猫名恢复", gs.panda_name == "团团")
	_check("读档后推进标记恢复", gs.lamp_named)
	_check("读档后 kept_id 恢复空槽", gs.kept_id == "")
	_check("读档后 Day 重置（当日不重复发奖）", gs.energy == 8 and gs.daily_done.is_empty())
	# 当前档损坏 → 回退上一版（第一次检查点：jg 6）
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{这根本不是 JSON")
	f.close()
	gs.jg = -999
	_check("当前档损坏时 load 回退上一版", gs.load_game())
	_check("回退后家光为上一版检查点的值（== 6）", gs.jg == 6)

	_section("预留接口冒烟（不改变第一幕行为）")
	gs.install_device("seal")
	_check("install_device 打开设备标记", bool(gs.device_flags["seal"]))
	gs.jg_balance = 5
	_check("spend_jg(3) 从兑换余额扣", gs.spend_jg(3) and gs.jg_balance == 2)
	_check("兑换余额不足拒绝", not gs.spend_jg(5))
	gs.add_collectible("小板凳")
	_check("add_collectible 入收藏", gs.collectibles.has("小板凳"))

	_section("清理")
	gs.reset_for_new_game()
	_check("存档文件已清理", not FileAccess.file_exists(GameState.SAVE_PATH) and not FileAccess.file_exists(GameState.SAVE_PREV_PATH))
	_check("全部字段回初值", gs.panda_name == "" and gs.jg == 0 and gs.energy == 8 and gs.notes.is_empty() and gs.kept_id == "")

	return {"passed": _passed, "failed": _failed, "failures": _failures}


func _section(title: String) -> void:
	print("\n== " + title + " ==")


func _check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  [OK] " + name)
	else:
		_failed += 1
		_failures.append(name)
		print("  [FAIL] " + name)
