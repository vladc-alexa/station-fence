class_name Barter
extends RefCounted
## Barter maths: goods-for-goods, cash sweetener, rating consequences.

const ACCEPT_RATIO := 0.9
const OFF_WANT_DISCOUNT := 0.6

static func want_value(customer: Customer) -> int:
	var total := 0
	for w in customer.wants:
		total += GoodsDB.value_of(str(w["id"])) * int(w["qty"])
	return total

static func offer_value(offered: Dictionary, customer: Customer = null) -> int:
	var total := 0
	for id in offered.keys():
		var unit := float(GoodsDB.value_of(str(id))) * float(offered[id])
		if customer != null and not _wants(customer, str(id)):
			unit *= OFF_WANT_DISCOUNT
		total += int(round(unit))
	return total

static func _wants(customer: Customer, good_id: String) -> bool:
	for w in customer.wants:
		if str(w["id"]) == good_id:
			return true
	return false

static func threshold(customer: Customer) -> int:
	return int(ceil(float(want_value(customer)) * ACCEPT_RATIO))

static func evaluate(customer: Customer, offered: Dictionary) -> Dictionary:
	var res := {"ok": false, "reason": "", "want_value": 0, "offer_value": 0,
		"cash_gain": 0, "goods_gain": [], "rating_delta": 0.0}
	if customer == null:
		res["reason"] = "no_customer"
		return res
	res["want_value"] = want_value(customer)
	res["offer_value"] = offer_value(offered)
	if int(res["offer_value"]) < threshold(customer):
		res["reason"] = "too_low"
		return res
	res["ok"] = true
	res["cash_gain"] = customer.cash_offer
	res["goods_gain"] = customer.brings
	res["rating_delta"] = 0.7
	return res
