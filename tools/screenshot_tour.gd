extends Node
## A tour of every screen: parks, rides, the coaster builder, building,
## windows and menus, saved as JPEGs in <dir>/<group>/<name>.jpg with a
## README.md beside them listing them all. tools/screenshot.gd starts it;
## run it under xvfb-run at the game's own size, with Mesa's software Vulkan
## (mesa-vulkan-drivers) so the shots use the game's Forward+ renderer
## (under plain xvfb-run Godot falls back to OpenGL, and the colours come
## out paler):
##   VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 tools/screenshot.tscn -- --all=docs/screenshots [group=builder]
## With group=, only that group is shot and the README is left alone.
## The parks it plays are saved in their own library, which the menus show.

## [id, heading, what the group shows], in the order they're shot: the
## parks come first so the park library has them, with their pictures.
const GROUPS := [
	["parks", "Parks", "Meadow Fair from its first day to its result, new sandbox parks on both maps, and a busy park with both ready-made coasters."],
	["rides", "Rides", "The ready-made coasters running, with their ride windows, and guests boarding."],
	["builder", "Coaster builder", "Ready-made coasters and a station placed with the cursor, then a coaster built piece by piece: every kind of piece, one that won't go, the entrance and exit, and the finished ride."],
	["building", "Building", "The build menu's tabs, and the tools for footpaths, queue lines, shops, scenery and the bulldozer."],
	["windows", "Windows", "A shop, a guest, the park's money and staff, renaming, and the pause menu."],
	["menus", "Menus", "The title screen, the park library, new parks, settings, about and every page of How to play."],
]
const LIBRARY := "user://screenshot-tour-parks/"
const COMMAND := "VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s \"-screen 0 1280x800x24\" godot --path . --resolution 1280x800 tools/screenshot.tscn -- --all=docs/screenshots"

var _root := ""
## [group, file name, title, note] for each picture, in the order taken.
var _taken := []


func run(dir: String, only: String) -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		push_warning("Screenshot tour: not on Forward+, so the shots won't look like the game. See the top of tools/screenshot_tour.gd.")
	_root = dir if dir.begins_with("/") else ProjectSettings.globalize_path("res://").path_join(dir)
	ParkLibrary.dir = LIBRARY
	LGSettings.set_value("play", "autosave_minutes", 10, false)
	LGSettings.set_value("tutorial", "welcomed", true, false)
	LGSettings.set_value("tutorial", "hints", true, false)
	# Scene changes replace the current scene; this one stays to drive them.
	get_tree().current_scene = null
	for g in GROUPS:
		if only != "" and only != g[0]:
			continue
		match g[0]:
			"parks":
				await _shoot_parks()
			"rides":
				await _shoot_rides()
			"builder":
				await _shoot_builder()
			"building":
				await _shoot_building()
			"windows":
				await _shoot_windows()
			"menus":
				await _shoot_menus()
	if only == "":
		_write_index()


# --- Parks ---------------------------------------------------------------

