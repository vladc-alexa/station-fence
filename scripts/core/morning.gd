class_name Morning
extends RefCounted
## The morning budget: six actions before the shop opens.

const TICKS := 6

var ticks_left: int = TICKS

func reset() -> void:
	ticks_left = TICKS

func can_act() -> bool:
	return ticks_left > 0

func spend(action: String) -> Dictionary:
	if ticks_left <= 0:
		return {"ok": false, "reason": "budget_exhausted", "action": action, "ticks_left": 0}
	ticks_left -= 1
	return {"ok": true, "reason": "", "action": action, "ticks_left": ticks_left}
