extends SceneTree
## Headless test runner (no addons):
##   ~/tools/godot --headless --path . --script res://tests/run_tests.gd

var checks := 0
var failures := 0
var _current := ""

func _initialize() -> void:
	_suite("scripts compile", _test_scripts_load)
	_suite("item database", _test_item_db)
	_suite("deterministic spawns", _test_determinism)
	_suite("item rolling", _test_item_roll)
	_suite("appraisal accuracy", _test_estimate)
	_suite("buy negotiation", _test_buy)
	_suite("sell negotiation", _test_sell)
	_suite("contraband + heat", _test_heat)
	_suite("undercover bust", _test_undercover)
	_suite("day + rent", _test_day)
	_suite("save/load roundtrip", _test_save)
	_suite("economy over 10 days", _test_economy)

	print("")
	print("checks=%d failures=%d" % [checks, failures])
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _suite(title: String, fn: Callable) -> void:
	_current = title
	fn.call()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL [%s] %s" % [_current, message])

func _test_scripts_load() -> void:
	for path in [
		"res://scripts/core/game_rng.gd", "res://scripts/core/item_def.gd",
		"res://scripts/core/item_db.gd", "res://scripts/core/item_instance.gd",
		"res://scripts/core/customer.gd", "res://scripts/core/deal.gd",
		"res://scripts/core/day_cycle.gd", "res://scripts/core/save_game.gd",
		"res://scripts/autoload/game_state.gd",
	]:
		var s = load(path)
		_check(s != null and s.can_instantiate(), "failed to compile %s" % path)

func _test_item_db() -> void:
	var all := ItemDB.all()
	_check(all.size() >= 8, "expected >=8 items, got %d" % all.size())
	var pistol := ItemDB.get_def("scrubbed_pistol")
	_check(pistol != null, "scrubbed_pistol missing")
	if pistol != null:
		_check(not pistol.legal, "pistol should be illegal")
		_check(pistol.base_value == 340, "pistol base_value wrong")

func _test_determinism() -> void:
	var a := DayCycle.new(4242)
	var b := DayCycle.new(4242)
	var state := {"cash": 500, "heat": 0.0, "day": 1, "roll_counter": 0}
	for i in range(6):
		var ca := a.spawn_customer(0.0, 0)
		var cb := b.spawn_customer(0.0, 0)
		_check(ca.display_name == cb.display_name, "name mismatch at %d" % i)
		_check(ca.archetype == cb.archetype, "archetype mismatch at %d" % i)
		_check(ca.budget == cb.budget, "budget mismatch at %d" % i)
		if ca.offer_item != null and cb.offer_item != null:
			_check(ca.offer_item.def.id == cb.offer_item.def.id, "offer id mismatch at %d" % i)
			_check(ca.offer_item.true_value == cb.offer_item.true_value, "offer value mismatch at %d" % i)
	_check(state["cash"] == 500, "state untouched")

func _test_item_roll() -> void:
	var rng := GameRNG.new(7)
	var def := ItemDB.get_def("drone_battery")
	for i in range(40):
		var item := ItemInstance.roll(def, rng)
		_check(item.true_value > 0, "non-positive value")
		_check(item.condition >= def.condition_min - 0.001, "condition below min")
		_check(item.condition <= def.condition_max + 0.001, "condition above max")

func _test_estimate() -> void:
	var rng := GameRNG.new(11)
	var def := ItemDB.get_def("scrubbed_pistol")
	var item := ItemInstance.roll(def, rng)
	var rough: Dictionary = item.estimate(0, rng)
	_check(rough["low"] < rough["high"], "rough estimate should be a range")
	_check(not rough["exact"], "skill 0 should not be exact on difficulty 3")
	var precise: Dictionary = item.estimate(5, rng)
	_check(precise["exact"], "high skill should be exact")
	_check(precise["low"] <= item.true_value and item.true_value <= precise["high"], "value outside band")

func _test_buy() -> void:
	var rng := GameRNG.new(3)
	var def := ItemDB.get_def("neon_sign")
	var c := Customer.new()
	c.archetype = Customer.Archetype.WALKER
	c.offer_item = ItemInstance.roll(def, rng)
	c.ask_ratio = 0.7
	var state := {"cash": 500, "heat": 0.0, "day": 1, "roll_counter": 0}
	var low := Deal.buy_from_customer(state, c, c.offer_item, int(c.asking_price() * 0.5))
	_check(not low["ok"], "lowball should be refused")
	_check(low["reason"] == "lowball", "expected lowball reason, got %s" % low["reason"])
	var fair := Deal.buy_from_customer(state, c, c.offer_item, c.asking_price())
	_check(fair["ok"], "ask price should be accepted (%s)" % fair["reason"])
	var broke := {"cash": 5, "heat": 0.0, "day": 1, "roll_counter": 0}
	var nocash := Deal.buy_from_customer(broke, c, c.offer_item, c.asking_price())
	_check(not nocash["ok"] and nocash["reason"] == "no_cash", "should fail on cash")

func _test_sell() -> void:
	var rng := GameRNG.new(5)
	var def := ItemDB.get_def("synth_whiskey")
	var item := ItemInstance.roll(def, rng)
	var c := Customer.new()
	c.archetype = Customer.Archetype.WALKER
	c.budget = 9999
	var state := {"cash": 100, "heat": 0.0, "day": 1, "roll_counter": 0}
	var greedy := Deal.sell_to_customer(state, c, item, c.perceived_value(item) + 200)
	_check(not greedy["ok"] and greedy["reason"] == "too_expensive", "overpriced sale should fail")
	var ok := Deal.sell_to_customer(state, c, item, c.perceived_value(item))
	_check(ok["ok"], "fair sale should pass (%s)" % ok["reason"])
	_check(ok["heat"] == 0.0, "legal sale should not raise heat")

