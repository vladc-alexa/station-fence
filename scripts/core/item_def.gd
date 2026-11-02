class_name ItemDef
extends RefCounted
## Static definition of an item type (data-driven from data/items.json).

var id: String
var name: String
var base_value: int
var category: String
var legal: bool
var inspect_difficulty: int
var condition_min: float
var condition_max: float
var heat_weight: float

static func from_dict(d: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = str(d.get("id", ""))
	def.name = str(d.get("name", def.id))
	def.base_value = int(d.get("base_value", 1))
	def.category = str(d.get("category", "misc"))
	def.legal = bool(d.get("legal", true))
	def.inspect_difficulty = int(d.get("inspect_difficulty", 0))
	def.condition_min = float(d.get("condition_min", 0.5))
	def.condition_max = float(d.get("condition_max", 1.0))
	def.heat_weight = float(d.get("heat_weight", 0.0))
	return def
