class_name DayCycle
extends RefCounted
## Who walks through the door today, and what the shop costs to keep.

const PATH := "res://data/customers.json"
const TIER2_RATING := 20.0

static var _archetypes: Array = []

var rng: GameRNG
var day: int = 1
var visitors_left: int = 0

func _init(seed_value: int = 0) -> void:
	rng = GameRNG.new(seed_value)

static func archetypes() -> Array:
	if not _archetypes.is_empty():
		return _archetypes
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("DayCycle: cannot open %s" % PATH)
		return _archetypes
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_ARRAY:
		_archetypes = parsed
	return _archetypes

static func rent_for_day(d: int) -> int:
	return 40 + 6 * d

func begin_day(rating: float) -> int:
	visitors_left = Rating.visitors_for(rating)
	return visitors_left

func spawn(rating: float) -> Customer:
	var pool: Array = []
	for a in archetypes():
		if Rating.tier_unlocked(rating, int(a.get("tier", 1))):
			pool.append(a)
	if pool.is_empty():
		return null
	var def: Dictionary = rng.pick(pool)
	return Customer.from_def(def, rng)

func consume_visitor() -> void:
	visitors_left = maxi(0, visitors_left - 1)

func day_over() -> bool:
	return visitors_left <= 0
