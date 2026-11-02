class_name Customer
extends RefCounted
## A visitor at the counter: brings goods (and a little cash), wants specific produce.

var archetype: String = "miner"
var display_name: String = "Visitor"
var tier: int = 1
var cash_offer: int = 0
var wants: Array = []	  # [{ "id": String, "qty": int }]
var brings: Array = []	 # [{ "id": String, "qty": int }]
var quip: String = ""

func wants_text() -> String:
	var parts: Array = []
	for w in wants:
		parts.append("%s x%d" % [str(w["id"]), int(w["qty"])])
	return ", ".join(parts) if not parts.is_empty() else "-"

func brings_text() -> String:
	var parts: Array = []
	for g in brings:
		parts.append("%s x%d" % [str(g["id"]), int(g["qty"])])
	return ", ".join(parts) if not parts.is_empty() else "-"

static func brings_value(c: Customer) -> int:
	var total := 0
	for g in c.brings:
		total += GoodsDB.value_of(str(g["id"])) * int(g["qty"])
	return total

static func from_def(d: Dictionary, rng: GameRNG) -> Customer:
	var c := Customer.new()
	c.archetype = str(d.get("id", "visitor"))
	c.display_name = str(d.get("name", c.archetype))
	c.tier = int(d.get("tier", 1))
	var cash_range: Array = d.get("cash", [0, 20])
	c.cash_offer = rng.randi_range(int(cash_range[0]), int(cash_range[1]))
	c.quip = str(d.get("quip", ""))

	# What they carry in: 1-3 units of junk or trade goods.
	var bring_pool: Array = d.get("brings", ["scrap_metal"])
	var bring_count := rng.randi_range(1, 2)
	for i in range(bring_count):
		var bid := str(rng.pick(bring_pool))
		c.brings.append({"id": bid, "qty": rng.randi_range(1, 3)})

	# What they want, sized to what they can actually pay for.
	# A request that costs more than wallet + trade goods would be a guaranteed walkout.
	var budget := c.cash_offer + brings_value(c)
	var pool: Array = d.get("wants", ["bean_pod"]).duplicate()
	shuffle_with(pool, rng)
	var spent := 0
	for wid in pool:
		if c.wants.size() >= 2:
			break
		var value := GoodsDB.value_of(str(wid))
		if value <= 0:
			continue
		var qty := 1
		if value <= 12 and value * 2 <= budget - spent:
			qty = 2
		if value * qty > budget - spent:
			continue
		c.wants.append({"id": str(wid), "qty": qty})
		spent += value * qty
	return c

static func shuffle_with(arr: Array, rng: GameRNG) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