func _shoot_parks() -> void:
	for m in ParkLibrary.list():
		ParkLibrary.delete(str(m.id))
	var game := await _open(Scenarios.start("meadow_fair", 7))
	await _welcome(game)
	await _snap("parks", "meadow-fair-start", "Meadow Fair, day one", "The first scenario starts with a gate, a short path, a meadow of trees and $12,000. The tips say what to do first.")

	game = await _open(_meadow_fair())
	_hide_cursor(game)
	_look(game, Vector2(14, 21), 23.0, 35.0, 48.0, false)
	await _wait(1.0)
	await _snap("parks", "meadow-fair", "Meadow Fair, built up", "Two months in, with Little Woody, shops by the gate, benches, bins and a janitor.")
	await game.save_park()
	game.hud.show_park("park")
	await _wait(0.6)
	await _snap("parks", "meadow-fair-goal", "Meadow Fair's goal", "The park window shows the goal and the deadline next to how the park is doing.")
	_clear(game)
	game.hud.show_goal("won")
	await _wait(0.6)
	await _snap("parks", "meadow-fair-won", "Scenario complete", "Meeting the goal in time. The park stays open to keep building.")
	_clear(game)
	game.hud.show_goal("lost")
	await _wait(0.6)
	await _snap("parks", "meadow-fair-lost", "Out of time", "Missing the deadline. The park can still be played on.")

	game = await _open(ParkData.create("Treetop Gardens", "meadow", true, 4))
	await _welcome(game)
	await _snap("parks", "sandbox-meadow", "Sandbox on the Meadow", "A new sandbox park on the Meadow map, with no money to worry about.")
	await game.save_park()

	game = await _open(ParkData.create("Blank Slate", "empty", true, 5))
	await _welcome(game)
	await _snap("parks", "sandbox-empty-lot", "Sandbox on the Empty lot", "The Empty lot map: no trees, just the gate and a path.")
	await game.save_park()

	game = await _open(_sunny_hollow())
	_hide_cursor(game)
	_look(game, Vector2(21, 13), 36.0, 30.0, 45.0, false)
	await _wait(1.0)
	await _snap("parks", "sunny-hollow", "A busy park", "Little Woody and Timber Twister both running, with queues, shops and a crowd.")
	await game.save_park()
	_look(game, Vector2(18, 18), 44.0, 0.0, 82.0, false)
	await _wait(0.8)
	await _snap("parks", "sunny-hollow-above", "From above", "The same park with the camera tilted right down, as far out as it zooms.")
	_look(game, Vector2(18, 24), 9.0, 25.0, 36.0, false)
	await _wait(0.8)
	await _snap("parks", "crowd", "The crowd", "Close in on the shops by the gate: guests eating, queuing, resting and dropping litter.")


# --- Rides ---------------------------------------------------------------

func _shoot_rides() -> void:
	var game := await _open(_sunny_hollow())
	_hide_cursor(game)
	for r in game.park.rides:
		var slug := str(r.name).to_lower().replace(" ", "-")
		_frame_ride(game, r)
		await _wait(1.5)
		await _snap("rides", slug, str(r.name), str(CoasterDesigns.get_design(_design_of(r)).get("blurb", "A wooden coaster.")))
		_frame_ride(game, r, true)
		game.hud.show_ride(r)
		await _wait(0.6)
		await _snap("rides", slug + "-window", "%s's ride window" % r.name, "Whether it's open, its queue, its ratings from the test run, and the ticket price and train length.")
		_clear(game)
	var lw: Dictionary = game.park.rides[0]
	var st: Vector2i = lw.station.tile
	_look(game, Vector2(st) + Vector2(0.0, 2.0), 8.0, 290.0, 55.0, false)
	await _wait(1.5)
	await _snap("rides", "station", "Boarding", "Guests queue from the footpath to the entrance, board at the station and leave by the exit.")


## Which ready-made design a ride came from, by its name.
static func _design_of(r: Dictionary) -> String:
	for id in CoasterDesigns.BUILT_IN:
		if str(r.name).begins_with(str(CoasterDesigns.BUILT_IN[id].name)):
			return id
	return ""


## The camera on the whole of a ride's track, from the front; with
## `window`, off to the left of the ride window.
func _frame_ride(game: Game, r: Dictionary, window := false) -> void:
	var pts: PackedVector3Array = Track.build(r).points
	var lo := Vector2(INF, INF)
	var hi := -lo
	for q in pts:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	var distance := maxf(hi.x - lo.x, hi.y - lo.y) + 5.0
	_look(game, (lo + hi) / 2.0, distance, 35.0, 38.0, false)
	if window:
		game.cam.pan(Vector2(distance * 0.2, 0.0))
		game.cam.snap()


# --- The coaster builder -------------------------------------------------

