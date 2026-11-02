extends Control
## Barebones counter UI, built in code so the scene file stays trivial.

var _hud: Label
var _offer: Label
var _log: RichTextLabel
var _shelf: ItemList
var _buttons: HBoxContainer

func _ready() -> void:
	_build()
	GameState.state_changed.connect(_refresh)
	GameState.log_line.connect(_on_log)
	GameState.run_over.connect(_on_game_over)
	_on_log("Shift starts. Rent is due at closing.")
	_refresh()
	if OS.get_cmdline_user_args().has("--smoke"):
		call_deferred("_smoke")

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 22)
	root.add_child(_hud)

	_offer = Label.new()
	_offer.add_theme_font_size_override("font_size", 18)
	root.add_child(_offer)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	_shelf = ItemList.new()
	_shelf.custom_minimum_size = Vector2(420, 0)
	_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_shelf)

	_log = RichTextLabel.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	split.add_child(_log)

	_buttons = HBoxContainer.new()
	root.add_child(_buttons)
	_add_button("Next customer", _on_next)
	_add_button("Appraise", _on_appraise)
	_add_button("Buy at ask", _on_buy_ask)
	_add_button("Lowball -20%", _on_buy_lowball)
	_add_button("Sell selected", _on_sell)
	_add_button("End day", _on_end_day)
	_add_button("Save", _on_save)
	_add_button("Load", _on_load)

func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	_buttons.add_child(b)

func _refresh() -> void:
	_hud.text = "Day %d   Cash %d   Rep %d   Heat %.0f   Skill %d" % [
		GameState.day, GameState.cash, GameState.reputation, GameState.heat, GameState.inspection_skill
	]
	var c = GameState.current
	if c == null:
		_offer.text = "Counter empty. Press 'Next customer'."
	else:
		var line := "%s (%s)" % [c.display_name, _arch_name(c.archetype)]
		if c.offer_item != null:
			line += " wants to sell: %s, condition %d%%, asking %d" % [
				c.offer_item.def.name, int(c.offer_item.condition * 100.0), c.asking_price()
			]
		else:
			line += " is looking for %s (budget %d)" % [c.wants_category, c.budget]
		_offer.text = line
	_shelf.clear()
	for i in range(GameState.inventory.size()):
		var item = GameState.inventory[i]
		var tag := "  [CONTRABAND]" if not item.def.legal else ""
		_shelf.add_item("%s  ~%dc  cond %d%%%s" % [
			item.def.name, item.true_value, int(item.condition * 100.0), tag
		])

func _arch_name(a: int) -> String:
	match a:
		Customer.Archetype.DESPERATE:
			return "desperate"
		Customer.Archetype.COLLECTOR:
			return "collector"
		Customer.Archetype.UNDERCOVER:
			return "???"
	return "walker"

func _on_next() -> void:
	GameState.next_customer()
	_refresh()

func _on_appraise() -> void:
	var c = GameState.current
	if c == null or c.offer_item == null:
		_on_log("Nothing to appraise.")
		return
	var est: Dictionary = c.offer_item.estimate(GameState.inspection_skill, GameState.cycle.rng)
	var text := "Appraisal: %d-%d credits" % [int(est["low"]), int(est["high"])]
	if est["exact"]:
		text = "Appraisal: exactly %d credits" % int(est["low"])
	_on_log(text)

func _on_buy_ask() -> void:
	var c = GameState.current
	if c == null or c.offer_item == null:
		_on_log("They are not selling anything.")
		return
	GameState.buy_offer(c.asking_price())
	_refresh()

func _on_buy_lowball() -> void:
	var c = GameState.current
	if c == null or c.offer_item == null:
		_on_log("They are not selling anything.")
		return
	GameState.buy_offer(int(round(float(c.asking_price()) * 0.8)))
	_refresh()

func _on_sell() -> void:
	var c = GameState.current
	var picked := _shelf.get_selected_items()
	if c == null or picked.is_empty():
		_on_log("Pick a shelf item and have a customer at the counter.")
		return
	var idx := int(picked[0])
	var item = GameState.inventory[idx]
	GameState.sell_item(idx, c.perceived_value(item))
	_refresh()

func _on_end_day() -> void:
	GameState.end_day()
	_refresh()

func _on_save() -> void:
	_on_log("Saved." if GameState.save_game() else "Save failed.")

func _on_load() -> void:
	_on_log("Loaded." if GameState.load_game() else "No save found.")

## Headless integration smoke test: godot --headless --path . -- --smoke
func _smoke() -> void:
	var fails := 0
	var deals := 0
	var start_cash: int = GameState.cash
	for i in range(48):
		_on_next()
		var c = GameState.current
		if c == null:
			continue
		if c.offer_item != null:
			_on_appraise()
			_on_buy_ask()
		elif not GameState.inventory.is_empty():
			_shelf.select(0)
			_on_sell()
			deals += 1
	if GameState.day != 1:
		fails += 1
	_on_end_day()
	if GameState.day != 2:
		fails += 1
	if _hud.text.find("Day 2") == -1:
		fails += 1
	if GameState.cash == start_cash:
		fails += 1
	print("SMOKE hud=%s" % _hud.text)
	print("SMOKE cash %d -> %d  deals=%d  inv=%d" % [start_cash, GameState.cash, deals, GameState.inventory.size()])
	print("SMOKE: %s" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
	get_tree().quit(0 if fails == 0 else 1)

func _on_log(text: String) -> void:
	_log.append_text(text + "\n")

func _on_game_over(reason: String) -> void:
	_on_log("RUN OVER: " + reason)
