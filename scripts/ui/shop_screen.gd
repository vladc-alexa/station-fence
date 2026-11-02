extends Control
## Debug-but-playable shop screen: greenhouse benches on the left, counter on the right.

var _hud: Label
var _bench_box: VBoxContainer
var _customer_label: Label
var _log: RichTextLabel
var _slot_rows: Array = []	  # [{ "label": Label, "bench": int, "slot": int }]
var _lamp_buttons: Array = []

func _ready() -> void:
	_build()
	GameState.state_changed.connect(_refresh)
	GameState.log_line.connect(_on_log)
	GameState.run_over.connect(_on_run_over)
	_refresh()
	if OS.get_cmdline_user_args().has("--smoke"):
		call_deferred("_smoke")

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_hud = Label.new()
	root.add_child(_hud)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	var bench_panel := VBoxContainer.new()
	bench_panel.custom_minimum_size = Vector2(560, 0)
	columns.add_child(bench_panel)
	var bench_title := Label.new()
	bench_title.text = "GREENHOUSE"
	bench_panel.add_child(bench_title)
	_bench_box = VBoxContainer.new()
	bench_panel.add_child(_bench_box)

	for b in range(GameState.BENCH_COUNT):
		var bench_label := Label.new()
		_bench_box.add_child(bench_label)
		var lamp_button := Button.new()
		lamp_button.text = "Toggle lamp"
		var bi := b
		lamp_button.pressed.connect(func() -> void: GameState.toggle_lamp(bi))
		_bench_box.add_child(lamp_button)
		_lamp_buttons.append(bench_label)
		for s in range(GameState.SLOT_COUNT):
			var row := HBoxContainer.new()
			var plant_label := Label.new()
			plant_label.custom_minimum_size = Vector2(320, 0)
			row.add_child(plant_label)
			var water_button := Button.new()
			water_button.text = "Water"
			var bb := b
			var ss := s
			water_button.pressed.connect(func() -> void: GameState.water_slot(bb, ss))
			row.add_child(water_button)
			var harvest_button := Button.new()
			harvest_button.text = "Harvest"
			harvest_button.pressed.connect(func() -> void: GameState.harvest_slot(bb, ss))
			row.add_child(harvest_button)
			_bench_box.add_child(row)
			_slot_rows.append({"label": plant_label, "bench": b, "slot": s})

	var shop_panel := VBoxContainer.new()
	shop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_panel.add_theme_constant_override("separation", 8)
	columns.add_child(shop_panel)

	_customer_label = Label.new()
	_customer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_customer_label.custom_minimum_size = Vector2(0, 140)
	shop_panel.add_child(_customer_label)

	var next_button := Button.new()
	next_button.text = "Next visitor"
	next_button.pressed.connect(_on_next)
	shop_panel.add_child(next_button)

	var trade_button := Button.new()
	trade_button.text = "Trade (offer what they want)"
	trade_button.pressed.connect(_on_trade)
	shop_panel.add_child(trade_button)

	var day_button := Button.new()
	day_button.text = "End day"
	day_button.pressed.connect(_on_end_day)
	shop_panel.add_child(day_button)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save)
	shop_panel.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_on_load)
	shop_panel.add_child(load_button)

	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 200)
	_log.scroll_following = true
	root.add_child(_log)

