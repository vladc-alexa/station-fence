extends Node
## Authoritative run state: benches, goods, cash, rating, day.

signal state_changed
signal log_line(text: String)
signal run_over(reason: String)

const SAVE_PATH := "user://greenhouse_save.json"
const BENCH_COUNT := 3
const SLOT_COUNT := 2
const START_CASH := 400
const AMBIENT_LIGHT := 0.35
const LAMP_LIGHT := 1.2
const WATER_PER_ACTION := 1.2
const WATER_CAP := 3.0
const ROOM_TEMP := 21.0

var seed_value: int = 0
var cash: int = START_CASH
var day: int = 1
var rating: float = 0.0
var morning: Morning = Morning.new()
var benches: Array = []
var goods: Dictionary = {}
var rng: GameRNG = GameRNG.new(0)
var cycle: DayCycle = DayCycle.new(0)
var current: Customer = null
var visitors_left: int = 0
var over: bool = false

func _ready() -> void:
	new_run(int(Time.get_unix_time_from_system()) % 100000)

func new_run(p_seed: int) -> void:
	seed_value = p_seed
	rng = GameRNG.new(p_seed)
	cycle = DayCycle.new(p_seed)
	cash = START_CASH
	day = 1
	rating = 5.0
	over = false
	current = null
	goods = {"kelp_syrup": 4, "bean_pod": 4, "glow_sap": 4, "water_canister": 1}
	benches = []
	var starters := ["lumen_moss", "vine_bean", "brine_kelp", "ember_pepper", "dew_fern", "crystal_orchid"]
	for b in range(BENCH_COUNT):
		var slots: Array = []
		for s in range(SLOT_COUNT):
			slots.append(null)
		for s2 in range(SLOT_COUNT):
			var idx := b * SLOT_COUNT + s2
			if idx < starters.size():
				var p := Plant.from_id(starters[idx])
				p.progress = 1.0
				p.recompute_stage()
				slots[s2] = p
		benches.append({"lamp": false, "water": 1.0, "slots": slots})
	morning = Morning.new()
	visitors_left = cycle.begin_day(rating)
	state_changed.emit()

func bench_light(bench_index: int) -> float:
	var lamp: bool = bool(benches[bench_index]["lamp"])
	return 1.25 if lamp else 1.0

func water_slot(bench_index: int, slot_index: int) -> Dictionary:
	if over:
		return {"ok": false, "reason": "run_over"}
	if benches[bench_index]["slots"][slot_index] == null:
		return {"ok": false, "reason": "empty_slot"}
	var spend := morning.spend("water")
	if not bool(spend["ok"]):
		return spend
	benches[bench_index]["water"] = minf(WATER_CAP, float(benches[bench_index]["water"]) + WATER_PER_ACTION)
	state_changed.emit()
	return {"ok": true, "water": benches[bench_index]["water"], "ticks_left": morning.ticks_left}

func toggle_lamp(bench_index: int) -> Dictionary:
	if over:
		return {"ok": false, "reason": "run_over"}
	var spend := morning.spend("lamp")
	if not bool(spend["ok"]):
		return spend
	benches[bench_index]["lamp"] = not bool(benches[bench_index]["lamp"])
	state_changed.emit()
	return {"ok": true, "lamp": benches[bench_index]["lamp"], "ticks_left": morning.ticks_left}

func harvest_slot(bench_index: int, slot_index: int) -> Dictionary:
	var plant = benches[bench_index]["slots"][slot_index]
	if plant == null:
		return {"ok": false, "reason": "empty_slot"}
	var res: Dictionary = plant.harvest(rng)
	if bool(res["ok"]):
		goods[str(res["good"])] = int(goods.get(str(res["good"]), 0)) + int(res["qty"])
		log_line.emit("Harvested %d %s" % [int(res["qty"]), str(res["good"])])
		state_changed.emit()
	return res

func next_customer() -> Customer:
	if over:
		return null
	if current != null:
		rating = Rating.clamp_rating(rating - 1.0)
		current = null
	if visitors_left <= 0:
		state_changed.emit()
		return null
	current = cycle.spawn(rating)
	state_changed.emit()
	return current

