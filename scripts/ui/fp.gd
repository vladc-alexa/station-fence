extends Node2D
## First-person shop: the counter, and the greenhouse you can walk into.

const SPR := "res://assets/sprites/"
const FONT := "res://assets/fonts/hud.fnt"

enum Station { COUNTER, GREENHOUSE }

# planters: [bench, slot, x, base_y]
const POTS := [
	[0, 0, 50, 240, 2.0], [0, 1, 96, 224, 1.7], [1, 0, 146, 208, 1.5],
	[1, 1, 336, 208, 1.5], [2, 0, 386, 224, 1.7], [2, 1, 432, 240, 2.0],
]
const DOOR := Rect2(248, 92, 118, 88)
const BELL := Rect2(203, 194, 48, 34)

var station: Station = Station.COUNTER
var _counter: Node2D
var _green: Node2D
var _pot_sprites := {}
var _plant_sprites := {}
var _lamp_sprites := {}
var _hud: Label
var _end_label: Label
var _nav_label: Label
var _toast: Label
var _bubble: Label
var _bubble_plate: ColorRect
var _bubble_panel: Panel


func _ready() -> void:
	_build_counter()
	_build_greenhouse()
	_build_hud()
	GameState.state_changed.connect(_refresh)
	GameState.log_line.connect(_on_log)
	_refresh()
	station = Station.COUNTER
	_show_station()
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke"):
		call_deferred("_smoke")
	for a in args:
		if a == "--clicktest":
			_clicktest()
			return
		if a.begins_with("--shot="):
			if args.has("--green"):
				station = Station.GREENHOUSE
			_show_station()
			if args.has("--demo"):
				GameState.next_customer()
				_refresh()
			_shoot(a.substr(7))



func _tex(name: String) -> Texture2D:
	const GEN := "res://assets/gen/"
	for path in [GEN + name + ".png", SPR + name + ".png"]:
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _sprite(parent: Node2D, name: String, pos: Vector2, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.position = pos
	s.z_index = z
	parent.add_child(s)
	return s


func _build_counter() -> void:
	_counter = Node2D.new()
	_counter.name = "Counter"
	add_child(_counter)
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/gen/bg_counter.png")
	bg.centered = false
	bg.position = Vector2.ZERO
	_counter.add_child(bg)
	_counter.visible = false


func _build_greenhouse() -> void:
	_green = Node2D.new()
	_green.name = "Greenhouse"
	add_child(_green)
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/gen/bg_greenhouse.png")
	bg.centered = false
	bg.position = Vector2.ZERO
	_green.add_child(bg)
	for i in range(POTS.size()):
		var pot: Array = POTS[i]
		var bx := float(pot[2])
		var by := float(pot[3])
		var sc := float(pot[4])
		var plant_sprite := _sprite(_green, "plant_lumen_moss", Vector2(bx, by - 20.0 * sc), 4)
		plant_sprite.scale = Vector2(sc, sc)
		_plant_sprites[i] = plant_sprite
	_green.visible = false


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var font: FontFile = FontFile.new()
	if font.load_bitmap_font(FONT) != OK:
		push_warning("hud font failed")
	var plate := ColorRect.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.color = Color(0.043, 0.059, 0.102, 0.94)
	plate.position = Vector2(0, 248)
	plate.size = Vector2(480, 22)
	layer.add_child(plate)
	_hud = Label.new()
	_hud.add_theme_font_override("font", font)
	_hud.add_theme_font_size_override("font_size", 5)
	_hud.add_theme_color_override("font_color", Color(0.95, 0.94, 0.89))
	_hud.position = Vector2(8, 252)
	layer.add_child(_hud)
	_toast = Label.new()
	_toast.add_theme_font_override("font", font)
	_toast.add_theme_font_size_override("font_size", 5)
	_toast.add_theme_color_override("font_color", Color(0.68, 0.88, 0.77))
	_toast.position = Vector2(8, 236)
	layer.add_child(_toast)
	_bubble_panel = Panel.new()
	_bubble_panel.position = Vector2(8, 6)
	_bubble_panel.size = Vector2(464, 44)
	_bubble_panel.visible = false
	layer.add_child(_bubble_panel)
	var plate_bg := ColorRect.new()
	plate_bg.name = "BubblePlate"
	plate_bg.position = Vector2(8, 6)
	plate_bg.size = Vector2(464, 44)
	plate_bg.color = Color(0.03, 0.05, 0.08, 0.78)
	plate_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_bg.visible = false
	_bubble_panel.add_child(plate_bg)
	_bubble_plate = plate_bg
	_bubble = Label.new()
	_bubble.add_theme_font_override("font", font)
	_bubble.add_theme_font_size_override("font_size", 5)
	_bubble.add_theme_color_override("font_color", Color(0.95, 0.94, 0.89))
	_bubble.position = Vector2(13, 10)
	_bubble.size = Vector2(452, 36)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bubble)
	# END DAY + navigation buttons (drawn as labels, hit-tested in _click)
	_end_label = Label.new()
	_end_label.add_theme_font_override("font", font)
	_end_label.add_theme_font_size_override("font_size", 5)
	_end_label.add_theme_color_override("font_color", Color(0.88, 0.69, 0.30))
	_end_label.position = Vector2(402, 252)
	_end_label.text = "END DAY"
	layer.add_child(_end_label)
	_nav_label = Label.new()
	_nav_label.add_theme_font_override("font", font)
	_nav_label.add_theme_font_size_override("font_size", 5)
	_nav_label.add_theme_color_override("font_color", Color(0.53, 0.88, 0.77))
	_nav_label.position = Vector2(300, 252)
	layer.add_child(_nav_label)