func _refresh() -> void:
	_hud.text = "Day %d   Cash %d   Rating %.1f (visitors %d)   Morning ticks %d" % [
		GameState.day, GameState.cash, GameState.rating,
		GameState.visitors_left, GameState.morning.ticks_left]

	for row in _slot_rows:
		var b: int = row["bench"]
		var s: int = row["slot"]
		var plant = GameState.benches[b]["slots"][s]
		var label: Label = row["label"]
		if plant == null:
			label.text = "  slot %d: (empty)" % s
		else:
			label.text = "  %s — stage %d/3  growth %.1f/%.1f%s" % [
				plant.def.display_name, plant.stage, plant.progress,
				plant.def.total_days(), "  WILTED" if plant.wilted else ""]

	for bi in range(_lamp_buttons.size()):
		var label: Label = _lamp_buttons[bi]
		var lamp_on := bool(GameState.benches[bi]["lamp"])
		label.text = "Bench %d  [%s]  water %.1f" % [bi + 1, "lamp ON" if lamp_on else "lamp off", float(GameState.benches[bi]["water"])]

	if GameState.current == null:
		_customer_label.text = "Counter: nobody here.\n\nStock: %s" % _stock_text()
	else:
		var c := GameState.current
		_customer_label.text = "%s (tier %d) says: %s\nWants: %s\nBrings: %s + %d cash\nAccept threshold: %d value\n\nStock: %s" % [
			c.display_name, c.tier, c.quip, c.wants_text(), c.brings_text(),
			c.cash_offer, Barter.threshold(c), _stock_text()]

func _stock_text() -> String:
	if GameState.goods.is_empty():
		return "nothing"
	var parts: Array = []
	for id in GameState.goods.keys():
		parts.append("%s x%d" % [str(id), int(GameState.goods[id])])
	return ", ".join(parts)

func _on_next() -> void:
	GameState.next_customer()
	_refresh()

func _on_trade() -> void:
	if GameState.current == null:
		_on_log("Nobody at the counter.")
		return
	var offered := GameState.offer_for(GameState.current)
	var res := GameState.trade(offered)
	_on_log("Trade %s (offered %d, wanted %d)" % [
		"accepted" if bool(res["ok"]) else "refused: %s" % str(res["reason"]),
		int(res["offer_value"]), int(res["want_value"])])
	_refresh()

func _on_end_day() -> void:
	var summary := GameState.end_day()
	if bool(summary.get("ok", false)):
		_on_log("Upkeep paid: %d. Day %d." % [int(summary["upkeep"]), int(summary["day"])])
	_refresh()

func _on_save() -> void:
	_on_log("Saved." if GameState.save_game() else "Save failed.")

func _on_load() -> void:
	_on_log("Loaded." if GameState.load_game() else "No save found.")

func _on_run_over(reason: String) -> void:
	_on_log("RUN OVER: %s" % reason)

func _on_log(text: String) -> void:
	_log.append_text(text + "\n")

## Headless integration smoke: godot --headless --path . -- --smoke
func _smoke() -> void:
	var fails := 0
	var start_day: int = GameState.day
	var trades := 0
	var harvests := 0
	for d in range(10):
		for row in _slot_rows:
			GameState.water_slot(int(row["bench"]), int(row["slot"]))
		for row in _slot_rows:
			GameState.water_slot(int(row["bench"]), int(row["slot"]))
		GameState.toggle_lamp(0)
		for b in range(GameState.BENCH_COUNT):
			for s in range(GameState.SLOT_COUNT):
				if GameState.harvest_slot(b, s).get("ok", false):
					harvests += 1
		for i in range(12):
			GameState.next_customer()
			if GameState.current == null:
				break
			var res := GameState.trade(GameState.offer_for(GameState.current))
			if bool(res.get("ok", false)):
				trades += 1
		GameState.end_day()
	if GameState.day != start_day + 10:
		fails += 1
	if harvests <= 0:
		fails += 1
	if _hud.text.find("Day %d" % GameState.day) == -1:
		fails += 1
	print("SMOKE hud=%s" % _hud.text)
	print("SMOKE trades=%d harvests=%d cash=%d rating=%.1f plants=%s" % [
		trades, harvests, GameState.cash, GameState.rating, _plant_progress()])
	print("SMOKE: %s" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)

func _plant_progress() -> String:
	var parts: Array = []
	for b in range(GameState.BENCH_COUNT):
		for s in range(GameState.SLOT_COUNT):
			var plant = GameState.benches[b]["slots"][s]
			if plant != null:
				parts.append("%s:%d" % [plant.def.id, plant.stage])
	return ",".join(parts)
