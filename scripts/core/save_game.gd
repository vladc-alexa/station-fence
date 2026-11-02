class_name SaveGame
extends RefCounted
## Pure serialization helpers: no file IO here, so tests stay headless-safe.

const VERSION := 1

static func snapshot(state: Dictionary) -> Dictionary:
	var inv: Array = []
	for item in state.get("inventory", []):
		if item != null:
			inv.append(item.to_dict())
	return {
		"version": VERSION,
		"seed": int(state.get("seed", 0)),
		"day": int(state.get("day", 1)),
		"cash": int(state.get("cash", 0)),
		"reputation": int(state.get("reputation", 0)),
		"heat": float(state.get("heat", 0.0)),
		"inspection_skill": int(state.get("inspection_skill", 1)),
		"inventory": inv,
	}

static func restore(data: Dictionary) -> Dictionary:
	var inv: Array = []
	for entry in data.get("inventory", []):
		var item := ItemInstance.from_dict(entry)
		if item != null:
			inv.append(item)
	return {
		"seed": int(data.get("seed", 0)),
		"day": int(data.get("day", 1)),
		"cash": int(data.get("cash", 0)),
		"reputation": int(data.get("reputation", 0)),
		"heat": float(data.get("heat", 0.0)),
		"inspection_skill": int(data.get("inspection_skill", 1)),
		"inventory": inv,
	}

static func to_json(state: Dictionary) -> String:
	return JSON.stringify(snapshot(state), "\t")

static func from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return restore(parsed)
