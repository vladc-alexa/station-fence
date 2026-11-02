class_name GrowSim
extends RefCounted
## One day of growth for one plant. Deliberately simple and legible:
## daily growth = light_factor x water_factor x temp_factor, capped at 1.0.

const LIGHT_FACTOR := {
	"low": {"off": 1.0, "on": 0.7},
	"mid": {"off": 1.0, "on": 0.85},
	"high": {"off": 0.6, "on": 1.0},
}
const DRY_LIMIT := 2

static func light_factor(need: String, lamp_on: bool) -> float:
	var row: Dictionary = LIGHT_FACTOR.get(need, LIGHT_FACTOR["mid"])
	return float(row["on"] if lamp_on else row["off"])

static func water_factor(plant: Plant, water_units: float) -> float:
	var need: float = maxf(plant.def.water_per_day, 0.01)
	return clampf(water_units / need, 0.4, 1.0)

static func temp_factor(plant: Plant, temp_c: float) -> float:
	var lo := float(plant.def.temp_c[0])
	var hi := float(plant.def.temp_c[1])
	if temp_c < lo or temp_c > hi:
		return 0.7
	return 1.0

static func tick(plant: Plant, env: Dictionary) -> Dictionary:
	var lamp: bool = bool(env.get("lamp", false))
	var lf := light_factor(plant.def.light_need, lamp)
	var wf := water_factor(plant, float(env.get("water", 0.0)))
	var tf := temp_factor(plant, float(env.get("temp_c", 21.0)))
	if wf < 0.6:
		plant.dry_days += 1
	else:
		plant.dry_days = 0
	var wilted := false
	if plant.dry_days >= DRY_LIMIT and not plant.wilted:
		plant.wilted = true
		wilted = true
		plant.progress = maxf(0.0, plant.progress * (1.0 - plant.def.wilt_penalty))
	if plant.wilted:
		plant.progress = maxf(0.0, plant.progress - 0.5)
	var gained: float = lf * wf * tf
	plant.progress = maxf(0.0, plant.progress + gained)
	plant.recompute_stage()
	return {"light": lf, "water": wf, "temp": tf, "gained": gained,
		"wilted": wilted, "stage": plant.stage}