func _test_heat() -> void:
	var rng := GameRNG.new(9)
	var def := ItemDB.get_def("fake_id_chip")
	var item := ItemInstance.roll(def, rng)
	var c := Customer.new()
	c.archetype = Customer.Archetype.WALKER
	c.budget = 99999
	var state := {"cash": 100, "heat": 0.0, "day": 1, "roll_counter": 0}
	var res := Deal.sell_to_customer(state, c, item, c.perceived_value(item))
	if res["ok"]:
		_check(res["heat"] > 0.0, "contraband sale must raise heat")
	else:
		_check(res["reason"] == "undercover", "only undercover may block contraband (%s)" % res["reason"])

func _test_undercover() -> void:
	var rng := GameRNG.new(13)
	var item := ItemInstance.roll(ItemDB.get_def("neon_sign"), rng)
	var c := Customer.new()
	c.archetype = Customer.Archetype.UNDERCOVER
	c.offer_item = item
	c.budget = 9999
	var state := {"cash": 900, "heat": 0.0, "day": 1, "roll_counter": 0}
	var legal_buy := Deal.buy_from_customer(state, c, item, item.true_value)
	_check(not legal_buy["seized"], "undercover won't seize legal goods")
	var hot_item := ItemInstance.roll(ItemDB.get_def("scrubbed_pistol"), rng)
	var buy := Deal.buy_from_customer(state, c, hot_item, hot_item.true_value)
	_check(not buy["ok"] and buy["seized"], "undercover buy of contraband should seize")
	c.offer_item = null
	var sell := Deal.sell_to_customer(state, c, item, item.true_value)
	_check(not sell["ok"] and sell["seized"], "undercover sale should seize")

func _test_day() -> void:
	var cycle := DayCycle.new(1)
	cycle.begin_day()
	for i in range(20):
		cycle.advance_time(1)
	_check(cycle.day_over(), "day should end after its length")
	var summary := cycle.close_day(10000)
	_check(summary["paid"], "cash 10000 should cover rent")
	_check(summary["rent"] == DayCycle.rent_for_day(1), "rent formula mismatch")
	_check(cycle.day == 2, "day should advance")
	var poor := DayCycle.new(1)
	var evicted := poor.close_day(0)
	_check(evicted["game_over"], "no cash should mean eviction")

func _test_save() -> void:
	var rng := GameRNG.new(21)
	var inv: Array = []
	for i in range(3):
		inv.append(ItemInstance.roll(ItemDB.get_def("drone_battery"), rng))
	var state := {
		"seed": 21, "day": 4, "cash": 812, "reputation": 3, "heat": 12.5,
		"inspection_skill": 2, "inventory": inv,
	}
	var text := SaveGame.to_json(state)
	var back := SaveGame.from_json(text)
	_check(int(back["cash"]) == 812, "cash lost in save")
	_check(int(back["day"]) == 4, "day lost in save")
	_check(is_equal_approx(float(back["heat"]), 12.5), "heat lost in save")
	_check(back["inventory"].size() == 3, "inventory size lost in save")
	if back["inventory"].size() == 3:
		_check(back["inventory"][0].def.id == inv[0].def.id, "item id lost in save")
		_check(back["inventory"][0].true_value == inv[0].true_value, "item value lost in save")

func _test_economy() -> void:
	# A competent-player strategy: buy only under market, hold stock until a buyer
	# pays at least 15% over cost, keep one day of rent in reserve.
	var cycle := DayCycle.new(2026)
	var state := {"cash": 500, "heat": 0.0, "day": 1, "roll_counter": 0}
	var shelf: Array = []
	var basis: Array = []
	var spent := 0
	var earned := 0
	var skill := 2
	for d in range(10):
		cycle.begin_day()
		var reserve := DayCycle.rent_for_day(cycle.day)
		var guard := 0
		while not cycle.day_over() and guard < 60:
			guard += 1
			cycle.advance_time(1)
			var c: Customer = cycle.spawn_customer(float(state["heat"]), 0)
			if c == null:
				break
			if c.offer_item != null:
				var est: Dictionary = c.offer_item.estimate(skill, cycle.rng)
				var ask := c.asking_price()
				var cap: int = int(round(float(est["low"]) * 0.92))
				if ask <= cap and int(state["cash"]) - ask >= reserve and shelf.size() < 12:
					if Deal.buy_from_customer(state, c, c.offer_item, ask)["ok"]:
						state["cash"] = int(state["cash"]) - ask
						spent += ask
						shelf.append(c.offer_item)
						basis.append(ask)
			elif not shelf.is_empty():
				var best := -1
				var best_price := 0
				for i in range(shelf.size()):
					var p: int = mini(c.perceived_value(shelf[i]), c.budget)
					if p >= int(basis[i]) * 1.15 and p > best_price:
						best = i
						best_price = p
				if best >= 0:
					var item = shelf[best]
					var res: Dictionary = Deal.sell_to_customer(state, c, item, best_price)
					if res["ok"]:
						state["cash"] = int(state["cash"]) + best_price
						earned += best_price
						shelf.remove_at(best)
						basis.remove_at(best)
					elif res.get("seized", false):
						shelf.remove_at(best)
						basis.remove_at(best)
		state["cash"] = int(state["cash"]) - DayCycle.rent_for_day(cycle.day)
		cycle.day += 1
	print("  [economy] spent=%d earned=%d cash=%d stock=%d" % [spent, earned, int(state["cash"]), shelf.size()])
	_check(earned > 0, "no sales completed at all")
	_check(earned > spent, "gross sales (%d) must exceed stock cost (%d)" % [earned, spent])
	_check(int(state["cash"]) > 0, "strategy must not go bankrupt (cash=%d)" % int(state["cash"]))

