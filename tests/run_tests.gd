extends SceneTree
## Headless unit + integration suite: godot --headless --path . --script res://tests/run_tests.gd

var failures := 0
var checks := 0
var _current := ""

func _initialize() -> void:
	_suite("scripts compile", _test_scripts_load)
	_suite("plant database", _test_plant_db)
	_suite("goods database", _test_goods_db)
	_suite("growth under ideal conditions", _test_grow_ideal)
	_suite("drought and wilting", _test_grow_drought)
	_suite("plant persistence", _test_plant_roundtrip)
	_suite("morning budget", _test_morning)
	_suite("barter maths", _test_barter)
	_suite("rating maths", _test_rating)
	_suite("visitor scaling", _test_visitors)
	_suite("determinism (20 days)", _test_determinism)
	_suite("save/load round trip", _test_save_roundtrip)
	print("")
	print("checks=%d failures=%d" % [checks, failures])
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _suite(name: String, fn: Callable) -> void:
	_current = name
	print("-- %s" % name)
	fn.call()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL [%s] %s" % [_current, message])

func _gs(p_seed: int) -> Node:
	var script: GDScript = load("res://scripts/autoload/game_state.gd")
	var gs: Node = script.new()
	gs.new_run(p_seed)
	return gs

func _test_scripts_load() -> void:
	for path in [
		"res://scripts/core/game_rng.gd", "res://scripts/core/plant_def.gd",
		"res://scripts/core/plant_db.gd", "res://scripts/core/goods_def.gd",
		"res://scripts/core/goods_db.gd", "res://scripts/core/plant.gd",
		"res://scripts/core/grow_sim.gd", "res://scripts/core/morning.gd",
		"res://scripts/core/rating.gd", "res://scripts/core/customer.gd",
		"res://scripts/core/barter.gd", "res://scripts/core/day_cycle.gd", "res://scripts/autoload/game_state.gd",
		"res://scripts/ui/shop_screen.gd",
	]:
		var s = load(path)
		_check(s != null and s.can_instantiate(), "failed to compile %s" % path)

func _test_plant_db() -> void:
	var all := PlantDB.all()
	_check(all.size() == 6, "expected 6 plants, got %d" % all.size())
	for def in all:
		_check(def.is_valid(), "invalid plant def %s" % def.id)
		_check(def.stage_days.size() == 3, "%s needs 3 stage entries" % def.id)
	_check(PlantDB.get_def("crystal_orchid") != null, "crystal_orchid missing")
	_check(PlantDB.get_def("nope") == null, "unknown plant should be null")

func _test_goods_db() -> void:
	_check(GoodsDB.all().size() >= 10, "expected >=10 goods")
	_check(GoodsDB.value_of("orchid_bloom") == 140, "orchid_bloom value")
	_check(GoodsDB.by_category("food").size() >= 3, "food category too small")
	_check(GoodsDB.value_of("nope") == 0, "unknown good value should be 0")

func _test_grow_ideal() -> void:
	var plant := Plant.from_id("lumen_moss")
	var env := {"lamp": false, "water": 2.0, "temp_c": 20.0}
	for i in range(10):
		GrowSim.tick(plant, env)
	_check(plant.stage >= 2, "ideal 10 days should pass stage 2 (got %d)" % plant.stage)
	_check(not plant.wilted, "well-watered plant should not wilt")
	_check(plant.is_harvestable(), "10 ideal days should be harvestable")

func _test_grow_drought() -> void:
	var plant := Plant.from_id("vine_bean")
	var dry := {"lamp": false, "water": 0.0, "temp_c": 20.0}
	var before := 0.0
	for i in range(3):
		GrowSim.tick(plant, dry)
	_check(plant.wilted, "3 dry days should wilt")
	_check(plant.progress < plant.def.total_days(), "wilted plant must not progress to harvest")
	_check(not Plant.from_id("vine_bean").is_harvestable(), "fresh plant not harvestable")

func _test_plant_roundtrip() -> void:
	var plant := Plant.from_id("dew_fern")
	plant.progress = 4.2
	plant.dry_days = 1
	plant.recompute_stage()
	var copy := Plant.from_dict(plant.to_dict())
	_check(copy.def.id == plant.def.id, "id preserved")
	_check(is_equal_approx(copy.progress, 4.2), "progress preserved")
	_check(copy.dry_days == 1, "dry_days preserved")
	_check(copy.stage == plant.stage, "stage preserved")

func _test_morning() -> void:
	var m := Morning.new()
	_check(m.ticks_left == 6, "starts with 6 ticks")
	for i in range(6):
		_check(bool(m.spend("water")["ok"]), "tick %d should succeed" % i)
	_check(not bool(m.spend("water")["ok"]), "7th action must be refused")
	_check(m.spend("water")["reason"] == "budget_exhausted", "reason must be budget_exhausted")
	m.reset()
	_check(m.ticks_left == 6, "reset restores ticks")

