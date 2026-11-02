extends SceneTree
## Balance harness: godot --headless --path . --script res://tests/balance_sim.gd -- 30 [--debug]

func _initialize() -> void:
	var days := 30
	var debug := OS.get_cmdline_user_args().has("--debug")
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			days = int(a)
	var GS = load("res://scripts/autoload/game_state.gd")
	var gs = GS.new()
	gs.new_run(4242)
	print("day cash rating visitors trades harvests plants")
	for d in range(days):
		for b in [1, 2]:
			if not bool(gs.benches[b]["lamp"]):
				gs.toggle_lamp(b)
		for i in range(6):
			for b in range(gs.BENCH_COUNT):
				for s in range(gs.SLOT_COUNT):
					gs.water_slot(b, s)
		var harvests := 0
		for b in range(gs.BENCH_COUNT):
			for s in range(gs.SLOT_COUNT):
				if bool(gs.harvest_slot(b, s).get("ok", false)):
					harvests += 1
		var trades := 0
		for i in range(12):
			var cust = gs.next_customer()
			if cust == null:
				break
			var off: Dictionary = gs.offer_for(cust)
			var res: Dictionary = gs.trade(off)
			if debug:
				print("   %s wants=%s | offer=%s want_v=%d offer_v=%d -> %s" % [
					cust.display_name, cust.wants_text(), str(off),
					int(res.get("want_value", 0)), int(res.get("offer_value", 0)),
					str(res.get("reason", "accepted"))])
			if bool(res.get("ok", false)):
				trades += 1
		var plants := 0
		for b in range(gs.BENCH_COUNT):
			for s in range(gs.SLOT_COUNT):
				if gs.benches[b]["slots"][s] != null:
					plants += 1
		print("%3d %5d %5.1f %8d %6d %8d %6d" % [gs.day, gs.cash, gs.rating, gs.visitors_left, trades, harvests, plants])
		if gs.over:
			print("RUN OVER on day %d" % gs.day)
			break
		gs.end_day()
	gs.free()
	quit(0)