func _shoot_builder() -> void:
	var game := await _open(_builder_park())
	var p := game.park
	var station := Vector2i(23, 3)
	_look(game, Vector2(26, 9), 22.0)
	game.choose("design:little_woody")
	game.station_dir = 0
	await _point(game, station)
	await _snap("builder", "design-little-woody", "Placing Little Woody", "A ready-made coaster follows the cursor, green where it fits. Turn turns it.")
	game.choose("design:timber_twister")
	var spot := _design_spot(p, "timber_twister", Vector2i(26, 9))
	game.station_dir = spot[1]
	await _point(game, spot[0])
	await _snap("builder", "design-timber-twister", "Placing Timber Twister", "The bigger ready-made coaster, with its price beside the tool's name.")
	game.choose("design:little_woody")
	game.station_dir = 0
	_look(game, Vector2(17, 24), 20.0)
	await _point(game, Vector2i(16, 22))
	await _snap("builder", "design-blocked", "Where it won't fit", "Red where something's in the way, with the reason underneath.")

	game.choose("coaster_wood")
	game.station_dir = 0
	_look(game, Vector2(23.5, 6), 14.0)
	await _point(game, station)
	await _snap("builder", "station", "A station", "Building your own coaster starts with a station. Turn turns it and Look changes its length.")
	_look(game, Vector2(18.5, 27), 14.0)
	await _point(game, Vector2i(18, 26))
	await _snap("builder", "station-blocked", "A station that won't go", "Stations need clear ground: not footpaths, shops or other rides.")

	var r := p.add_coaster(station, 0, 4)
	game._changed()
	game.edit_track(r)
	game.cam.distance = 13.0
	await _ghost(game, [0, 0, 0], "track-start", "The track builder", "Track goes on piece by piece from the station. The panel picks the next piece's turn, slope and extras, and the ghost shows where it goes.")
	_lay(game, [[0, 0, 0]])
	await _ghost(game, [0, 1, 1], "track-lift", "A chain lift", "Chain lifts pull the train up. Slopes change one step at a time.")
	_lay(game, [[0, 1, 1]])
	await _ghost(game, [0, 2, 1], "track-steep-up", "Steep up", "From a slope, the next piece can go steeper.")
	_lay(game, [[0, 2, 1], [0, 2, 1], [0, 1, 1], [0, 0, 1]])
	await _ghost(game, [1, 0, 0], "track-left", "Left", "At the top of the lift, flat again: a tight turn to the left.")
	await _ghost(game, [2, 0, 0], "track-wide-left", "Wide left", "A wide turn takes more room and is gentler on riders.")
	await _ghost(game, [-1, 0, 0], "track-right", "Right", "A tight turn to the right.")
	await _ghost(game, [-2, 0, 0], "track-wide-right", "Wide right", "A wide turn to the right.")
	_lay(game, [[2, 0, 0]])
	game._leave_track()
	_look(game, Vector2(25, 9), 20.0, 35.0, 45.0, false)
	await _wait(0.8)
	await _snap("builder", "unfinished", "An unfinished coaster", "Stop building any time: the ride waits, closed, until its track comes back round to the station.")
	game.hud.close_window()
	game.edit_track(r)
	game.cam.distance = 13.0
	_lay(game, [[2, 0, 0]])
	await _ghost(game, [0, -1, 0], "track-down", "Down", "Over the top and down the other side.")
	_lay(game, [[0, -1, 0]])
	await _ghost(game, [0, -2, 0], "track-steep-down", "Steep down", "Steep drops make a ride more exciting, and more intense.")
	_lay(game, [[0, -2, 0]])
	await _ghost(game, [0, 0, 0], "track-blocked", "A piece that won't go", "Red means no, with the reason underneath: here the slope can only change one step at a time.")
	_lay(game, [[0, -2, 0], [0, -1, 0], [0, 0, 0]])
	await _ghost(game, [0, 0, 2], "track-brakes", "Brakes", "Brakes on the flat slow the train before the station.")
	_lay(game, [[0, 0, 2], [0, 0, 2], [0, 0, 0], [0, 0, 0], [0, 0, 0], [2, 0, 0]])
	await _ghost(game, [2, 0, 0], "track-last-piece", "The last piece", "The ghost meets the station: one more piece closes the circuit.")
	_lay(game, [[2, 0, 0]])

	# The circuit is closed, so the builder moves on to the doors.
	_look(game, Vector2(22.5, 4.5), 12.0, 35.0, 60.0)
	await _point(game, Vector2i(22, 4))
	await _snap("builder", "doors-entrance", "The entrance", "With the circuit closed, the entrance goes beside the station: the yellow tiles are the places it can go.")
	p.set_door(r, "ride_in", Vector2i(22, 4))
	game._changed()
	game._start_doors(r)
	await _point(game, Vector2i(22, 6))
	await _snap("builder", "doors-exit", "The exit", "Then the exit, on another of the yellow tiles.")
	p.set_door(r, "ride_out", Vector2i(22, 6))
	game._changed()
	game.set_mode(Game.Mode.EXPLORE)
	game.hud.show_ride(r)
	_frame_ride(game, r, true)
	_hide_cursor(game)
	_clear_toasts(game)
	await _wait(1.0)
	await _snap("builder", "finished", "A finished coaster", "Its test run rates it for excitement, intensity and nausea. Lead a queue line to the entrance, then open it.")
	_clear(game)
	game.choose("queue")
	_look(game, Vector2(21.5, 5), 10.0)
	await _point(game, Vector2i(21, 4))
	await _snap("builder", "queue-line", "A queue line", "Queue lines run from a footpath to a ride's entrance.")