func _test_barter() -> void:
	var c := Customer.new()
	c.cash_offer = 30
	c.wants = [{"id": "bean_pod", "qty": 2}]
	c.brings = [{"id": "mineral_chunk", "qty": 1}]
	var want := Barter.want_value(c)
	_check(want == 14, "want value should be 14 (got %d)" % want)
	var low := Barter.evaluate(c, {"scrap_metal": 1})
	_check(not bool(low["ok"]), "cheap offer must be refused")
	_check(low["reason"] == "too_low", "reason should be too_low")
	var good := Barter.evaluate(c, {"bean_pod": 2})
	_check(bool(good["ok"]), "exact offer must be accepted")
	_check(int(good["cash_gain"]) == 30, "cash transferred")
	_check(float(good["rating_delta"]) > 0.0, "accepted trade raises rating")

func _test_rating() -> void:
	var low := Rating.visitors_for(0.0)
	var mid := Rating.visitors_for(48.0)
	var high := Rating.visitors_for(100.0)
	_check(low >= 3, "a fresh shop still gets a minimum trickle (%d)" % low)
	_check(mid > low, "rating 48 brings more traffic than rating 0 (%d > %d)" % [mid, low])
	_check(high >= mid and high <= 10, "traffic is monotonic and capped (%d)" % high)
	_check(Rating.clamp_rating(140.0) == 100.0, "clamped at 100")
	_check(Rating.decay(10.0) == 9.5, "decays 0.5 per day")
	_check(Rating.decay(0.2) == 0.0, "never below zero")
	_check(Rating.tier_unlocked(25.0, 2), "tier 2 unlocked at 25")
	_check(not Rating.tier_unlocked(20.0, 2), "tier 2 locked at 20")

func _test_visitors() -> void:
	var cycle := DayCycle.new(7)
	var low_visitors := cycle.begin_day(0.0)
	_check(low_visitors >= 3, "low rating day still has traffic (%d)" % low_visitors)
	cycle = DayCycle.new(7)
	var high_visitors := cycle.begin_day(90.0)
	_check(high_visitors > low_visitors, "reputation grows traffic (%d > %d)" % [high_visitors, low_visitors])
	var low: Customer = DayCycle.new(3).spawn(0.0)
	_check(low != null and low.tier == 1, "low rating spawns tier 1 only")
	var high_cycle := DayCycle.new(3)
	var saw_tier2 := false
	for i in range(200):
		var c := high_cycle.spawn(80.0)
		if c != null and c.tier == 2:
			saw_tier2 = true
			break
	_check(saw_tier2, "tier 2 customers appear once unlocked")

func _run_scenario(p_seed: int) -> String:
	var gs := _gs(p_seed)
	for d in range(20):
		for b in range(gs.BENCH_COUNT):
			for s in range(gs.SLOT_COUNT):
				gs.water_slot(b, s)
		gs.toggle_lamp(0)
		for b in range(gs.BENCH_COUNT):
			for s in range(gs.SLOT_COUNT):
				gs.harvest_slot(b, s)
		for i in range(10):
			gs.next_customer()
			if gs.current == null:
				break
			gs.trade(gs.offer_for(gs.current))
		gs.end_day()
	var snapshot := JSON.stringify(gs.state_dict())
	gs.free()
	return snapshot

func _test_determinism() -> void:
	var a := _run_scenario(424242)
	var b := _run_scenario(424242)
	_check(a == b, "same seed must produce identical 20-day state")
	var c := _run_scenario(999)
	_check(a != c, "different seed must diverge")

func _test_save_roundtrip() -> void:
	var gs := _gs(11)
	for b in range(gs.BENCH_COUNT):
		for s in range(gs.SLOT_COUNT):
			gs.water_slot(b, s)
	gs.next_customer()
	gs.trade(gs.offer_for(gs.current))
	var snapshot: Dictionary = gs.state_dict()
	var other := _gs(0)
	other.restore(snapshot)
	_check(other.cash == gs.cash, "cash restored")
	_check(other.day == gs.day, "day restored")
	_check(is_equal_approx(other.rating, gs.rating), "rating restored")
	_check(other.goods.keys().size() == gs.goods.keys().size(), "goods restored")
	for b in range(gs.BENCH_COUNT):
		for s in range(gs.SLOT_COUNT):
			var p1 = gs.benches[b]["slots"][s]
			var p2 = other.benches[b]["slots"][s]
			if p1 == null:
				_check(p2 == null, "empty slot restored as empty")
			else:
				_check(p2 != null and p2.def.id == p1.def.id, "plant id restored")
				_check(p2 != null and p2.stage == p1.stage, "plant stage restored")
	gs.free()
	other.free()
