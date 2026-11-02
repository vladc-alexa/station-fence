extends Node
## Run-level state + the glue between pure core classes and the UI.
## Autoloaded as `GameState`.

signal state_changed
signal log_line(text: String)
signal run_over(reason: String)

const HEAT_DECAY_PER_DAY := 8.0
const SAVE_PATH := "user://save_01.json"
const START_CASH := 500

var seed_value: int = 1337
var cash: int = START_CASH
var day: int = 1
var reputation: int = 0
var heat: float = 0.0
var inspection_skill: int = 1
var inventory: Array = []
var cycle: DayCycle
var current: Customer = null
var roll_counter: int = 0
var is_over: bool = false

func _ready() -> void:
	if cycle == null:
		new_run()

func new_run(run_seed: int = 1337) -> void:
	seed_value = run_seed
	cash = START_CASH
	day = 1
	reputation = 0
	heat = 0.0
	inspection_skill = 1
	inventory = []
	roll_counter = 0
	is_over = false
	cycle = DayCycle.new(seed_value)
	cycle.begin_day()
	current = null
	_emit()

func sim_state() -> Dictionary:
	return {"cash": cash, "heat": heat, "day": day, "roll_counter": roll_counter}

func apply_sim_state(s: Dictionary) -> void:
	cash = int(s.get("cash", cash))
	heat = float(s.get("heat", heat))
	day = int(s.get("day", day))
	roll_counter = int(s.get("roll_counter", roll_counter))

func next_customer() -> Customer:
	if is_over:
		return null
	if cycle.day_over():
		log_line.emit("The shutters are down. End the day.")
		return null
	cycle.advance_time(1)
	current = cycle.spawn_customer(heat, reputation)
	if current != null:
		var verb := "browsing" if current.wants_to_buy() else "selling"
		log_line.emit("%s walks in, %s." % [current.display_name, verb])
	_emit()
	return current

## Buy the item the current customer is offering.
func buy_offer(price: int) -> Dictionary:
	if current == null or current.offer_item == null:
		return {"ok": false, "reason": "no_offer"}
	var s := sim_state()
	var res := Deal.buy_from_customer(s, current, current.offer_item, price)
	apply_sim_state(s)
	if res["ok"]:
		cash -= int(res["price"])
		inventory.append(current.offer_item)
		current.offer_item = null
		_after_deal(res, "Bought for %d credits" % int(res["price"]))
	elif res["seized"]:
		_after_deal(res, "Busted. Goods seized.")
	return res

## Sell shelf item at `index` to the current customer.
func sell_item(index: int, price: int) -> Dictionary:
	if current == null or index < 0 or index >= inventory.size():
		return {"ok": false, "reason": "no_item"}
	var item = inventory[index]
	var s := sim_state()
	var res := Deal.sell_to_customer(s, current, item, price)
	apply_sim_state(s)
	if res["ok"]:
		cash += int(res["price"])
		inventory.remove_at(index)
		_after_deal(res, "Sold for %d credits" % int(res["price"]))
	elif res["seized"]:
		inventory.remove_at(index)
		_after_deal(res, "Busted. Item seized.")
	return res

func _after_deal(res: Dictionary, text: String) -> void:
	reputation += int(res["rep"])
	heat = clampf(heat + float(res["heat"]), 0.0, 100.0)
	log_line.emit(text)
	if reputation < -20:
		is_over = true
		run_over.emit("Reputation collapsed. The station blacklists you.")
	_emit()

func end_day() -> Dictionary:
	var summary := cycle.close_day(cash)
	if summary["paid"]:
		cash -= int(summary["rent"])
		day = cycle.day
		heat = maxf(0.0, heat - HEAT_DECAY_PER_DAY)
		log_line.emit("Rent paid: -%d credits. Heat -%.0f. Day %d begins." % [
			int(summary["rent"]), HEAT_DECAY_PER_DAY, day])
		cycle.begin_day()
		current = null
	else:
		is_over = true
		log_line.emit("You cannot cover rent (%d). Evicted." % int(summary["rent"]))
		run_over.emit("Evicted: rent unpaid.")
	_emit()
	return summary

func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(SaveGame.to_json({
		"seed": seed_value, "day": day, "cash": cash, "reputation": reputation,
		"heat": heat, "inspection_skill": inspection_skill, "inventory": inventory,
	}))
	f.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data := SaveGame.from_json(text)
	if data.is_empty():
		return false
	seed_value = int(data["seed"])
	day = int(data["day"])
	cash = int(data["cash"])
	reputation = int(data["reputation"])
	heat = float(data["heat"])
	inspection_skill = int(data["inspection_skill"])
	inventory = data["inventory"]
	cycle = DayCycle.new(seed_value)
	cycle.day = day
	cycle.begin_day()
	current = null
	is_over = false
	_emit()
	return true

func _emit() -> void:
	state_changed.emit()
