class_name PlantDef
extends RefCounted
## Static definition of a plant species (loaded from data/plants.json).

var id: String = ""
var display_name: String = ""
var stage_days: Array = [2, 3, 4]	 # days needed for stage 1 -> 2 -> 3
var water_per_day: float = 1.0
var light_need: String = "mid"		# low | mid | high
var temp_c: Array = [16, 28]
var yield_good: String = ""
var yield_min: int = 1
var yield_max: int = 2
var wilt_penalty: float = 0.25
var value: int = 10
var sprite: String = ""

static func from_dict(d: Dictionary) -> PlantDef:
	var p := PlantDef.new()
	p.id = str(d.get("id", ""))
	p.display_name = str(d.get("name", p.id))
	p.stage_days = d.get("stage_days", [2, 3, 4])
	p.water_per_day = float(d.get("water_per_day", 1.0))
	p.light_need = str(d.get("light_need", "mid"))
	p.temp_c = d.get("temp_c", [16, 28])
	p.yield_good = str(d.get("yield_good", ""))
	p.yield_min = int(d.get("yield_min", 1))
	p.yield_max = int(d.get("yield_max", 2))
	p.wilt_penalty = float(d.get("wilt_penalty", 0.25))
	p.value = int(d.get("value", 10))
	p.sprite = str(d.get("sprite", ""))
	return p

func total_days() -> float:
	var total := 0.0
	for d in stage_days:
		total += float(d)
	return total

func is_valid() -> bool:
	return id != "" and stage_days.size() == 3 and water_per_day > 0.0 and yield_good != ""

func to_dict() -> Dictionary:
	return {"id": id, "name": display_name, "stage_days": stage_days,
		"water_per_day": water_per_day, "light_need": light_need, "temp_c": temp_c,
		"yield_good": yield_good, "yield_min": yield_min, "yield_max": yield_max,
		"wilt_penalty": wilt_penalty, "value": value, "sprite": sprite}
