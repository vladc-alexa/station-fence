class_name Customer
extends RefCounted
## One visitor: selling something to you, or buying from your shelf.

enum Archetype { WALKER, DESPERATE, COLLECTOR, UNDERCOVER }

var archetype: int = Archetype.WALKER
var display_name: String = "Unknown"
var budget: int = 100
var patience: int = 3
var offer_item: ItemInstance = null
var wants_category: String = ""
var ask_ratio: float = 0.7   # what they ask for their own goods, vs. real value

func wants_to_buy() -> bool:
	return offer_item == null

func perceived_value(item: ItemInstance) -> int:
	# Retail: what a buyer will pay over the item's real value.
	var arch_mult: float = 1.08
	match archetype:
		Archetype.DESPERATE:
			arch_mult = 0.95
		Archetype.COLLECTOR:
			arch_mult = 1.25
	var want_bonus := 1.12 if item.def.category == wants_category else 1.0
	return int(round(item.true_value * arch_mult * want_bonus))

func asking_price() -> int:
	if offer_item == null:
		return 0
	return maxi(1, int(round(offer_item.true_value * ask_ratio)))