## The track builder showing `piece` as the next one, with the end of the
## track off to the left of the builder's panel.
func _ghost(game: Game, piece: Array, file: String, title: String, note: String) -> void:
	game.set_piece(piece)
	game._focus_track_end()
	game.cam.pan(Vector2(game.cam.distance * 0.2, 0.0))
	game.cam.snap()
	await _wait(0.6)
	await _snap("builder", file, title, note)


## Builds pieces onto the ride in the track builder.
func _lay(game: Game, pieces: Array) -> void:
	for piece in pieces:
		game.set_piece(piece)
		var why := game.piece_error()
		if why != "":
			push_warning("Screenshot tour: piece %s: %s" % [piece, why])
		game.build_piece()
	game.cam.snap()


## Where a ready-made coaster fits nearest `near`: [tile, heading].
static func _design_spot(p: ParkData, design: String, near: Vector2i) -> Array:
	for t in _tiles_by_distance(p, near):
		for d in 4:
			if p.design_error(design, t, d) == "":
				return [t, d]
	return [near, 0]


# --- Building ------------------------------------------------------------

func _shoot_building() -> void:
	var game := await _open(_meadow_fair())
	var p := game.park
	_look(game, Vector2(18, 26), 18.0)
	_hide_cursor(game)
	var notes := {
		"paths": "Footpaths, and queue lines that lead to rides.",
		"rides": "The wooden coaster to build yourself, and the two ready-made ones.",
		"shops": "Food, drinks, toilets and the information kiosk.",
		"scenery": "Benches, bins, trees, flowers and tall grass.",
		"clear": "The bulldozer.",
	}
	for tab in Pieces.TABS:
		game.hud.open_build_menu()
		game.hud.build_menu._show_tab(tab[0], false)
		(game.hud.build_menu._items.get_child(0) as Control).grab_focus()
		await _wait(0.5)
		await _snap("building", "menu-" + str(tab[0]), "Build menu: %s" % tab[1], notes[tab[0]])
		_clear(game)
	var tools := [
		["path", Vector2i(20, 32), true, "path", "Footpaths", "Hold the button and move to keep laying. Guests only walk on footpaths."],
		["queue", Vector2i(10, 7), true, "queue", "Queue lines", "Queue lines lead from a footpath to a ride's entrance."],
		["food", Vector2i(17, 32), true, "shop", "A shop", "Shops go beside a footpath and turn to face it."],
		["tree_large", Vector2i(21, 25), true, "scenery", "Scenery", "Trees, flowers and benches. Turn turns them."],
		["food", Vector2i(24, 27), false, "shop-blocked", "A shop that won't go", "Shops need a footpath next to them."],
	]
	for t in tools:
		game.choose(t[0])
		var at := _free_tile(p, str(t[0]), t[1], t[2])
		_look(game, Vector2(at) + Vector2(0.5, 0.5), 10.0)
		await _wait(0.8)
		await _snap("building", t[3], t[4], t[5])
	game.choose("bulldoze")
	var tree := Vector2i(20, 24)
	for c in _tiles_by_distance(p, tree):
		if p.tiles.has(c) and p.tiles[c].get("wild", false):
			tree = c
			break
	_look(game, Vector2(tree) + Vector2(0.5, 0.5), 10.0)
	await _wait(0.8)
	await _snap("building", "bulldozer", "The bulldozer", "Clears a tile and gives half its price back. Hold the button to keep clearing.")


