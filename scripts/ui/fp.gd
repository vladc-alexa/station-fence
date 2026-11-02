extends Node2D
## First-person shop: the counter, and the greenhouse you can walk into.

const SPR := "res://assets/sprites/"
const FONT := "res://assets/fonts/hud.fnt"

enum Station { COUNTER, GREENHOUSE }

# planters: [bench, slot, x, base_y]
const POTS := [
	[0, 0, 86, 150], [0, 1, 176, 150], [1, 0, 300, 150],
	[1, 1, 86, 214], [2, 0, 196, 214], [2, 1, 322, 214],
]
const DOOR := Rect2(300, 34, 134, 156)
const LAMP_X := [86, 196, 322]

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
		if a.begins_with("--shot="):
			if args.has("--green"):
				station = Station.GREENHOUSE
			_show_station()
			if args.has("--demo"):
				GameState.next_customer()
				_refresh()
			_shoot(a.substr(7))



func _tex(name: String) -> Texture2D:
	var path := SPR + name + ".png"
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
	bg.texture = _tex("bg_counter")
	bg.centered = false
	bg.position = Vector2.ZERO
	_counter.add_child(bg)
	_sprite(_counter, "till", Vector2(52, 190), 2)
	_sprite(_counter, "ledger", Vector2(150, 198), 2)
	_sprite(_counter, "bell", Vector2(258, 194), 2)
	_sprite(_counter, "can", Vector2(400, 196), 2)
	_counter.visible = false


func _build_greenhouse() -> void:
	_green = Node2D.new()
	_green.name = "Greenhouse"
	add_child(_green)
	var bg := Sprite2D.new()
	bg.texture = _tex("bg_greenhouse")
	bg.centered = false
	bg.position = Vector2.ZERO
	_green.add_child(bg)
	for i in range(POTS.size()):
		var pot: Array = POTS[i]
		var bench := int(pot[0])
		var bx := float(pot[2])
		var by := float(pot[3])
		_sprite(_green, "shadow", Vector2(bx, by + 2), 1)
		var pot_sprite := _sprite(_green, "pot_big", Vector2(bx, by - 16), 3)
		_pot_sprites[i] = pot_sprite
		var plant_sprite := _sprite(_green, "plant_lumen_moss_0", Vector2(bx, by - 40), 4)
		_plant_sprites[i] = plant_sprite
	for b in range(3):
		var lamp := _sprite(_green, "lamp_big", Vector2(float(LAMP_X[b]), 104.0), 5)
		_lamp_sprites[b] = lamp
	_green.visible = false


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var font: FontFile = FontFile.new()
	if font.load_bitmap_font(FONT) != OK:
		push_warning("hud font failed")
	var plate := ColorRect.new()
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
	_bubble = Label.new()
	_bubble.add_theme_font_override("font", font)
	_bubble.add_theme_font_size_override("font_size", 5)
	_bubble.add_theme_color_override("font_color", Color(0.95, 0.94, 0.89))
	_bubble.position = Vector2(13, 10)
	_bubble.size = Vector2(452, 36)
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
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
		_nav_label.text = "GREENHOUSE >" if station == Station.COUNTER else "< COUNTER"
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
			ps.texture = _tex("plant_%s_%d" % [plant.def.id, plant.stage])
			ps.self_modulate = Color(0.72, 0.78, 0.82) if plant.wilted else Color.WHITE
	for b in range(3):
		var lamp: Sprite2D = _lamp_sprites[b]
		lamp.self_modulate = Color.WHITE if bool(GameState.benches[b]["lamp"]) else Color(0.45, 0.5, 0.55)
	var c = GameState.current
	if c == null:
		_bubble_panel.visible = false
	else:
		_bubble_panel.visible = true
		_bubble.text = "%s WANTS %s\nBRINGS %d CR + %s\nCLICK HERE TO SERVE" % [
			c.display_name.to_upper(), c.wants_text().to_upper().replace(" X", "X"),
			c.cash_offer, c.brings_text().to_upper().replace(" X", "X")]
	_hud.text = "DAY %d  CASH %d  RATING %.0f  VIS %d    S SAVE   L LOAD" % [
		GameState.day, GameState.cash, GameState.rating, GameState.visitors_left]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: _end_day()
			KEY_N: _next_visitor()
			KEY_T: _serve()
			KEY_G: _goto(Station.GREENHOUSE)
			KEY_C: _goto(Station.COUNTER)
			KEY_S: GameState.save_game()
			KEY_L: GameState.load_game()


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
		elif Rect2(244, 182, 32, 24).has_point(p):
			_next_visitor()
		elif _bubble_panel.visible and Rect2(8, 6, 464, 44).has_point(p):
			_serve()
	else:
		for i in range(POTS.size()):
			var bx := float(POTS[i][2])
			var by := float(POTS[i][3])
			if Rect2(bx - 16.0, by - 82.0, 32.0, 44.0).has_point(p):
				_pick(i, true)
				return
			if Rect2(bx - 28.0, by - 34.0, 56.0, 36.0).has_point(p):
				_pick(i, false)
				return
		for b in range(3):
			if Rect2(float(LAMP_X[b]) - 7.0, 88.0, 14.0, 16.0).has_point(p):
				GameState.toggle_lamp(b)
				_toast.text = "LAMP %d %s" % [b + 1, "ON" if bool(GameState.benches[b]["lamp"]) else "OFF"]
				return


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
