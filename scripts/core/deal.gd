class_name Deal
extends RefCounted
## Pure negotiation + consequence resolution. No scene or singleton dependency.
##
## Economy invariants (asserted by tests):
##  - buying below true value is profitable, buying above it is not
##  - contraband raises heat, legal goods do not
##  - an undercover customer seizes goods instead of paying

const HEAT_PER_CONTRABAND_SALE := 12.0
const UNDERCOVER_BASE_CHANCE := 0.06

## Player buys `item` from `customer` at `price`.
static func buy_from_customer(state: Dictionary, customer: Customer, item: ItemInstance, price: int) -> Dictionary:
	var result := {"ok": false, "reason": "", "price": 0, "heat": 0.0, "rep": 0, "seized": false}
	if customer == null or item == null:
		result["reason"] = "no_deal"
		return result
	if customer.archetype == Customer.Archetype.UNDERCOVER and not item.def.legal:
		result["reason"] = "undercover"
		result["seized"] = true
		result["heat"] = 35.0
		result["rep"] = -6
		return result
	var floor_ratio := 0.75 if customer.archetype == Customer.Archetype.DESPERATE else 0.9
	var floor_price := int(round(float(customer.asking_price()) * floor_ratio))
	if price < floor_price:
		result["reason"] = "lowball"
		return result
	if price > int(state.get("cash", 0)):
		result["reason"] = "no_cash"
		return result
	result["ok"] = true
	result["price"] = price
	result["rep"] = 1
	result["heat"] = 4.0 if item.hot else 0.0
	return result

## Player sells `item` from the shelf to `customer` at `price`.
static func sell_to_customer(state: Dictionary, customer: Customer, item: ItemInstance, price: int) -> Dictionary:
	var result := {"ok": false, "reason": "", "price": 0, "heat": 0.0, "rep": 0, "seized": false}
	if customer == null or item == null:
		result["reason"] = "no_deal"
		return result
	var busted := customer.archetype == Customer.Archetype.UNDERCOVER
	if not busted and not item.def.legal:
		var heat := float(state.get("heat", 0.0))
		busted = _roll(state, UNDERCOVER_BASE_CHANCE + heat * 0.004)
	if busted:
		result["reason"] = "undercover"
		result["seized"] = true
		result["heat"] = 30.0
		result["rep"] = -5
		return result
	var ceiling := mini(customer.perceived_value(item), customer.budget)
	if price > ceiling:
		result["reason"] = "too_expensive"
		return result
	result["ok"] = true
	result["price"] = price
	result["rep"] = 1
	if not item.def.legal:
		result["heat"] = HEAT_PER_CONTRABAND_SALE * item.def.heat_weight
	return result

## Stable roll derived from run state so a seed replays identically.
static func _roll(state: Dictionary, probability: float) -> bool:
	var counter := int(state.get("roll_counter", 0))
	state["roll_counter"] = counter + 1
	var h := absi(hash([counter, int(state.get("day", 1)), int(state.get("cash", 0))]))
	return float(h % 10000) / 10000.0 < probability
