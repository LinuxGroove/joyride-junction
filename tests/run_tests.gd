extends Node
## Headless tests: run with
##   godot --headless --path . tests/run_tests.tscn
## Add `-- --days=N` to run the sample park for N park days (default 120).
## Exits non-zero on failure.

const TEST_LIBRARY := "user://test-parks/"

var failures := 0
var checks := 0


func _ready() -> void:
	var days := 120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--days="):
			days = maxi(1, arg.substr(7).to_int())
		# The other games take --games=N; one "game" here is a season.
		elif arg.begins_with("--games="):
			days = maxi(1, arg.substr(8).to_int()) * 120
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGTheme.apply(get_tree().root)
	LGInput.register_actions(GameConfig.ACTIONS)
	LGInput.extend_ui_actions()
	LGSettings.set_value("tutorial", "welcomed", true, false)
	ParkLibrary.dir = TEST_LIBRARY
	_clear_library()
	printerr("- _test_track_rules")
	_test_track_rules()
	printerr("- _test_designs")
	_test_designs()
	printerr("- _test_park_rules")
	_test_park_rules()
	printerr("- _test_ride_building")
	_test_ride_building()
	printerr("- _test_save_round_trip")
	_test_save_round_trip()
	printerr("- _test_library")
	_test_library()
	printerr("- _test_goal")
	_test_goal()
	printerr("- _test_season")
	_test_season(days)
	printerr("- _test_version")
	_test_version()
	printerr("- _test_launch_ping")
	_test_launch_ping()
	printerr("- _test_playtest")
	await _test_playtest()
	printerr("- _test_name_maker")
	_test_name_maker()
	printerr("- _test_scene_switcher")
	await _test_scene_switcher()
	printerr("- _test_option_rows")
	await _test_option_rows()
	printerr("- _test_game_scene")
	await _test_game_scene()
	printerr("- _test_title_menu")
	await _test_title_menu()
	_clear_library()
	print("\n%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await get_tree().process_frame


func _clear_library() -> void:
	for m in ParkLibrary.list():
		ParkLibrary.delete(str(m.id))


## An empty lot with a path from the gate, money to spend, not a sandbox.
func _lot(money := 20000) -> ParkData:
	var p := ParkData.create("Test lot", "empty", false, 1)
	p.money = money
	return p


# --- Coasters ------------------------------------------------------------

func _test_track_rules() -> void:
	var pose := {"pos": Vector3.ZERO, "dir": 0, "slope": 0}
	check(Track.piece_error(pose, [0, 1, 0]) == "", "flat track can start going up")
	check(Track.piece_error(pose, [0, 2, 0]) != "", "flat track can't jump straight to steep")
	check(Track.piece_error(pose, [1, 0, 0]) == "", "flat track can turn")
	var up := {"pos": Vector3.ZERO, "dir": 0, "slope": 1}
	check(Track.piece_error(up, [1, 1, 0]) != "", "track going up can't turn")
	check(Track.piece_error(up, [0, 0, Track.BRAKES]) != "", "brakes go on flat track only")
	var down := {"pos": Vector3.ZERO, "dir": 0, "slope": -1}
	check(Track.piece_error(down, [0, -1, Track.LIFT]) != "", "chain lifts don't go down")
	# Four left turns come back round to where they started.
	var at := pose
	for i in 4:
		at = Track.piece_points(at, [1, 0, 0]).pose
	check(Track.same_pose(at, pose), "four turns make a circle")
	var climb: Dictionary = Track.piece_points(pose, [0, 1, 0]).pose
	check(is_equal_approx((climb.pos as Vector3).y, 0.25) and int(climb.slope) == 1, "an easing-in slope rises a quarter tile (got %s)" % climb.pos)
	var r := CoasterDesigns.as_ride("little_woody", Vector2i(5, 5), 0)
	r.pieces.pop_back()
	var path := Track.build(r)
	check(not path.complete, "a circuit missing a piece isn't complete")
	check(not RidePhysics.simulate(path).ok, "an unfinished circuit can't be test run")


func _test_designs() -> void:
	for id in CoasterDesigns.BUILT_IN:
		for dir in 4:
			var r := CoasterDesigns.as_ride(id, Vector2i(15, 15), dir)
			var path := Track.build(r)
			check(path.complete, "%s closes its circuit facing %d" % [id, dir])
			var st := RidePhysics.simulate(path)
			check(st.ok, "%s runs (%s)" % [id, st.get("error", "")])
			if not st.ok:
				continue
			check(st.excitement > 2.0 and st.excitement < 7.0, "%s excitement %.2f is sensible" % [id, st.excitement])
			check(st.intensity > 1.5 and st.intensity < 8.0, "%s intensity %.2f is sensible" % [id, st.intensity])
			check(not st.too_intense, "%s can open" % id)
			check(st.duration > 10.0 and st.duration < 120.0, "%s takes %.0f s" % [id, st.duration])
	var a := RidePhysics.simulate(Track.build(CoasterDesigns.as_ride("little_woody", Vector2i(15, 15), 0)))
	var b := RidePhysics.simulate(Track.build(CoasterDesigns.as_ride("timber_twister", Vector2i(15, 15), 0)))
	check(b.intensity > a.intensity and b.highest_m > a.highest_m, "Timber Twister is the bigger ride")


# --- Building ------------------------------------------------------------

func _test_park_rules() -> void:
	var p := _lot(1000)
	var gate := p.gate_tile()
	check(p.kind_at(gate) == "entrance" and p.is_path(p.arrival_tile()), "a new park has a gate and a path in")
	check(p.build_error("path", gate) != "", "nothing goes on the gate")
	check(p.build_error("food", Vector2i(3, 3)) == "Shops need a footpath next to them", "shops need a path")
	var beside := p.arrival_tile() + Vector2i(1, 0)
	check(p.build_error("food", beside) == "", "a shop can go beside the path")
	var before := p.money
	p.build("food", beside)
	check(p.money == before - Pieces.cost("food"), "building costs money")
	check(Track.DIRS[int(p.tiles[beside].r)] == Vector2i(-1, 0), "a shop faces the path")
	check(int(p.tiles[beside].price) == int(Pieces.STALLS.food.price), "a shop starts at its usual price")
	before = p.money
	p.bulldoze(beside)
	check(not p.tiles.has(beside) and p.money == before + Pieces.cost("food") / 2, "bulldozing gives half back")
	p.money = 5
	check(p.build_error("path", Vector2i(3, 3)) == "Not enough money", "building needs money")
	var sandbox := ParkData.create("Sandbox", "meadow", true, 3)
	check(sandbox.build_error("food", sandbox.arrival_tile() + Vector2i(1, 0)) == "", "a sandbox never runs out")
	var wild := 0
	for t in sandbox.tiles:
		if sandbox.tiles[t].get("wild", false):
			wild += 1
	check(wild > 20, "the meadow has trees (%d)" % wild)
	var tree := sandbox.tiles.keys().filter(func(t): return sandbox.tiles[t].get("wild", false))[0] as Vector2i
	check(sandbox.build_error("path", tree) == "", "paths go over wild trees")


func _test_ride_building() -> void:
	var p := _lot()
	var at := Vector2i(12, 10)
	check(p.design_error("little_woody", at, 0) == "", "Little Woody fits on an empty lot")
	check(p.design_error("little_woody", Vector2i(34, 10), 0) != "", "but not hanging off the edge")
	var before := p.money
	var r := p.add_design("little_woody", at, 0)
	check(before - p.money == ParkData.design_cost("little_woody"), "a ready-made coaster costs what the menu says")
	check(Track.build(r).complete and r.name == "Little Woody", "a ready-made coaster is finished and named")
	check(p.design_error("little_woody", at, 0) != "", "two coasters can't share a place")
	check(p.ride_open_error(r).begins_with("Add an entrance"), "a ride needs an entrance to open")
	var doors := p.ride_door_tiles(r)
	check(doors.size() == 8, "a 4-tile station has 8 places for doors")
	p.set_door(r, "ride_in", doors[0])
	check(p.ride_open_error(r).begins_with("Add an exit"), "and an exit")
	check(p.door_error(r, doors[0]) != "", "doors don't stack")
	p.set_door(r, "ride_out", doors[2])
	check(p.ride_open_error(r) == "", "with both, the ride can open (%s)" % p.ride_open_error(r))
	p.set_door(r, "ride_in", doors[4])
	check(p.kind_at(doors[0]) == "" and p.kind_at(doors[4]) == "ride_in", "moving the entrance moves it")
	# Building track over a path needs clearance.
	var q := _lot()
	q.build("path", Vector2i(10, 15))
	var r2 := q.add_coaster(Vector2i(10, 10), 0, 3)
	for i in 2:
		q.add_piece(r2, [0, 0, 0])
	check(q.piece_error(r2, [0, 0, 0]) == "Something is in the way", "track at ground level can't cross a path")
	q.bulldoze(Vector2i(10, 15))
	check(q.piece_error(r2, [0, 0, 0]) == "", "but it can once the path's gone")
	q.remove_last_piece(r2)
	check(r2.pieces.size() == 1, "removing the last piece removes one")
	var refund := q.demolish_ride(r2)
	check(refund > 0 and q.rides.is_empty(), "demolishing a ride gives some money back")


func _test_save_round_trip() -> void:
	var p := ParkData.create("Round trip", "meadow", false, 9)
	SamplePark.build(p)
	var sim := ParkSim.new(p, 4)
	sim.hire_janitor()
	for i in 600:
		sim.step(0.1)
	sim.store()
	var text := JSON.stringify(p.to_dict())
	var back := ParkData.from_dict(JSON.parse_string(text))
	check(back != null, "a saved park opens")
	if back == null:
		return
	check(JSON.stringify(back.to_dict()) == text, "a park survives saving and opening unchanged")
	check(back.tiles.size() == p.tiles.size() and back.rides.size() == 1, "tiles and rides come back")
	check(back.rides[0].station.tile is Vector2i and back.tiles.keys()[0] is Vector2i, "tiles come back as tiles")
	var sim2 := ParkSim.new(back, 5)
	check(sim2.guests.size() == p.guests.size() and p.guests.size() > 5, "guests come back (%d)" % sim2.guests.size())
	check(sim2.janitors.size() == 1, "staff come back")
	check(sim2.runs[int(back.rides[0].id)].state != "closed", "an open ride is open again")
	for i in 100:
		sim2.step(0.1)
	check(sim2.guests.size() > 0, "a reopened park keeps running")
	check(ParkData.from_dict({"format": 99}) == null, "a park from a newer game doesn't open")


func _test_library() -> void:
	_clear_library()
	check(ParkLibrary.list().is_empty(), "the test library starts empty")
	var a := Scenarios.start("meadow_fair")
	var b := ParkData.create("Sandbox one", "meadow", true, 2)
	SamplePark.build(b)
	var img := Image.create(64, 40, false, Image.FORMAT_RGB8)
	img.fill(Color.SKY_BLUE)
	check(ParkLibrary.save(a) and ParkLibrary.save(b, null, img), "parks save")
	var list := ParkLibrary.list()
	check(list.size() == 2, "both parks are in the library")
	check(ParkLibrary.thumbnail(b.id) != null and ParkLibrary.thumbnail(a.id) == null, "a park saved with a picture has one")
	var loaded := ParkLibrary.load_park(b.id)
	check(loaded != null and loaded.name == "Sandbox one" and loaded.rides.size() == 1, "a saved park loads")
	check(ParkLibrary.unique_name("Meadow Fair") == "Meadow Fair 2", "new parks get names of their own")
	var c := ParkLibrary.copy(b.id, "Sandbox copy")
	check(c != "" and c != b.id and ParkLibrary.list().size() == 3, "copying makes a third park")
	check(ParkLibrary.load_park(c).name == "Sandbox copy" and ParkLibrary.thumbnail(c) != null, "the copy has its name and picture")
	check(ParkLibrary.rename(a.id, "Fairground") and ParkLibrary.load_park(a.id).name == "Fairground", "renaming a park")
	check(ParkLibrary.list().any(func(m): return m.name == "Fairground"), "the list shows the new name")
	ParkLibrary.delete(c)
	check(ParkLibrary.list().size() == 2 and ParkLibrary.load_park(b.id) != null, "deleting one park leaves the others")
	var f := FileAccess.open(TEST_LIBRARY + "broken.park", FileAccess.WRITE)
	f.store_string("not a park")
	f.close()
	check(ParkLibrary.load_park("broken") == null, "a broken file doesn't open")
	check(ParkLibrary.list().size() == 2, "and isn't listed")
	ParkLibrary.delete("broken")
	_clear_library()


func _test_goal() -> void:
	var p := Scenarios.start("meadow_fair", 3)
	var sim := ParkSim.new(p, 3)
	var states := []
	sim.goal_changed.connect(func(s): states.append(s))
	p.clock = ParkData.DAYS_PER_MONTH * 8 - 0.001
	sim.step(0.2)
	check(p.goal_state == "lost" and states == ["lost"], "missing the deadline loses the scenario")
	var q := Scenarios.start("meadow_fair", 4)
	SamplePark.build(q)
	var sim2 := ParkSim.new(q, 4)
	for i in 100:
		sim2.spawn_guest()
	sim2.rating = 700
	sim2._check_goal(false)
	check(q.goal_state == "won", "enough guests and a good rating wins")
	check(Scenarios.goal_text("meadow_fair").contains("100 guests"), "the goal says what it wants")


## A season in the sample park: guests come, ride, eat, litter, go home,
## and the park makes money.
func _test_season(days: int) -> void:
	var p := ParkData.create("Season", "meadow", false, 21)
	p.money = 20000
	SamplePark.build(p)
	var sim := ParkSim.new(p, 21)
	sim.hire_janitor()
	var start_money := p.money
	var peak := 0
	var steps := int(days * ParkSim.DAY_SECONDS / ParkSim.STEP)
	for i in steps:
		sim.step(ParkSim.STEP)
		peak = maxi(peak, sim.guests.size())
	var r: Dictionary = p.rides[0]
	print("  %d days: %d guests now (peak %d, %d visits), rating %d, happiness %.2f, money %d -> %d, %d riders, litter %d" % [
		days, sim.guests.size(), peak, p.total_guests, sim.rating, sim.average_happiness(), start_money, p.money, r.riders, p.litter.size()])
	check(peak >= 25, "guests come to the park (peak %d)" % peak)
	if days * ParkSim.DAY_SECONDS > 400.0:
		check(p.total_guests > sim.guests.size(), "guests go home too")
	check(int(r.riders) > 20, "guests ride the coaster (%d)" % r.riders)
	var shop_income := 0
	for t in p.tiles:
		shop_income += int(p.tiles[t].get("income", 0))
	check(shop_income > 0, "guests buy things")
	check(p.money > start_money, "the park makes money (%d -> %d)" % [start_money, p.money])
	check(sim.rating > 400, "the rating is decent (%d)" % sim.rating)
	check(sim.average_happiness() > 0.5, "guests are mostly happy (%.2f)" % sim.average_happiness())
	if days >= 30:
		check(not p.finances.is_empty() and int(p.month_totals().out) > 0, "months keep accounts")
	for g in sim.guests:
		if g.state == Guest.State.WALK and not g.route.is_empty():
			var next: Vector2i = g.route[0]
			check(sim.is_walkable(next) or p.kind_at(next) in ["entrance", "ride_out", "queue", "ride_in"], "guests stay on paths")
			break


# --- The add-on ----------------------------------------------------------

func _test_version() -> void:
	for v in ["2026.41.0", "2026.41.12", "2026.41.0+3.g1a2b3c4d", "0.1.0"]:
		check(LGVersion.is_valid(v), "%s is a valid version" % v)
	for v in ["v2026.41.0", "2026.41", "2026.41.0-3-g1a2b3c4d", ""]:
		check(not LGVersion.is_valid(v), "%s is not a valid version" % v)
	check(LGVersion.is_valid(GameConfig.version()), "this run's version %s is valid" % GameConfig.version())


func _test_name_maker() -> void:
	var used := ["MossyOtter"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 100:
		var n := LGNameMaker.make(used, rng)
		check(n.length() <= 16 and not n in used, "name %s is short and unique" % n)
		used.append(n)


func _test_scene_switcher() -> void:
	var tree := get_tree()
	await tree.process_frame
	var placeholder := Node.new()
	placeholder.name = "Placeholder"
	tree.root.add_child(placeholder)
	tree.current_scene = placeholder
	var made := []
	for n in ["SceneA", "SceneB", "SceneC"]:
		var node := Node.new()
		node.name = n
		var packed := PackedScene.new()
		packed.pack(node)
		node.free()
		made.append(packed)
	LGScenes.change_scene(made[0])
	LGScenes.change_scene(made[1])
	LGScenes.change_scene(made[2])
	await _wait_scene(placeholder)
	var found := []
	for c in tree.root.get_children():
		if str(c.name).begins_with("Scene") or c.name == "Placeholder":
			found.append(str(c.name))
	check(found == ["SceneC"], "a burst of scene changes leaves only the last scene (got %s)" % [found])
	for c in tree.root.get_children():
		if str(c.name).begins_with("Scene"):
			c.free()
	tree.current_scene = self


func _wait_scene(old: Node) -> void:
	var waited := 0
	while (LGScenes.is_busy() or get_tree().current_scene == old) and waited < 600:
		await get_tree().process_frame
		waited += 1
	await get_tree().process_frame


## Option rows by controller: A starts editing, right changes the value,
## A again finishes.
func _test_option_rows() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var col := VBoxContainer.new()
	layer.add_child(col)
	var got := []
	var row := LGCycler.make("Autosave", [[1, "Every minute"], [3, "Every 3 minutes"]], 1, func(v): got.append(v))
	col.add_child(row)
	col.add_child(LGUi.button("Below", func(): pass))
	await _frames(2)
	row.grab_focus()
	await _frames(1)
	await _press("ui_accept")
	check(row.editing, "A starts editing a row")
	await _press("ui_right")
	check(row.value() == 3 and got == [3], "right while editing changes the value")
	await _press("ui_accept")
	check(not row.editing, "A again finishes editing")
	layer.queue_free()
	await _frames(1)


# --- Playing -------------------------------------------------------------

## Drives the game scene the way a player would: paths, a shop, the
## bulldozer, a ready-made coaster with its doors, a coaster built piece by
## piece, the windows and the pause menu, then saving.
func _test_game_scene() -> void:
	_clear_library()
	var p := ParkData.create("Played park", "empty", false, 7)
	p.money = 30000
	var game: Game = (load(Game.SCENE) as PackedScene).instantiate()
	game.park = p
	add_child(game)
	await _frames(3)
	var arrival := p.arrival_tile()
	# Lay a path north from the end of the entry path.
	game.choose("path")
	check(game.mode == Game.Mode.BUILD, "picking a path starts building")
	var top := arrival + Vector2i(0, -6)
	for z in range(top.y - 1, top.y - 6, -1):
		game.cursor = Vector2(top.x + 0.5, z + 0.5)
		await _frames(1)
		game._place(false)
	check(p.is_path(Vector2i(top.x, top.y - 5)), "paths get built where the cursor is")
	game.choose("food")
	var shop := Vector2i(top.x + 1, top.y - 3)
	game.cursor = Vector2(shop) + Vector2(0.5, 0.5)
	await _frames(1)
	game._place(false)
	check(p.kind_at(shop) == "stall", "a shop gets built")
	game.cursor = Vector2(shop + Vector2i(4, 0)) + Vector2(0.5, 0.5)
	await _frames(1)
	var reason: Label = game.hud._ghost_error
	check(reason.text != "" and get_viewport().get_visible_rect().encloses(reason.get_global_rect()), "why a shop can't go shows on screen (%s at %s)" % [reason.text, reason.get_global_rect()])
	game.choose("tree")
	game.cursor = Vector2(top.x - 3.5, top.y - 2.5)
	await _frames(1)
	game._place(false)
	game.choose("bulldoze")
	await _frames(1)
	game._place(false)
	check(p.kind_at(Vector2i(top.x - 4, top.y - 3)) == "", "the bulldozer clears a tile")
	game._cancel()
	check(game.mode == Game.Mode.EXPLORE, "cancel puts the tool away")
	# A ready-made coaster, then its entrance and exit.
	game.choose("design:little_woody")
	var st := Vector2i(top.x + 3, top.y - 8)
	game.station_dir = 0
	game.cursor = Vector2(st) + Vector2(0.5, 0.5)
	await _frames(1)
	game._place(false)
	check(p.rides.size() == 1 and game.mode == Game.Mode.DOORS and game.door_kind == "ride_in", "placing a ready-made coaster asks for its entrance")
	var r: Dictionary = p.rides[0]
	game.cursor = Vector2(st + Vector2i(-1, 1)) + Vector2(0.5, 0.5)
	await _frames(1)
	game._place(false)
	check(game.door_kind == "ride_out", "then for its exit")
	game.cursor = Vector2(st + Vector2i(-1, 3)) + Vector2(0.5, 0.5)
	await _frames(1)
	game._place(false)
	check(game.mode == Game.Mode.EXPLORE and game.hud.window.visible, "with both placed, the ride's window opens")
	check(p.ride_open_error(r) == "", "the ride can open (%s)" % p.ride_open_error(r))
	game.hud.window._toggle_ride(r)
	check(r.open and game.sim.runs[int(r.id)].state == "loading", "opening the ride starts the train (open %s, %s)" % [r.open, game.sim.runs[int(r.id)].state])
	game.hud.close_window()
	# A coaster built piece by piece.
	game.choose("coaster_wood")
	game.station_dir = 0
	game.station_len = 3
	var st2 := Vector2i(4, 4)
	game.cursor = Vector2(st2) + Vector2(0.5, 0.5)
	await _frames(1)
	game._place(false)
	check(p.rides.size() == 2 and game.mode == Game.Mode.TRACK, "placing a station opens the track builder")
	var r2: Dictionary = game.ride
	game.set_piece([0, 0, 0])
	game.build_piece()
	game.build_piece()
	check(r2.pieces.size() == 2, "pieces get added")
	await _press("cancel")
	check(r2.pieces.size() == 1, "cancel removes the last piece")
	await _press("step_up")
	check(int(game.piece[1]) == 1, "up on the D-pad picks an upward slope")
	await _press("rotate")
	check(int(game.piece[2]) == Track.LIFT, "rotate picks a chain lift")
	game.set_piece([0, 2, 0])
	await _frames(2)
	check(reason.text != "" and reason.get_global_rect().end.x <= game.hud._track_panel.get_global_rect().position.x, "why a piece won't go is clear of the builder's panel (%s)" % reason.text)
	game.set_piece([0, 1, 1])
	await _press("inspect")
	check(game.mode == Game.Mode.EXPLORE and game.hud.window.visible, "stopping building shows the ride")
	await _frames(2)
	# Windows, menus and pause.
	game.hud.close_window()
	game.hud.open_build_menu()
	await _frames(1)
	check(game.hud.build_menu.visible, "the build menu opens")
	game.hud.build_menu.close()
	for i in 200:
		game.sim.step(0.1)
	await _frames(2)
	check(game.sim.guests.size() > 0, "guests arrive")
	game.hud.show_guest(game.sim.guests[0])
	game.hud.refresh()
	check(game.hud.window.visible and game.hud.window._col.get_child_count() > 4, "a guest's window shows them")
	for tab in ["park", "money", "staff"]:
		game.hud.show_park(tab)
		game.hud.refresh()
		await _frames(1)
	game.hud.window._hire()
	check(p.staff.size() == 1, "hiring a janitor")
	game.hud.show_stall(shop)
	game.hud.refresh()
	check(game.hud.window.visible, "a shop's window opens")
	game.hud.close_window()
	for state in ["won", "lost"]:
		game.hud.show_goal(state)
		var said: String = (game.hud._goal_panel.get_child(0).get_child(1) as Label).text
		check(said.contains(Scenarios.goal_text(p.scenario)) and not said.contains("%"), "the scenario's %s message says the goal (%s)" % [state, said])
		game.hud._close_goal()
	game.hud.open_pause()
	check(game.paused and game.hud.pause_menu.visible, "the pause menu pauses the park")
	var clock := p.clock
	await _frames(5)
	check(p.clock == clock, "nothing moves while paused")
	game.hud.pause_menu.close()
	check(not game.paused, "closing the menu carries on")
	await game.save_park()
	var saved := ParkLibrary.load_park(p.id)
	check(saved != null and saved.rides.size() == 2 and saved.staff.size() == 1, "the park saves to the library")
	game.queue_free()
	await _frames(2)
	_clear_library()


func _test_title_menu() -> void:
	_clear_library()
	var title: Node = (load("res://game/ui/title.tscn") as PackedScene).instantiate()
	add_child(title)
	await _frames(2)
	var texts := func() -> Array: return title._col.get_children().filter(func(c): return c is Button).map(func(b): return b.text)
	check(not texts.call().any(func(t): return t.begins_with("Carry on")), "no parks: nothing to carry on")
	var a := Scenarios.start("meadow_fair")
	var b := ParkData.create("Beach", "empty", true)
	ParkLibrary.save(a)
	ParkLibrary.save(b)
	title._show_main()
	check(texts.call().any(func(t): return t.begins_with("Carry on")) and texts.call().has("Your parks (2)"), "saved parks show on the title (%s)" % [texts.call()])
	await _frames(1)
	title._show_library()
	var list: VBoxContainer = title._list_scroll.get_child(0)
	check(list.get_child_count() == 2, "the library lists every park")
	await _frames(1)
	title._show_park(b.id)
	await _frames(1)
	title._copy(b.id, "Beach")
	await _frames(1)
	check(ParkLibrary.list().size() == 3 and ParkLibrary.list().any(func(m): return m.name == "Beach copy"), "copying from the menu")
	title._delete(b.id)
	await _frames(1)
	check(ParkLibrary.list().size() == 2 and ParkLibrary.load_park(a.id) != null, "deleting from the menu keeps the others")
	title._show_new()
	await _frames(1)
	check(texts.call().any(func(t): return t.contains("Meadow Fair")) and texts.call().any(func(t): return t.begins_with("Sandbox")), "new parks: scenarios and sandboxes")
	title._show_about()
	await _frames(1)
	title._show_settings()
	await _frames(1)
	title.queue_free()
	await _frames(2)
	_clear_library()


## The launch ping says only what it should, honours DO_NOT_TRACK and never
## goes out from tests.
func _test_launch_ping() -> void:
	for v in ["1", "yes", "true", " 1 "]:
		check(LGLaunchPing.opted_out(v), "DO_NOT_TRACK=%s turns pings off" % v)
	for v in ["", "0", "false"]:
		check(not LGLaunchPing.opted_out(v), "DO_NOT_TRACK=%s leaves pings on" % v)
	check(not LGLaunchPing.should_send(), "headless runs don't ping")
	LGLaunchPing.send(GameConfig.GAME_ID)
	check(not LGLaunchPing.sent, "tests send no ping")
	var id := LGLaunchPing.install_id()
	check(LGLaunchPing.is_install_id(id), "the install id is 32 hex digits")
	check(LGLaunchPing.install_id() == id, "the install id is kept between runs")
	var body := LGLaunchPing.body(GameConfig.GAME_ID, id)
	check(body.keys() == ["game", "install", "version", "os", "distro", "os_version", "arch"], "a ping says nothing more")
	check(body.game == GameConfig.GAME_ID and body.version == LGVersion.current(), "a ping names the game and version")
	check(body.arch == Engine.get_architecture_name() and body.os == OS.get_name(), "a ping names the OS and CPU")
	var server := {}
	for key in ["scheme", "host", "port"]:
		server[key] = LGSettings.get_value("online", key)
	LGSettings.set_value("online", "scheme", "https", false)
	LGSettings.set_value("online", "host", "play.example.org", false)
	LGSettings.set_value("online", "port", 443, false)
	check(LGLaunchPing.url(LGSettings) == "https://play.example.org:443/launch", "pings go to the game server's /launch")
	LGSettings.set_value("online", "host", "", false)
	check(LGLaunchPing.url(LGSettings) == "", "no server, no ping")
	for key in server:
		LGSettings.set_value("online", key, server[key], false)


## Play test recording: main sets it up, quitting ends it first, and a
## session packs into one zip with its events and answers.
func _test_playtest() -> void:
	check((load("res://game/main.gd") as GDScript).source_code.contains("LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)"), "main sets up play test recording")
	check((load("res://game/ui/title.gd") as GDScript).source_code.contains("LGScenes.quit"), "quitting from the title ends a play test first")
	var dir := "user://test_playtest"
	LGPlaytestPack._remove(dir)
	var p := LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)
	p.dir = dir
	await get_tree().process_frame
	p.begin()
	check(LGPlaytest.recording(), "a play test records")
	LGPlaytest.event("test", {"at": Vector2(1, 2)})
	p.mark("fun", "a note")
	var zip := p._end("test", {"fun": 5})
	var r := ZIPReader.new()
	check(zip != "" and r.open(zip) == OK, "a play test packs into one zip")
	var files := r.get_files()
	for f in ["session.json", "events.jsonl", "survey.json"]:
		check(f in files, "the zip holds " + f)
	if "session.json" in files:
		var info: Dictionary = JSON.parse_string(r.read_file("session.json").get_string_from_utf8())
		check(info.get("game") == GameConfig.GAME_ID and int(info.get("marks", 0)) == 1, "session.json names the game and counts the notes")
		check(not info.get("settings", {}).get("online", {}).has("server_key"), "the server key never goes in a recording")
	r.close()
	var survey := LGPlaytestSurvey.make(GameConfig.PLAYTEST)
	check("fun" in survey.questions() and "name" in survey.questions(), "the survey asks the standard questions")
	for id in GameConfig.PLAYTEST.get("skip", []):
		check(not id in survey.questions(), "the survey skips " + id)
	survey.free()
	p.queue_free()
	await get_tree().process_frame
	LGPlaytestPack._remove(dir)
