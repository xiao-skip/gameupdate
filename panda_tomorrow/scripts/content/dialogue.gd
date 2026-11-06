extends Node
## ============================================================
## Dialogue —— 内容/对话服务（autoload 单例）
##
## 读 script.json + panda_profiles.json，按 phase 取场景，
## 把 {panda.xxx} 占位符替换成当前熊猫的对应字段（换皮机制）。
## 通过 project.godot 的 [autoload] 注册，任何脚本直接 Dialogue.xxx。
## ============================================================

var _script_data: Dictionary = {}
var _profiles_data: Dictionary = {}


func _load_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _get_script() -> Dictionary:
	if _script_data.is_empty():
		var parsed: Variant = _load_json("res://data/script.json")
		if parsed is Dictionary:
			_script_data = parsed
	return _script_data


func _get_profiles() -> Dictionary:
	if _profiles_data.is_empty():
		var parsed: Variant = _load_json("res://data/panda_profiles.json")
		if parsed is Dictionary:
			_profiles_data = parsed
	return _profiles_data


## 返回某只熊猫的全部字段（id 不存在时返回空字典）。
func get_profile(panda_id: String) -> Dictionary:
	var profiles: Dictionary = _get_profiles().get("pandas", {})
	return profiles.get(panda_id, {})


## 返回全部熊猫 id，如 ["huahua","zhuangzhuang","lingling","keke"]。
func get_panda_ids() -> Array:
	var profiles: Dictionary = _get_profiles().get("pandas", {})
	return profiles.keys()


## 按 phase 取场景（未找到返回空字典）。
func get_scene(phase: String) -> Dictionary:
	var scenes: Array = _get_script().get("scenes", [])
	for scene: Dictionary in scenes:
		if str(scene.get("phase", "")) == phase:
			return scene
	return {}


func get_daily_note_template() -> String:
	var note: Dictionary = _get_script().get("daily_note", {})
	return str(note.get("template", ""))


## 替换 {panda.xxx} 占位符。
func _resolve_text(text: String, profile: Dictionary) -> String:
	var result: String = text
	for key in profile.keys():
		result = result.replace("{panda." + str(key) + "}", str(profile[key]))
	return result


func _resolve_value(value: Variant, profile: Dictionary) -> Variant:
	if value is String:
		return _resolve_text(value, profile)
	if value is Dictionary:
		return _resolve_dict(value, profile)
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_resolve_value(item, profile))
		return arr
	return value


func _resolve_dict(data: Dictionary, profile: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in data.keys():
		out[key] = _resolve_value(data[key], profile)
	return out


## 取场景并替换占位符，返回一个已换皮的新字典（不改缓存）。
func resolve_scene(phase: String, panda_id: String) -> Dictionary:
	var scene: Dictionary = get_scene(phase)
	if scene.is_empty():
		return {}
	var profile: Dictionary = get_profile(panda_id)
	return _resolve_dict(scene, profile)
