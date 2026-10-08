extends Node
## Saves screenshots of menus or a park, for checking the look without a
## screen (run under xvfb-run, optionally with --resolution WxH):
##   godot --path . tools/screenshot.tscn -- out_prefix [options] [seconds...]
## Options:
##   title | welcome | library | park | new | about | howto   the title screen
##   window=ride|stall|guest|park|money|staff  build  track  doors  pause   in a park
## Menu shots use their own park library (user://screenshot-parks), with a
## few parks saved in it first.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "/tmp/shot"
	var times := []
	var opts := {}
	for i in range(1, args.size()):
		var a: String = args[i]
		if a.is_valid_float():
			times.append(float(a))
		elif "=" in a:
			opts[a.get_slice("=", 0)] = a.get_slice("=", 1)
		else:
			opts[a] = true
	if times.is_empty():
		times = [4.0]
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGInput.register_actions(GameConfig.ACTIONS)
	LGInput.extend_ui_actions()
	LGTheme.apply(get_tree().root, 22)
	LGSettings.set_value("play", "autosave_minutes", 10, false)
	if not opts.has("welcome"):
		LGSettings.set_value("tutorial", "welcomed", true, false)
	ParkLibrary.dir = "user://screenshot-parks/"
	get_tree().current_scene = null
	for menu in ["title", "welcome", "library", "park", "new", "about", "howto"]:
		if opts.has(menu):
			await _menus(prefix, menu)
			get_tree().quit()
			return
	var p := ParkData.create("Sample park", "meadow", false, 11)
	p.money = 8400
	SamplePark.build(p)
	Game.open(p)
	await LGScenes.scene_changed
	var game: Game = get_tree().current_scene as Game
	# Let a crowd build up.
	game.sim.hire_janitor()
	for i in 1200:
		game.sim.step(0.1)
	game.view.refresh()
	game.cam.focus = Vector3(13, 0, 15)
	game.cam.distance = 17.0
	game.cam.snap()
	var t := 0.0
	var n := 0
	for when in times:
		await get_tree().create_timer(when - t).timeout
		t = when
		if n == times.size() - 1:
			await _setup_park_shot(game, opts)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, n])
		n += 1
	get_tree().quit()


func _setup_park_shot(game: Game, opts: Dictionary) -> void:
	var w := str(opts.get("window", ""))
	match w:
		"ride":
			game.hud.show_ride(game.park.rides[0])
		"stall":
			for t in game.park.tiles:
				if game.park.tiles[t].k == "stall":
					game.hud.show_stall(t)
					break
		"guest":
			game.hud.show_guest(game.sim.guests[0])
		"park", "money", "staff":
			game.hud.show_park(w)
	if opts.has("build"):
		game.hud.open_build_menu()
		game.hud.build_menu._show_tab(str(opts.get("tab", "rides")), false)
	if opts.has("track") or opts.has("doors"):
		game.choose("coaster_wood")
		var r := game.park.add_coaster(Vector2i(24, 10), 0, 4)
		game._changed()
		game.edit_track(r)
		for piece in [[0, 0, 0], [0, 1, 1], [0, 1, 1], [0, 0, 1], [1, 0, 0]]:
			game.set_piece(piece)
			game.build_piece()
		game.set_piece([0, -1, 0])
		if opts.has("doors"):
			game.edit_doors(r, "ride_in")
		game.cam.distance = 13.0
		game.cam.snap()
	if opts.has("pause"):
		game.hud.open_pause()
	await get_tree().create_timer(0.5).timeout


func _menus(prefix: String, menu: String) -> void:
	for id in ["meadow_fair", "", ""]:
		var p := Scenarios.start(id) if id != "" else ParkData.create("My park", "empty", true)
		if id == "":
			SamplePark.build(p)
			p.name = ParkLibrary.unique_name("Sandbox park")
		ParkLibrary.save(p)
	LGScenes.change_scene("res://game/ui/title.tscn")
	var title: Node = await LGScenes.scene_changed
	await get_tree().create_timer(1.0).timeout
	match menu:
		"library":
			title._show_library()
		"park":
			title._show_park(str(ParkLibrary.list()[0].id))
		"new":
			title._show_new()
		"about":
			title._show_about()
		"howto":
			title._show_tutorial()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_0.png" % prefix)
	for m in ParkLibrary.list():
		ParkLibrary.delete(str(m.id))