## The tile nearest `near` that's empty and where `id` can (or, with `ok`
## false, can't) be built; a footpath or queue goes beside a footpath.
static func _free_tile(p: ParkData, id: String, near: Vector2i, ok: bool) -> Vector2i:
	for t in _tiles_by_distance(p, near):
		if p.kind_at(t) != "" or (p.build_error(id, t) == "") != ok:
			continue
		if Pieces.kind(id) in ["path", "queue"] and not _beside_path(p, t):
			continue
		return t
	return near


# --- Windows -------------------------------------------------------------

func _shoot_windows() -> void:
	var game := await _open(_meadow_fair())
	var p := game.park
	_hide_cursor(game)
	var shop := Vector2i(-1, -1)
	for t in p.tiles:
		if str(p.tiles[t].id) == "food":
			shop = t
	_look(game, Vector2(shop) + Vector2(-1.5, 1.0), 12.0, 35.0, 50.0, false)
	game.hud.show_stall(shop)
	await _wait(0.6)
	await _snap("windows", "shop", "A shop", "What it sells, what it has taken and its price.")
	_clear(game)
	var guest: Guest = _chatty_guest(game.sim, Vector2(shop))
	_look(game, guest.pos, 7.0, 35.0, 40.0, false)
	game.hud.show_guest(guest)
	await _wait(0.6)
	await _snap("windows", "guest", "A guest", "What they're doing, what they think, their money and their needs.")
	_clear(game)
	_look(game, Vector2(15, 22), 28.0, 35.0, 48.0, false)
	for tab in [["park", "The park", "The rating, guests, happiness and the date, the goal, the entry fee and renaming."],
			["money", "Money", "This month's money in and out, and last month's."],
			["staff", "Staff", "The janitors, to hire or let go."]]:
		game.hud.show_park(tab[0])
		await _wait(0.6)
		await _snap("windows", "park-" + str(tab[0]), tab[1], tab[2])
	_clear(game)
	var r: Dictionary = p.rides[0]
	game.hud.show_ride(r)
	game.hud.window._rename_ride(r)
	await _wait(0.6)
	await _snap("windows", "rename-ride", "Renaming a ride", "Rides, and parks, take any name up to 24 letters.")
	_clear(game)
	game.hud.open_pause()
	await _wait(0.6)
	await _snap("windows", "pause", "The pause menu", "The park stops while it's open: save, how to play, tips, autosave, or back to the title screen.")
	game.hud.pause_menu._show_howto()
	await _wait(0.6)
	await _snap("windows", "pause-howto", "How to play, from the pause menu", "The same pages as on the title screen, over the park.")
	game.hud.howto.close()
	_clear(game)


## A guest near `near` with something on their mind, if there is one.
static func _chatty_guest(sim: ParkSim, near: Vector2) -> Guest:
	var all: Array = sim.guests.duplicate()
	all.sort_custom(func(a: Guest, b: Guest) -> bool: return a.pos.distance_to(near) < b.pos.distance_to(near))
	for g in all:
		if g.thought != "" and g.state == Guest.State.WALK:
			return g
	return all[0]


# --- Menus ---------------------------------------------------------------

