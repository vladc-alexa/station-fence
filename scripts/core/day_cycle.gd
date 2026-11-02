class_name DayCycle
extends RefCounted
## Day/schedule driver: who walks in, what rent costs, when the day ends.
## Deterministic for a given seed.

const NAMES := ["Rix", "Mora", "Tav", "Juno", "Kesh", "Bel", "Odo", "Sable", "Wren", "Hax"]
const CATEGORIES := ["medical", "tech", "cyberware", "luxury", "weapon", "forgery", "salvage", "food"]

var rng: GameRNG
var day: int = 1
var day_length_minutes: int = 16   # visitors per day
var minutes_remaining: int = 16
var spawn_index: int = 0

func _init(seed_value: int = 0) -> void:
	rng = GameRNG.new(seed_value)

static func rent_for_day(d: int) -> int:
	return 70 + 12 * d

func begin_day() -> void:
	minutes_remaining = day_length_minutes
	spawn_index = 0

func day_over() -> bool:
	return minutes_remaining <= 0

## Burn time; returns true when the day has just ended.
func advance_time(minutes: int) -> bool:
	minutes_remaining = maxi(0, minutes_remaining - minutes)
	return day_over()

func spawn_customer(heat: float, reputation: int) -> Customer:
	var c := Customer.new()
	spawn_index += 1
	c.display_name = str(rng.pick(NAMES))

	var r := rng.randf()
	if r < 0.08 + heat * 0.004:
		c.archetype = Customer.Archetype.UNDERCOVER
		c.display_name = "Inspector"
	elif r < 0.38:
		c.archetype = Customer.Archetype.DESPERATE
	elif r < 0.62:
		c.archetype = Customer.Archetype.COLLECTOR
	else:
		c.archetype = Customer.Archetype.WALKER

	c.wants_category = str(rng.pick(CATEGORIES))
	c.budget = 80 + rng.randi_range(0, 420) + maxi(0, reputation) * 6
	c.patience = 3 if c.archetype == Customer.Archetype.WALKER else 2
	# Sellers in a pawnshop ask UNDER market value: that gap is the player's margin.
	match c.archetype:
		Customer.Archetype.DESPERATE:
			c.ask_ratio = snappedf(rng.randf_range(0.45, 0.62), 0.01)
		Customer.Archetype.COLLECTOR:
			c.ask_ratio = snappedf(rng.randf_range(0.80, 0.98), 0.01)
		_:
			c.ask_ratio = snappedf(rng.randf_range(0.62, 0.82), 0.01)

	# ~45% of visitors are sellers, the rest are buyers.
	if rng.chance(0.45):
		var defs := ItemDB.all()
		var def = rng.pick(defs)
		if def != null:
			c.offer_item = ItemInstance.roll(def, rng)
	return c

## Pay rent, roll into the next day.
func close_day(cash: int) -> Dictionary:
	var rent := rent_for_day(day)
	var paid := cash >= rent
	var summary := {
		"day": day,
		"rent": rent,
		"paid": paid,
		"game_over": not paid,
	}
	if paid:
		day += 1
		begin_day()
	return summary