func offer_for(customer: Customer) -> Dictionary:
	var offered := {}
	if customer == null:
		return offered
	for w in customer.wants:
		var id := str(w["id"])
		var want_qty := int(w["qty"])
		var have := int(goods.get(id, 0))
		var qty := mini(want_qty, have)
		if qty > 0:
			offered[id] = qty
	# Upsell: fill the gap with other stock (Barter values it at a discount).
	var short_by := Barter.threshold(customer) - Barter.offer_value(offered, customer)
	if short_by > 0:
		var ids := goods.keys()
		ids.sort()
		for gid in ids:
			if short_by <= 0:
				break
			var g := str(gid)
			if offered.has(g):
				continue
			var unit := int(round(float(GoodsDB.value_of(g)) * Barter.OFF_WANT_DISCOUNT))
			if unit <= 0:
				continue
			for n in range(int(goods.get(g, 0))):
				if short_by <= 0:
					break
				offered[g] = int(offered.get(g, 0)) + 1
				short_by -= unit
	return offered

func trade(offered: Dictionary) -> Dictionary:
	if current == null:
		return {"ok": false, "reason": "no_customer"}
	var res := Barter.evaluate(current, offered)
	if not bool(res["ok"]):
		return res
	for id in offered.keys():
		var left := int(goods.get(str(id), 0)) - int(offered[id])
		if left <= 0:
			goods.erase(str(id))
		else:
			goods[str(id)] = left
	cash += int(res["cash_gain"])
	for g in res["goods_gain"]:
		var gid := str(g["id"])
		goods[gid] = int(goods.get(gid, 0)) + int(g["qty"])
	rating = Rating.clamp_rating(rating + float(res["rating_delta"]))
	cycle.consume_visitor()
	current = null
	state_changed.emit()
	return res

func end_day() -> Dictionary:
	if over:
		return {"ok": false, "reason": "run_over"}
	var upkeep := DayCycle.rent_for_day(day)
	for b in range(benches.size()):
		var env := {"lamp": bool(benches[b]["lamp"]), "water": float(benches[b]["water"]), "temp_c": ROOM_TEMP}
		for s in range(SLOT_COUNT):
			var plant = benches[b]["slots"][s]
			if plant != null:
				GrowSim.tick(plant, env)
		benches[b]["water"] = maxf(0.0, float(benches[b]["water"]) - 1.0)
	rating = Rating.clamp_rating(Rating.decay(rating))
	cash -= upkeep
	day += 1
	cycle.day = day
	morning.reset()
	visitors_left = cycle.begin_day(rating)
	current = null
	var summary := {"ok": true, "upkeep": upkeep, "cash": cash, "day": day,
		"rating": rating, "visitors": visitors_left}
	if cash < 0:
		over = true
		run_over.emit("broke")
	log_line.emit("Day %d — upkeep %d paid. %d visitors expected." % [day, upkeep, visitors_left])
	state_changed.emit()
	return summary

func state_dict() -> Dictionary:
	var bench_data: Array = []
	for b in benches:
		var slots: Array = []
		for s in b["slots"]:
			slots.append(null if s == null else s.to_dict())
		bench_data.append({"lamp": b["lamp"], "water": b["water"], "slots": slots})
	return {"version": 2, "seed": seed_value, "cash": cash, "day": day,
		"rating": rating, "goods": goods, "benches": bench_data,
		"ticks_left": morning.ticks_left}

func restore(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	rng = GameRNG.new(seed_value)
	cycle = DayCycle.new(seed_value)
	cash = int(data.get("cash", START_CASH))
	day = int(data.get("day", 1))
	rating = float(data.get("rating", 0.0))
	goods = data.get("goods", {})
	morning = Morning.new()
	morning.ticks_left = int(data.get("ticks_left", Morning.TICKS))
	benches = []
	for b in data.get("benches", []):
		var slots: Array = []
		for s in b.get("slots", []):
			slots.append(null if s == null else Plant.from_dict(s))
		benches.append({"lamp": bool(b.get("lamp", false)), "water": float(b.get("water", 1.0)), "slots": slots})
	visitors_left = cycle.begin_day(rating)
	current = null
	over = cash < 0
	state_changed.emit()

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state_dict(), "  "))
	f.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	restore(parsed)
	return true
