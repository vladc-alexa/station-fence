class_name PlantDB
extends RefCounted
## Loads plant definitions once, exposes them by id.

const PATH := "res://data/plants.json"

static var _defs: Array = []

static func all() -> Array:
	if _defs.is_empty():
		_load()
	return _defs

static func get_def(id: String) -> PlantDef:
	for d in all():
		if d.id == id:
			return d
	return null

static func _load() -> void:
	_defs = []
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("PlantDB: cannot open %s" % PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		push_error("PlantDB: bad JSON")
		return
	for entry in parsed:
		var def := PlantDef.from_dict(entry)
		if def.is_valid():
			_defs.append(def)
