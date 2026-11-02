extends Node2D
## The greenhouse room. Builds its own nodes, draws the sim state, takes clicks.

const SPR := "res://assets/sprites/"
const FONT_PATH := "res://assets/fonts/hud.fnt"

const BENCHES := [
	{"x": 10, "y": 152, "slots": [44, 104]},
	{"x": 160, "y": 152, "slots": [194, 254]},
	{"x": 10, "y": 200, "slots": [44, 104]},
]
const COUNTER_POS := Vector2(298, 176)
const VENDOR_POS := Vector2(334, 138)
const CUSTOMER_POS := Vector2(262, 244)
const HUD_TOP := 246

var _layer: Node2D
var _plant_nodes: Array = []
var _pot_nodes: Array = []
var _lamp_nodes: Array = []
var _customer_sprite: Sprite2D
var _customer_shadow: Sprite2D
var _vendor_sprite: Sprite2D
var _bubble: Label
var _bubble_panel: ColorRect
var _hud: Label
var _log: Label
var _font: FontFile


func _ready() -> void:
	_font = FontFile.new()
	_font.load_bitmap_font(FONT_PATH)
	_build()
	GameState.state_changed.connect(_refresh)
	GameState.log_line.connect(_on_log)
	_refresh()
	if OS.get_cmdline_user_args().has("--smoke"):
		call_deferred("_smoke")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			call_deferred("_shot", arg.substr(7))


func _tex(name: String) -> Texture2D:
	return load(SPR + name + ".png")


func _sprite(name: String, pos: Vector2, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.position = pos
	s.z_index = z
	_layer.add_child(s)
	return s


func _build() -> void:
	_layer = Node2D.new()
	add_child(_layer)

	_sprite("backdrop", Vector2(240, 75))
	_sprite("floor", Vector2(240, 210))

	# benches: legs and plates first, so plants read as standing on them
	for i in range(BENCHES.size()):
		var b: Dictionary = BENCHES[i]
		_sprite("bench", Vector2(float(b["x"]) + 70.0, float(b["y"]) + 6.0), 1)
		var lamp := _sprite("lamp", Vector2(float(b["x"]) + 66.0, 128.0), 4)
		_lamp_nodes.append(lamp)

	for i in range(BENCHES.size()):
		var b: Dictionary = BENCHES[i]
		var by := float(b["y"])
		for slot_x in b["slots"]:
			var x := float(slot_x)
			var pot := _sprite("pot", Vector2(x, by - 4.0), 2)
			_pot_nodes.append(pot)
			var plant := _sprite("plant_lumen_moss_0", Vector2(x, by - 8.0 - 20.0), 3)
			_plant_nodes.append(plant)

	_sprite("shadow", VENDOR_POS + Vector2(0, 36), 1)
	_vendor_sprite = _sprite("vendor", VENDOR_POS, 2)
	_sprite("counter", COUNTER_POS + Vector2(88, 29), 5)
	_customer_shadow = _sprite("shadow", CUSTOMER_POS + Vector2(0, 2), 1)
	_customer_sprite = _sprite("customer_0", CUSTOMER_POS, 6)
	_customer_sprite.visible = false

	_bubble_panel = ColorRect.new()
	_bubble_panel.color = Color(0.05, 0.07, 0.11, 0.92)
	_bubble_panel.position = Vector2(180, 176)
	_bubble_panel.size = Vector2(150, 26)
	_bubble_panel.z_index = 6
	_bubble_panel.visible = false
	_layer.add_child(_bubble_panel)

	_bubble = _text(Vector2(184, 180), 120, 6)
	_bubble.visible = false

	var plate := ColorRect.new()
	plate.color = Color(0.06, 0.08, 0.12, 0.96)
	plate.position = Vector2(0, HUD_TOP)
	plate.size = Vector2(480, 24)
	plate.z_index = 10
	_layer.add_child(plate)

	_hud = _text(Vector2(4, HUD_TOP + 4), 300, 11)
	var end_plate := ColorRect.new()
	end_plate.color = Color(0.42, 0.28, 0.12, 1.0)
	end_plate.position = Vector2(392, HUD_TOP + 2)
	end_plate.size = Vector2(84, 20)
	end_plate.z_index = 10
	_layer.add_child(end_plate)
	var end_label := _text(Vector2(404, HUD_TOP + 8), 80, 11)
	end_label.text = "END DAY >"
	_log = _text(Vector2(4, 228), 290, 11)


func _text(pos: Vector2, width: float, z: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, 20)
	l.z_index = z
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 5)
	l.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	_layer.add_child(l)
	return l