func _shoot_menus() -> void:
	if ParkLibrary.list().is_empty():
		# Shot on its own: a couple of parks (without pictures) to list.
		ParkLibrary.save(_meadow_fair())
		ParkLibrary.save(ParkData.create("Blank Slate", "empty", true, 5))
	LGScenes.change_scene("res://game/ui/title.tscn")
	var title: Node = await LGScenes.scene_changed
	await _wait(1.0)
	title._show_welcome()
	await _snap_menu("welcome", "Welcome", "The first time the game starts: the tutorial, or straight into Meadow Fair.")
	title._show_main()
	await _snap_menu("title", "The title screen", "Carry on with the last park, or pick another. The sample park runs behind the menus.")
	title._show_library()
	await _snap_menu("library", "Your parks", "Every park is kept, with a picture from when it was last saved, most recently played first.")
	var meta: Dictionary = ParkLibrary.list()[0]
	var id := str(meta.id)
	title._show_park(id)
	await _snap_menu("park", "A saved park", "Play it, copy it, rename it or delete it.")
	title._ask_name("Rename the park", str(meta.name), title._rename.bind(id))
	await _snap_menu("rename", "Renaming a park", "A name box that works with a controller too.")
	title._confirm_delete(id, str(meta.name))
	await _snap_menu("delete", "Deleting a park", "Deleting asks first. The other parks stay.")
	title._show_new()
	await _snap_menu("new", "New park", "Start a scenario, or a sandbox on either map.")
	title._show_scenario("meadow_fair")
	await _snap_menu("scenario", "Meadow Fair", "The scenario's story, goal and starting money.")
	title._ask_name("Name your park", ParkLibrary.unique_name("My park"), title._start_sandbox.bind("meadow"))
	await _snap_menu("sandbox-name", "Naming a sandbox park", "Sandbox parks get a name before they start.")
	title._show_settings()
	await _snap_menu("settings", "Settings", "The shared settings, plus tips during play and how often to autosave.")
	title._show_about()
	await _snap_menu("about", "About", "Credits and licenses.")
	title._show_main()
	title._show_tutorial()
	var panel: HowToPanel = null
	for c in title._ui.get_children():
		if c is HowToPanel:
			panel = c
	var pages := HowToPanel.pages()
	for i in pages.size():
		if i > 0:
			panel._go(1)
		await _snap_menu("howto-%d" % (i + 1), "How to play: %s" % pages[i].title, "Page %d of %d." % [i + 1, pages.size()])
	panel.close()


func _snap_menu(file: String, title: String, note: String) -> void:
	await _wait(0.6)
	await _snap("menus", file, title, note)


# --- Parks to show -------------------------------------------------------

## Meadow Fair a couple of months in, built up from the sample park.
static func _meadow_fair() -> ParkData:
	var p := Scenarios.start("meadow_fair", 7)
	SamplePark.build(p)
	_play(p, 1, 2400)
	return p


## A busy sandbox park: the sample park and a Timber Twister.
static func _sunny_hollow() -> ParkData:
	var p := ParkData.create("Sunny Hollow", "meadow", true, 11)
	SamplePark.build(p)
	_add_coaster(p, "timber_twister", Vector2i(27, 11))
	_play(p, 2, 2400)
	return p


## The sample park with the trees cleared on its right, for building on.
static func _builder_park() -> ParkData:
	var p := ParkData.create("Sunny Hollow", "meadow", true, 11)
	SamplePark.build(p)
	for t in p.tiles.keys():
		if p.tiles[t].get("wild", false) and t.x >= 21 and t.x <= 30 and t.y <= 18:
			p.tiles.erase(t)
	_play(p, 1, 900)
	return p


## Runs a park for `steps` tenths of a second, with janitors, and keeps its
## guests.
static func _play(p: ParkData, janitors: int, steps: int) -> void:
	var sim := ParkSim.new(p, 5)
	for i in janitors:
		sim.hire_janitor()
	for i in steps:
		sim.step(ParkSim.STEP)
	sim.store()


## Puts a ready-made coaster as near `near` as it fits, with its entrance at
## the end of a queue line and its exit on a footpath, both joined to the
## park's paths, and opens it.
static func _add_coaster(p: ParkData, design: String, near: Vector2i) -> Dictionary:
	for t in _tiles_by_distance(p, near):
		for d in 4:
			if p.design_error(design, t, d) != "":
				continue
			var r := p.add_design(design, t, d)
			if _add_doors(p, r):
				r.open = p.ride_open_error(r) == ""
				return r
			p.demolish_ride(r)
	push_warning("Screenshot tour: no room for %s" % design)
	return {}


## An entrance and an exit beside the station, each where the way to a
## footpath is shortest, with the tiles between laid as queue or path.
static func _add_doors(p: ParkData, r: Dictionary) -> bool:
	for kind in ["ride_in", "ride_out"]:
		var best = null
		var door := Vector2i.ZERO
		for t in p.ride_door_tiles(r):
			if p.door_error(r, t) != "":
				continue
			var way = _way_to_path(p, t)
			if way != null and (best == null or way.size() < best.size()):
				best = way
				door = t
		if best == null:
			return false
		p.set_door(r, kind, door)
		for i in best.size():
			p.build("queue" if kind == "ride_in" and i < 3 else "path", best[i])
	return true


