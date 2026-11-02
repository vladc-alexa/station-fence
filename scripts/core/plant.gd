class_name Plant
extends RefCounted
## A live plant instance on a bench slot.

var def: PlantDef
var progress: float = 0.0		# accumulated growth-days
var stage: int = 0			   # 0 seedling .. 3 harvestable
var dry_days: int = 0
var wilted: bool = false

func _init(p_def: PlantDef = null) -> void:
	def = p_def
	if def != null:
		recompute_stage()

static func from_id(id: String) -> Plant:
	var d := PlantDB.get_def(id)
	if d == null:
		push_error("Plant: unknown plant id %s" % id)
		return null
	return Plant.new(d)

func thresholds() -> Array:
	var out: Array = []
	var acc := 0.0
	for d in def.stage_days:
		acc += float(d)
		out.append(acc)
	return out

func recompute_stage() -> void:
	var th := thresholds()
	stage = 0
	for i in range(th.size()):
		if progress >= float(th[i]) - 0.0001:
			stage = i + 1

func is_harvestable() -> bool:
	return stage >= 3 and not wilted

func harvest(rng: GameRNG) -> Dictionary:
	if not is_harvestable():
		return {"ok": false, "good": "", "qty": 0}
	var good := def.yield_good
	var qty := rng.randi_range(def.yield_min, def.yield_max)
	progress = 0.0
	stage = 0
	dry_days = 0
	wilted = false
	return {"ok": true, "good": good, "qty": qty}

func to_dict() -> Dictionary:
	return {"id": def.id, "progress": progress, "dry_days": dry_days, "wilted": wilted}

static func from_dict(d: Dictionary) -> Plant:
	var p := Plant.from_id(str(d.get("id", "")))
	if p == null:
		return null
	p.progress = float(d.get("progress", 0.0))
	p.dry_days = int(d.get("dry_days", 0))
	p.wilted = bool(d.get("wilted", false))
	p.recompute_stage()
	return p
