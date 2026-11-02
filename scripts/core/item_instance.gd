class_name ItemInstance
extends RefCounted
## A physical item on the shelf: rolled condition, hidden true value.

var def: ItemDef
var condition: float = 1.0
var true_value: int = 0
var quality: float = 1.0
var hot: bool = false
var inspected: bool = false

static func roll(def: ItemDef, rng: GameRNG) -> ItemInstance:
	var item := ItemInstance.new()
	item.def = def
	item.condition = snappedf(rng.randf_range(def.condition_min, def.condition_max), 0.01)
	item.quality = snappedf(rng.randf_range(0.85, 1.15), 0.01)
	item.hot = rng.chance(0.15) and not def.legal
	item.true_value = maxi(1, int(round(def.base_value * (0.45 + 0.55 * item.condition) * item.quality)))
	return item

## Player-visible estimate. Accuracy = inspection skill vs. item difficulty.
func estimate(inspection_skill: int, _rng: GameRNG) -> Dictionary:
	var error_span: float = clampf(0.18 * float(def.inspect_difficulty - inspection_skill + 1), 0.0, 0.45)
	var low := int(round(true_value * (1.0 - error_span)))
	var high := int(round(true_value * (1.0 + error_span)))
	return {"low": maxi(1, low), "high": maxi(1, high), "exact": error_span <= 0.0}

func to_dict() -> Dictionary:
	return {
		"id": def.id, "condition": condition, "true_value": true_value,
		"quality": quality, "hot": hot, "inspected": inspected,
	}

static func from_dict(d: Dictionary) -> ItemInstance:
	var def := ItemDB.get_def(str(d.get("id", "")))
	if def == null:
		return null
	var item := ItemInstance.new()
	item.def = def
	item.condition = float(d.get("condition", 1.0))
	item.true_value = int(d.get("true_value", def.base_value))
	item.quality = float(d.get("quality", 1.0))
	item.hot = bool(d.get("hot", false))
	item.inspected = bool(d.get("inspected", false))
	return item
