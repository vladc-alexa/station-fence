class_name GoodsDef
extends RefCounted

var id: String = ""
var display_name: String = ""
var category: String = ""	  # produce | food | medicine | luxury | raw | supply
var base_value: int = 1
var stack: int = 20

static func from_dict(d: Dictionary) -> GoodsDef:
	var g := GoodsDef.new()
	g.id = str(d.get("id", ""))
	g.display_name = str(d.get("name", g.id))
	g.category = str(d.get("category", "supply"))
	g.base_value = int(d.get("base_value", 1))
	g.stack = int(d.get("stack", 20))
	return g

func is_valid() -> bool:
	return id != "" and base_value > 0
