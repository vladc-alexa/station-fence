class_name ItemDB
extends RefCounted
## Loads item definitions once, exposes lookup by id.

const PATH := "res://data/items.json"

static var _items: Dictionary = {}

static func all() -> Array:
	_ensure_loaded()
	return _items.values()

static func get_def(id: String) -> ItemDef:
	_ensure_loaded()
	return _items.get(id, null)

static func _ensure_loaded() -> void:
	if not _items.is_empty():
		return
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("ItemDB: cannot read %s" % PATH)
		return
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("ItemDB: %s is not a JSON array" % PATH)
		return
	for entry in parsed:
		var def := ItemDef.from_dict(entry)
		_items[def.id] = def