func _show_station() -> void:
	_counter.visible = station == Station.COUNTER
	_green.visible = station == Station.GREENHOUSE
	if _nav_label != null:
		_nav_label.text = "GREENHOUSE" if station == Station.COUNTER else "COUNTER"
	_refresh()


func _refresh() -> void:
	for i in range(POTS.size()):
		var bench := int(POTS[i][0])
		var slot := int(POTS[i][1])
		var plant = GameState.benches[bench]["slots"][slot]
		var ps: Sprite2D = _plant_sprites[i]
		if plant == null:
			ps.visible = false
		else:
			ps.visible = true
			ps.texture = _tex("plant_%s" % plant.def.id)
			var st: int = clampi(int(plant.stage), 0, 3)
			var depth := float(POTS[i][4])
			var grow: float = [0.45, 0.62, 0.82, 1.0][st] * depth
			ps.scale = Vector2(grow, grow)
			ps.position = Vector2(float(POTS[i][2]), float(POTS[i][3]) - 32.0 * grow)
			ps.self_modulate = Color(0.72, 0.78, 0.82) if plant.wilted else Color.WHITE
	for b in range(3):
		if _lamp_sprites.size() > b:
			var lamp: Sprite2D = _lamp_sprites[b]
			lamp.self_modulate = Color.WHITE if bool(GameState.benches[b]["lamp"]) else Color(0.45, 0.5, 0.55)
	var c = GameState.current
	if c == null:
		_bubble_panel.visible = false
		if _bubble_plate != null:
			_bubble_plate.visible = false
	else:
		_bubble_panel.visible = true
		if _bubble_plate != null:
			_bubble_plate.visible = true
		_bubble.text = "%s WANTS %s\nBRINGS %d CR + %s\nCLICK HERE TO SERVE" % [
			c.display_name.to_upper(), c.wants_text().to_upper().replace(" X", "X"),
			c.cash_offer, c.brings_text().to_upper().replace(" X", "X")]
	_hud.text = "DAY %d  CASH %d  RATING %.0f  VIS %d    S SAVE   L LOAD" % [
		GameState.day, GameState.cash, GameState.rating, GameState.visitors_left]


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(get_viewport().get_mouse_position())
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: _end_day()
			KEY_N: _next_visitor()
			KEY_T: _serve()
			KEY_G: _goto(Station.GREENHOUSE)
			KEY_C: _goto(Station.COUNTER)
			KEY_S: GameState.save_game()
			KEY_L: GameState.load_game()
			KEY_1: _toggle_lamp(0)
			KEY_2: _toggle_lamp(1)
			KEY_3: _toggle_lamp(2)


func _goto(s: Station) -> void:
	station = s
	_show_station()