## Free tiles from beside `from` to beside a footpath, nearest `from` first:
## [] when `from` is beside one already, null when there's no way.
static func _way_to_path(p: ParkData, from: Vector2i) -> Variant:
	if _beside_path(p, from):
		return []
	var came := {from: from}
	var todo := [from]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		for n in p.neighbours(t):
			if came.has(n) or not p.kind_at(n) in ["", "scenery"] or p.build_error("path", n) != "":
				continue
			came[n] = t
			if _beside_path(p, n):
				var out := [n]
				while came[out[0]] != from:
					out.push_front(came[out[0]])
				return out
			todo.append(n)
	return null


static func _beside_path(p: ParkData, t: Vector2i) -> bool:
	for n in p.neighbours(t):
		if p.is_path(n):
			return true
	return false


static func _tiles_by_distance(p: ParkData, near: Vector2i) -> Array:
	var out := []
	for x in p.size.x:
		for z in p.size.y:
			out.append(Vector2i(x, z))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - near).length_squared() < (b - near).length_squared())
	return out


# --- Helpers -------------------------------------------------------------

func _open(p: ParkData) -> Game:
	Game.open(p)
	await LGScenes.scene_changed
	return get_tree().current_scene as Game


## A new park's tips again, once it has settled: a slow first frame
## (software rendering takes seconds) can outlast the ones it opened with.
func _welcome(game: Game) -> void:
	await _wait(0.5)
	_clear_toasts(game)
	game.welcome()
	await _wait(0.6)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Points the camera at `focus` (x, z on the ground) from `distance` away,
## turned `yaw` and tilted `pitch` degrees, with the cursor there too
## unless `cursor` is false.
func _look(game: Game, focus: Vector2, distance: float, yaw := 35.0, pitch := 50.0, cursor := true) -> void:
	game.cam.focus = Vector3(focus.x, 0, focus.y)
	game.cam.distance = distance
	game.cam.yaw = deg_to_rad(yaw)
	game.cam.pitch = deg_to_rad(pitch)
	game.cam.snap()
	if cursor:
		game.cursor = focus


## The cursor on a tile, and a moment for the tool's ghost to appear.
func _point(game: Game, t: Vector2i) -> void:
	game.cursor = Vector2(t) + Vector2(0.5, 0.5)
	await _wait(0.6)


## Off the map, where it isn't drawn.
static func _hide_cursor(game: Game) -> void:
	game.cursor = Vector2(-50, -50)


## Back to looking round the park: no windows, menus, tools or messages.
static func _clear(game: Game) -> void:
	game.hud.build_menu.close()
	game.hud.window.close()
	game.hud.pause_menu.close()
	game.hud._close_goal()
	game.set_mode(Game.Mode.EXPLORE)
	_clear_toasts(game)


static func _clear_toasts(game: Game) -> void:
	for t in game.hud._toasts.get_children():
		t.queue_free()


func _snap(group: String, file: String, title: String, note: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := _root.path_join(group)
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_jpg(dir.path_join(file + ".jpg"), 0.85)
	_taken.append([group, file, title, note])
	print("Saved ", group, "/", file, ".jpg")


## README.md beside the pictures, listing them all under their groups.
func _write_index() -> void:
	var lines := ["# Screenshots", "", "Every screen of %s, at the game's own size (1280 x 800), made with Mesa's software Vulkan (mesa-vulkan-drivers) so they use the game's own renderer:" % GameConfig.TITLE, "", "    " + COMMAND, ""]
	for g in GROUPS:
		var n := _taken.filter(func(s: Array) -> bool: return s[0] == g[0]).size()
		if n > 0:
			lines.append("- [%s](#%s) (%d)" % [g[1], str(g[1]).to_lower().replace(" ", "-"), n])
	lines.append("")
	for g in GROUPS:
		var shots := _taken.filter(func(s: Array) -> bool: return s[0] == g[0])
		if shots.is_empty():
			continue
		lines += ["## " + g[1], "", g[2], ""]
		for s in shots:
			lines += ["**%s.** %s" % [s[2], s[3]], "", "![%s](%s/%s.jpg)" % [s[2], s[0], s[1]], ""]
	var f := FileAccess.open(_root.path_join("README.md"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("Wrote ", _root.path_join("README.md"))
