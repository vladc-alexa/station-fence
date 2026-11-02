class_name GameRNG
extends RefCounted
## Deterministic RNG wrapper: same seed => same run (tests + replays).

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func chance(probability: float) -> bool:
	return _rng.randf() < probability

func pick(options: Array):
	if options.is_empty():
		return null
	return options[_rng.randi_range(0, options.size() - 1)]