func _refresh() -> void:
	for i in range(_plant_nodes.size()):
		var b := i / 2
		var s := i % 2
		var plant = GameState.benches[b]["slots"][s]
		var sprite: Sprite2D = _plant_nodes[i]
		var pot: Sprite2D = _pot_nodes[i]
		if plant == null:
			sprite.visible = false
			pot.visible = false
			continue
		pot.visible = true
		sprite.visible = true
		sprite.texture = _tex("plant_%s_%d" % [plant.def.id, clampi(plant.stage, 0, 3)])
		sprite.modulate = Color(0.62, 0.66, 0.62) if plant.wilted else Color.WHITE
	for i in range(_lamp_nodes.size()):
		var on := bool(GameState.benches[i]["lamp"])
		_lamp_nodes[i].modulate = Color(1, 0.95, 0.75) if on else Color(0.55, 0.6, 0.68)

	var c = GameState.current
	if c == null:
		_customer_sprite.visible = false
		_customer_shadow.visible = false
		_bubble.visible = false
		_bubble_panel.visible = false
	else:
		_customer_sprite.visible = true
		_customer_shadow.visible = true
		_customer_sprite.texture = _tex("customer_%d" % (abs(c.archetype.hash()) % 4))
		_bubble_panel.visible = true
		_bubble.visible = true
		_bubble.text = "%s WANTS %s" % [c.display_name.to_upper(), c.wants_text().to_upper()]

	_hud.text = "DAY %d  CASH %d  RATING %.0f  VIS %d  TICKS %d" % [
		GameState.day, GameState.cash, GameState.rating, GameState.visitors_left,
		GameState.morning.ticks_left]
	_log.text = ""


func _on_log(msg: String) -> void:
	_log.text = msg.to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				GameState.end_day()
				_refresh()
			KEY_N:
				GameState.next_customer()
			KEY_T:
				_trade()
			KEY_S:
				GameState.save_game()
			KEY_L:
				GameState.load_game()
				_refresh()


func _click(pos: Vector2) -> void:
	if pos.y >= HUD_TOP:
		if pos.x > 392:
			GameState.end_day()
			_refresh()
		return
	if GameState.current != null:
		var r := Rect2(CUSTOMER_POS - Vector2(12, 40), Vector2(26, 42))
		if r.has_point(pos):
			_trade()
			return
	for i in range(_lamp_nodes.size()):
		if Rect2(Vector2(float(BENCHES[i]["x"]) + 60.0, 114.0), Vector2(14, 14)).has_point(pos):
			GameState.toggle_lamp(i)
			return
	for i in range(_plant_nodes.size()):
		var b := i / 2
		var s := i % 2
		var bench: Dictionary = BENCHES[b]
		var x := float(bench["slots"][s])
		var by := float(bench["y"])
		if Rect2(Vector2(x - 16, by - 52), Vector2(32, 34)).has_point(pos):
			var res: Dictionary = GameState.harvest_slot(b, s)
			if not bool(res.get("ok", false)):
				var w: Dictionary = GameState.water_slot(b, s)
				_on_log("watered" if bool(w.get("ok", false)) else str(w.get("reason", "no")))
			else:
				_on_log("harvested %d %s" % [int(res["qty"]), str(res["good"])])
			return
	if Rect2(COUNTER_POS + Vector2(20, 4), Vector2(140, 30)).has_point(pos):
		GameState.next_customer()


func _trade() -> void:
	if GameState.current == null:
		_on_log("nobody at the counter")
		return
	var res: Dictionary = GameState.trade(GameState.offer_for(GameState.current))
	if bool(res.get("ok", false)):
		_on_log("deal: +%d credits" % int(res["cash_gain"]))
	else:
		_on_log("refused: %s" % str(res["reason"]))


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot -> ", path)
	get_tree().quit(0)


func _smoke() -> void:
	var fails := 0
	var start_day: int = GameState.day
	var trades := 0
	for d in range(6):
		for b in range(GameState.BENCH_COUNT):
			for s in range(GameState.SLOT_COUNT):
				GameState.water_slot(b, s)
		for b in range(GameState.BENCH_COUNT):
			for s in range(GameState.SLOT_COUNT):
				GameState.harvest_slot(b, s)
		for i in range(6):
			var c = GameState.next_customer()
			if c == null:
				break
			if bool(GameState.trade(GameState.offer_for(c)).get("ok", false)):
				trades += 1
		GameState.end_day()
	if GameState.day != start_day + 6:
		fails += 1
	if trades == 0:
		fails += 1
	print("SMOKE day=%d cash=%d rating=%.1f trades=%d" % [
		GameState.day, GameState.cash, GameState.rating, trades])
	print("SMOKE: %s" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)