func _click(p: Vector2) -> void:
	if Rect2(0, 248, 80, 22).has_point(p):
		_goto(Station.GREENHOUSE if station == Station.COUNTER else Station.COUNTER)
		return
	if Rect2(404, 248, 76, 22).has_point(p):
		_end_day()
		return
	if station == Station.COUNTER:
		if DOOR.has_point(p):
			_goto(Station.GREENHOUSE)
		elif BELL.has_point(p):
			_next_visitor()
		elif _bubble_panel.visible and Rect2(8, 6, 464, 44).has_point(p):
			_serve()
	else:
		for i in range(POTS.size()):
			var bx := float(POTS[i][2])
			var by := float(POTS[i][3])
			var sc := float(POTS[i][4])
			if Rect2(bx - 16.0 * sc, by - 42.0 * sc, 32.0 * sc, 44.0 * sc).has_point(p):
				_pick(i, true)
				return



func _toggle_lamp(b: int) -> void:
	GameState.toggle_lamp(b)
	_toast.text = "LAMP %d %s" % [b + 1, "ON" if bool(GameState.benches[b]["lamp"]) else "OFF"]


func _pick(index: int, harvest_first: bool) -> void:
	var bench := int(POTS[index][0])
	var slot := int(POTS[index][1])
	var plant = GameState.benches[bench]["slots"][slot]
	if harvest_first and plant != null and plant.is_harvestable():
		var res: Dictionary = GameState.harvest_slot(bench, slot)
		if bool(res.get("ok", false)):
			_toast.text = "HARVESTED %d %s" % [int(res["qty"]), str(res["good"]).to_upper()]
			return
	var wr: Dictionary = GameState.water_slot(bench, slot)
	_toast.text = "WATERED POT %d" % (index + 1) if bool(wr.get("ok", false)) else "NOTHING TO WATER"


func _next_visitor() -> void:
	var c = GameState.next_customer()
	_toast.text = "%s WALKS IN" % c.display_name.to_upper() if c != null else "NOBODY ELSE TODAY"


func _serve() -> void:
	if GameState.current == null:
		_toast.text = "NOBODY AT THE COUNTER"
		return
	var offered: Dictionary = GameState.offer_for(GameState.current)
	var res: Dictionary = GameState.trade(offered)
	_toast.text = "DEAL DONE" if bool(res.get("ok", false)) else "THEY REFUSED"


func _end_day() -> void:
	var s: Dictionary = GameState.end_day()
	_toast.text = "DAY %d  UPKEEP %d" % [int(s.get("day", GameState.day)), int(s.get("upkeep", 0))]


func _on_log(msg: String) -> void:
	pass


func _smoke() -> void:
	var fails := 0
	var start_day: int = GameState.day
	station = Station.GREENHOUSE
	_show_station()
	for i in range(6):
		_pick(i, true)
	station = Station.COUNTER
	_show_station()
	for d in range(4):
		for i in range(3):
			_next_visitor()
			_serve()
		_end_day()
	if GameState.day != start_day + 4:
		fails += 1
	print("SMOKE day=%d cash=%d rating=%.1f" % [GameState.day, GameState.cash, GameState.rating])
	print("SMOKE: %s" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _process(_delta: float) -> void:
	pass


func _shoot(path: String) -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot -> ", path)
	get_tree().quit(0)


func _clicktest() -> void:
	await get_tree().process_frame
	var before: int = GameState.day
	var k: float = float(get_window().size.x) / 480.0
	var target := Vector2(442.0, 259.0) * k
	DisplayServer.warp_mouse(Vector2i(target))
	await get_tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = target
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.2).timeout
	print("CLICK scale=%.1f mouse=%s day %d -> %d" % [k, str(get_viewport().get_mouse_position()), before, GameState.day])
	var day_ok := GameState.day > before
	# walk to the greenhouse and water the first planter
	DisplayServer.warp_mouse(Vector2i(Vector2(300.0, 130.0) * k))
	await get_tree().process_frame
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await get_tree().create_timer(0.2).timeout
	var in_green := station == Station.GREENHOUSE
	var w_before: float = float(GameState.benches[0]["water"])
	DisplayServer.warp_mouse(Vector2i(Vector2(float(POTS[0][2]), float(POTS[0][3])) * k))
	await get_tree().process_frame
	var ev3 := InputEventMouseButton.new()
	ev3.button_index = MOUSE_BUTTON_LEFT
	ev3.pressed = true
	Input.parse_input_event(ev3)
	await get_tree().create_timer(0.2).timeout
	var w_after: float = float(GameState.benches[0]["water"])
	print("CLICK nav=%s water %.2f -> %.2f" % [str(in_green), w_before, w_after])
	print("CLICK: " + ("PASS" if day_ok and in_green and w_after > w_before else "FAIL"))
	get_tree().quit()
