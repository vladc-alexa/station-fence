class_name GoodsDB
extends RefCounted

const PATH := "res://data/goods.json"

static var _defs: Array = []

static func all() -> Array:
	if _defs.is_empty():
		_load()
	return _defs

static func get_def(id: String) -> GoodsDef:
	for g in all():
		if g.id == id:
			return g
	return null

static func by_category(category: String) -> Array:
	var out: Array = []
	for g in all():
		if g.category == category:
			out.append(g)
	return out

static func value_of(id: String) -> int:
	var g := get_def(id)
	return g.base_value if g != null else 0

static func _load() -> void:
	_defs = []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("GoodsDB: cannot open %s" % PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("GoodsDB: bad JSON")
		return
	for entry in parsed:
		var g := GoodsDef.from_dict(entry)
		if g.is_valid():
			_defs.append(g)
