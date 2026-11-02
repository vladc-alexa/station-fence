class_name Rating
extends RefCounted
## Shop rating drives traffic, tiers and quest unlocks.

const MAX_RATING := 100.0
const MIN_RATING := 0.0

static func clamp_rating(value: float) -> float:
	return clampf(value, MIN_RATING, MAX_RATING)

static func decay(value: float, amount: float = 0.5) -> float:
	return clamp_rating(value - amount)

static func visitors_for(rating: float) -> int:
	return clampi(4 + int(floor(rating / 10.0)), 4, 8)

static func tier_unlocked(rating: float, tier: int) -> bool:
	if tier <= 1:
		return true
	return rating >= 25.0
