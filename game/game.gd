class_name Game
extends Node3D
## A park being played: the simulation, its 3D view, the camera, the grid
## cursor and the building tools. The HUD (Hud) shows the numbers and the
## windows; this node owns what the controls do in each tool.
##
## Start one with Game.open(park): the scene picks it up from `park`.

enum Mode { EXPLORE, BUILD, BULLDOZE, STATION, DESIGN, TRACK, DOORS }

const SCENE := "res://game/game.tscn"
const SPEEDS := [1.0, 2.0, 4.0]
const CURSOR_SPEED := 9.0
const TURNS := [2, 1, 0, -1, -2]
const SLOPE_ORDER := [-2, -1, 0, 1, 2]

## The park to play; set before the scene enters the tree.
var park: ParkData
var sim: ParkSim
var view: ParkView
var cam: ParkCamera
var hud: Hud
var mode := Mode.EXPLORE
var speed_index := 0
var paused := false
## The cursor on the ground, in tiles, and the tile it's over.
var cursor := Vector2.ZERO
var cursor_tile := Vector2i.ZERO
## What the BUILD tool places, and which way round.
var build_id := ""
var build_rot := 0
## Coaster station or ready-made design being placed.
var station_dir := 0
var station_len := 4
var design_id := ""
## The ride whose track, entrance or exit is being built.
var ride: Dictionary = {}
## The next piece in the track builder: [turn, slope, extra].
var piece := [0, 0, 0]
## Which door DOORS places next: "ride_in" or "ride_out".
var door_kind := "ride_in"

var _cursor_node: Node3D
var _cursor_mat: StandardMaterial3D
var _ghost: Node3D
var _ghost_key := ""
var _marks: Node3D
var _mouse_mode := false
var _painting := false
var _last_painted := Vector2i(-999, -999)
var _orbiting := false
var _orbit_moved := 0.0
var _autosave_at := 0.0
var _last_error := ""


## Opens a park in the game scene.
static func open(p: ParkData) -> void:
	LGScenes.change_scene(SCENE, _set_park.bind(p))


static func _set_park(node: Node, p: ParkData) -> void:
	(node as Game).park = p


func _ready() -> void:
	if park == null:
		park = Scenarios.start("meadow_fair")
	sim = ParkSim.new(park)
	view = ParkView.new()
	add_child(view)
	view.setup(park, sim)
	cam = ParkCamera.new()
	cam.bounds = Rect2(-2, -2, park.size.x + 4, park.size.y + 4)
	cam.focus = ParkView.tile_center(park.arrival_tile() + Vector2i(0, -6))
	add_child(cam)
	cam.snap()
	cursor = Vector2(cam.focus.x, cam.focus.z)
	_build_cursor()
	_marks = Node3D.new()
	add_child(_marks)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	sim.message.connect(_on_sim_message)
	sim.goal_changed.connect(_on_goal_changed)
	_autosave_at = _autosave_seconds()
	LGAudio.play_music(GameConfig.MUSIC[randi() % GameConfig.MUSIC.size()], -10.0)
	set_mode(Mode.EXPLORE)
	if park.rides.is_empty() and park.total_guests == 0:
		hint("Welcome to %s! Open the build menu to lay footpaths and build your first ride." % park.name)
		if park.scenario != "":
			hint("Goal: " + Scenarios.goal_text(park.scenario))


## A tip, unless the player turned tips off.
func hint(text: String) -> void:
	if bool(LGSettings.get_value("tutorial", "hints", true)):
		hud.toast(text)


func _autosave_seconds() -> float:
	return maxf(30.0, float(LGSettings.get_value("play", "autosave_minutes", 3)) * 60.0)


func _build_cursor() -> void:
	_cursor_node = Node3D.new()
	_cursor_mat = StandardMaterial3D.new()
	_cursor_mat.albedo_color = Color("ffd54a")
	_cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var bar := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(1.04, 0.05, 0.07) if i < 2 else Vector3(0.07, 0.05, 1.04)
		m.material = _cursor_mat
		bar.mesh = m
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var o := 0.5 if i % 2 == 0 else -0.5
		bar.position = Vector3(0, 0.06, o) if i < 2 else Vector3(o, 0.06, 0)
		_cursor_node.add_child(bar)
	add_child(_cursor_node)


# --- Modes ---------------------------------------------------------------

func set_mode(m: Mode) -> void:
	mode = m
	_painting = false
	_clear_ghost()
	view.grid = m != Mode.EXPLORE
	_update_marks()
	hud.on_mode_changed()


## Picks something from the build menu.
func choose(id: String) -> void:
	if id == "bulldoze":
		set_mode(Mode.BULLDOZE)
	elif id == "coaster_wood":
		station_dir = cam.heading_up()
		set_mode(Mode.STATION)
	elif id.begins_with("design:"):
		design_id = id.trim_prefix("design:")
		station_dir = cam.heading_up()
		set_mode(Mode.DESIGN)
	else:
		build_id = id
		set_mode(Mode.BUILD)


## Opens the track builder on a ride (closing it first if it's running).
func edit_track(r: Dictionary) -> void:
	if r.open:
		sim.set_ride_open(r, false)
	ride = r
	piece = [0, 0, 0]
	if Track.build(r).complete:
		_start_doors(r)
		return
	set_mode(Mode.TRACK)
	_focus_track_end()


func edit_doors(r: Dictionary, kind: String) -> void:
	ride = r
	door_kind = kind
	set_mode(Mode.DOORS)
	var tiles := park.ride_door_tiles(r)
	if not tiles.is_empty():
		_move_cursor_to(Vector2(tiles[0]) + Vector2(0.5, 0.5))


func _start_doors(r: Dictionary) -> void:
	ride = r
	if not r.has("entrance") or park.kind_at(r.entrance) != "ride_in":
		edit_doors(r, "ride_in")
		hint("Put the entrance and exit beside the station. Then lead a queue line from a footpath to the entrance, and open the ride.")
	elif not r.has("exit") or park.kind_at(r.exit) != "ride_out":
		edit_doors(r, "ride_out")
	else:
		set_mode(Mode.EXPLORE)
		hud.show_ride(r)


func _focus_track_end() -> void:
	var end: Dictionary = Track.build(ride).end
	var p: Vector3 = end.pos
	cam.focus = Vector3(p.x, 0, p.z)
	cursor = Vector2(p.x, p.z)


func _move_cursor_to(p: Vector2) -> void:
	cursor = p
	cam.focus = Vector3(p.x, 0, p.y)


# --- Every frame ---------------------------------------------------------

func _process(delta: float) -> void:
	var game_speed: float = 0.0 if paused else SPEEDS[speed_index]
	view.sim_speed = game_speed
	if game_speed > 0.0:
		sim.step(delta * game_speed)
		park.play_seconds += delta
	_autosave_at -= delta
	if _autosave_at <= 0.0:
		_autosave_at = _autosave_seconds()
		save_park()
	if not hud.has_focus_inside():
		_read_controls(delta)
	cursor_tile = Vector2i(floori(cursor.x), floori(cursor.y))
	_cursor_node.position = ParkView.tile_center(cursor_tile)
	_cursor_node.visible = mode != Mode.TRACK and park.in_bounds(cursor_tile)
	_update_ghost()
	if _painting and Input.is_action_pressed("place"):
		if cursor_tile != _last_painted:
			_place(true)
	else:
		_painting = false


func _read_controls(delta: float) -> void:
	# Camera: right stick or Q/E/R/F to orbit and tilt, triggers or Z/X to zoom.
	var turn := Input.get_axis("cam_left", "cam_right")
	var tilt := Input.get_axis("cam_down", "cam_up")
	if turn != 0.0 or tilt != 0.0:
		cam.orbit(-turn * delta * 2.2, tilt * delta * 1.4)
	var z := Input.get_action_strength("zoom_out") - Input.get_action_strength("zoom_in")
	if z != 0.0:
		cam.zoom(1.0 + z * delta * 1.8)
	# Cursor: left stick or WASD glides; the camera follows when it nears an edge.
	var v := Vector2(Input.get_axis("cursor_left", "cursor_right"), Input.get_axis("cursor_up", "cursor_down"))
	if v.length() > 0.05:
		_mouse_mode = false
		var g := cam.screen_to_ground(v.limit_length(1.0))
		cursor += g * delta * CURSOR_SPEED * clampf(cam.distance / 18.0, 0.6, 2.0)
		cursor = cursor.clamp(Vector2(-1.5, -1.5), Vector2(park.size) + Vector2(1.5, 1.5))
		_follow_cursor()
	if _mouse_mode:
		var at = cam.ground_at(get_viewport().get_mouse_position())
		if at != null:
			cursor = Vector2(at.x, at.z)
	if mode == Mode.TRACK:
		return
	for pair in [["step_left", Vector2(-1, 0)], ["step_right", Vector2(1, 0)], ["step_up", Vector2(0, -1)], ["step_down", Vector2(0, 1)]]:
		if Input.is_action_just_pressed(pair[0]):
			_mouse_mode = false
			var g := cam.screen_to_ground(pair[1])
			var step := Vector2(roundf(g.x), roundf(g.y)) if absf(g.x) > 0.38 and absf(g.y) > 0.38 else (Vector2(signf(g.x), 0) if absf(g.x) > absf(g.y) else Vector2(0, signf(g.y)))
			cursor = Vector2(cursor_tile) + Vector2(0.5, 0.5) + step
			_follow_cursor()


func _follow_cursor() -> void:
	var c := Vector3(cursor.x, 0, cursor.y)
	var off := c - cam.focus
	var limit := cam.distance * 0.3
	if off.length() > limit:
		cam.focus += off.normalized() * (off.length() - limit)
		cam._clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_mode = true
		# The mouse is over the park, not a window: the park has the controls.
		if get_viewport().gui_get_focus_owner():
			get_viewport().gui_release_focus()
		if _orbiting:
			var rel := (event as InputEventMouseMotion).relative
			_orbit_moved += rel.length()
			cam.orbit(-rel.x * 0.006, rel.y * 0.004)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom(0.9)
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom(1.1)
				return
			MOUSE_BUTTON_MIDDLE:
				_orbiting = mb.pressed
				_orbit_moved = 0.0
				return
			MOUSE_BUTTON_RIGHT:
				# Right-drag turns the camera; a right click cancels.
				if mb.pressed:
					_orbiting = true
					_orbit_moved = 0.0
				else:
					_orbiting = false
					if _orbit_moved < 6.0:
						_cancel()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("pause"):
		hud.open_pause()
	elif event.is_action_pressed("speed"):
		speed_index = (speed_index + 1) % SPEEDS.size()
		hud.refresh()
	elif event.is_action_pressed("build_menu"):
		hud.open_build_menu()
	elif event.is_action_pressed("park_menu"):
		hud.show_park()
	elif mode == Mode.TRACK and _track_input(event):
		pass
	elif event.is_action_pressed("place"):
		_place(false)
	elif event.is_action_pressed("cancel") and not (event is InputEventMouseButton):
		_cancel()
	elif event.is_action_pressed("rotate"):
		_rotate()
	elif event.is_action_pressed("inspect"):
		_inspect_key()
	else:
		return
	get_viewport().set_input_as_handled()


func _cancel() -> void:
	match mode:
		Mode.EXPLORE:
			hud.close_window()
		Mode.TRACK:
			if not ride.pieces.is_empty():
				park.remove_last_piece(ride)
				_changed()
				_focus_track_end()
			else:
				_leave_track()
		Mode.DOORS:
			set_mode(Mode.EXPLORE)
			hud.show_ride(ride)
		_:
			set_mode(Mode.EXPLORE)


func _leave_track() -> void:
	var r := ride
	set_mode(Mode.EXPLORE)
	hud.show_ride(r)


func _rotate() -> void:
	match mode:
		Mode.BUILD:
			build_rot = (build_rot + 1) % 4
		Mode.STATION, Mode.DESIGN:
			station_dir = (station_dir + 1) % 4
	_ghost_key = ""


func _inspect_key() -> void:
	match mode:
		Mode.STATION:
			station_len = station_len + 1 if station_len < Track.MAX_STATION else Track.MIN_STATION
			_ghost_key = ""
			hud.on_mode_changed()
		Mode.EXPLORE:
			_inspect()


# --- Placing -------------------------------------------------------------

func _place(painting: bool) -> void:
	_last_painted = cursor_tile
	var t := cursor_tile
	match mode:
		Mode.EXPLORE:
			_inspect()
		Mode.BUILD:
			var kind := Pieces.kind(build_id)
			var why := park.build_error(build_id, t)
			if why != "":
				if not painting:
					_error(why)
				# Paint over what's already there without complaint.
				_painting = kind != "stall"
				return
			park.build(build_id, t, _rotation_for(build_id, t))
			_painting = kind != "stall"
			_changed()
			LGAudio.play_sfx("res://assets/kenney/audio/sfx/drop_002.ogg", -6.0, 0.1)
		Mode.BULLDOZE:
			var what := _ride_at(t)
			if not what.is_empty():
				if not painting:
					hud.show_ride(what)
					set_mode(Mode.EXPLORE)
				return
			if park.tiles.has(t) and not park.kind_at(t) in ["entrance", "ride_in", "ride_out"]:
				park.bulldoze(t)
				_changed()
				LGAudio.play_sfx("res://assets/kenney/audio/sfx/drop_003.ogg", -6.0, 0.1)
			elif not painting and park.kind_at(t) == "entrance":
				_error("The park gate stays")
			_painting = true
		Mode.STATION:
			var why := park.station_error(t, station_dir, station_len)
			if why != "":
				_error(why)
				return
			var r := park.add_coaster(t, station_dir, station_len)
			_changed()
			edit_track(r)
		Mode.DESIGN:
			var why := park.design_error(design_id, t, station_dir)
			if why != "":
				_error(why)
				return
			var r := park.add_design(design_id, t, station_dir)
			_changed()
			_start_doors(r)
		Mode.DOORS:
			var why := park.door_error(ride, t)
			if why != "":
				_error(why)
				return
			park.set_door(ride, door_kind, t)
			_changed()
			if door_kind == "ride_in":
				_start_doors(ride)
			else:
				set_mode(Mode.EXPLORE)
				hud.show_ride(ride)


## Stalls and benches face a footpath next to them; other things turn freely.
func _rotation_for(id: String, t: Vector2i) -> int:
	if id == "bench":
		for r in 4:
			if park.is_path(t + Track.DIRS[r]):
				return r
	return build_rot


func _error(text: String) -> void:
	hud.toast(text)
	LGAudio.play_sfx("res://assets/kenney/audio/sfx/error_004.ogg", -8.0)


## Called after anything is built or removed.
func _changed() -> void:
	sim.refresh()
	view.refresh()
	_ghost_key = ""
	_update_marks()
	hud.refresh()


## The ride with a station, door or track on `t`, if any.
func _ride_at(t: Vector2i) -> Dictionary:
	var st := park.station_at(t)
	if not st.is_empty():
		return st
	if park.tiles.has(t) and park.tiles[t].has("ride"):
		return park.ride(int(park.tiles[t].ride))
	for r in park.rides:
		if Track.ride_tiles(r).has(t):
			return r
	return {}


func _inspect() -> void:
	var g := view.guest_near(cursor, 0.6)
	if g:
		hud.show_guest(g)
		return
	var t := cursor_tile
	var r := _ride_at(t)
	if not r.is_empty():
		hud.show_ride(r)
		return
	match park.kind_at(t):
		"stall":
			hud.show_stall(t)
		"entrance":
			hud.show_park()
		_:
			for j in sim.janitors:
				if (j.pos as Vector2).distance_to(cursor) < 0.6:
					hud.show_park("staff")
					return


# --- Track builder -------------------------------------------------------

## D-pad or arrows pick the piece, rotate cycles chain lift and brakes.
func _track_input(event: InputEvent) -> bool:
	if event.is_action_pressed("step_left") or event.is_action_pressed("step_right"):
		var i := TURNS.find(int(piece[0]))
		i = clampi(i + (1 if event.is_action_pressed("step_right") else -1), 0, TURNS.size() - 1)
		piece[0] = TURNS[i]
		if piece[0] != 0:
			piece[1] = 0
	elif event.is_action_pressed("step_up") or event.is_action_pressed("step_down"):
		piece[1] = clampi(int(piece[1]) + (1 if event.is_action_pressed("step_up") else -1), -2, 2)
		if piece[1] != 0:
			piece[0] = 0
	elif event.is_action_pressed("rotate"):
		piece[2] = (int(piece[2]) + 1) % 3
	elif event.is_action_pressed("place"):
		build_piece()
		return true
	elif event.is_action_pressed("inspect"):
		_leave_track()
		return true
	else:
		return false
	_ghost_key = ""
	hud.on_mode_changed()
	return true


## Sets the next piece (from the HUD's buttons).
func set_piece(p: Array) -> void:
	piece = p.duplicate()
	_ghost_key = ""
	hud.on_mode_changed()


func piece_error() -> String:
	if ride.is_empty():
		return ""
	return park.piece_error(ride, piece)


func build_piece() -> void:
	var why := piece_error()
	if why != "":
		_error(why)
		return
	park.add_piece(ride, piece.duplicate())
	LGAudio.play_sfx("res://assets/kenney/audio/sfx/drop_002.ogg", -6.0, 0.1)
	# Track ends flat after a slope: keep going the way it was going.
	var end: Dictionary = Track.build(ride).end
	if int(end.slope) != int(piece[1]):
		piece[1] = int(end.slope)
	if piece[2] == Track.BRAKES and int(piece[1]) != 0:
		piece[2] = 0
	_changed()
	_focus_track_end()
	if Track.build(ride).complete:
		ride.stats = {}
		var why_not := park.ride_open_error(ride)
		hud.toast("The circuit is complete!" if why_not.begins_with("Add an") or why_not == "" else why_not)
		_start_doors(ride)
	else:
		hud.on_mode_changed()


# --- Ghosts and marks ----------------------------------------------------

func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_ghost_key = ""


func _update_ghost() -> void:
	var key := "%d/%s/%s/%d/%d/%s/%s" % [mode, cursor_tile, build_id, build_rot, station_dir, station_len, piece]
	if key == _ghost_key:
		return
	_ghost_key = key
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	var t := cursor_tile
	var ok := true
	match mode:
		Mode.BUILD:
			var model := Pieces.model(build_id)
			if model == "":
				return
			ok = park.build_error(build_id, t) == ""
			_ghost = view.make_ghost(model, ok)
			var r := _rotation_for(build_id, t)
			if Pieces.kind(build_id) == "stall":
				var side := -1
				for d in 4:
					if park.is_path(t + Track.DIRS[d]):
						side = d
						break
				r = side if side >= 0 else build_rot
				_ghost.rotation.y = ParkView.turn(2, r)
			elif Pieces.kind(build_id) in ["path", "queue"]:
				_ghost.rotation.y = 0.0
			else:
				_ghost.rotation.y = ParkView.turn(0, r)
			_ghost.position = ParkView.tile_center(t)
		Mode.STATION:
			ok = park.station_error(t, station_dir, station_len) == ""
			_ghost = Node3D.new()
			for st in Track.station_tiles({"tile": t, "dir": station_dir, "length": station_len}):
				var s := view.make_ghost("station", ok)
				s.position = ParkView.tile_center(st)
				s.rotation.y = ParkView.turn(0, station_dir)
				_ghost.add_child(s)
		Mode.DESIGN:
			ok = park.design_error(design_id, t, station_dir) == ""
			var r := CoasterDesigns.as_ride(design_id, t, station_dir)
			_ghost = view.make_ghost_track(Track.build(r).points, ok)
		Mode.DOORS:
			if ride.is_empty() or not t in park.ride_door_tiles(ride):
				return
			ok = park.door_error(ride, t) == ""
			_ghost = view.make_ghost("ride-entrance" if door_kind == "ride_in" else "ride-exit", ok)
			var st_tiles := Track.station_tiles(ride.station)
			for d in 4:
				if (t - Track.DIRS[d]) in st_tiles:
					_ghost.rotation.y = ParkView.turn(2, d)
			_ghost.position = ParkView.tile_center(t)
		Mode.TRACK:
			if ride.is_empty():
				return
			ok = piece_error() == ""
			var end: Dictionary = Track.build(ride).end
			var pts: PackedVector3Array = Track.piece_points(end, piece).points
			pts.insert(0, end.pos)
			_ghost = view.make_ghost_track(pts, ok)
		_:
			return
	add_child(_ghost)
	hud.set_ghost_error("" if ok else _ghost_error())


func _ghost_error() -> String:
	match mode:
		Mode.BUILD:
			return park.build_error(build_id, cursor_tile)
		Mode.STATION:
			return park.station_error(cursor_tile, station_dir, station_len)
		Mode.DESIGN:
			return park.design_error(design_id, cursor_tile, station_dir)
		Mode.TRACK:
			return piece_error()
		Mode.DOORS:
			return park.door_error(ride, cursor_tile)
	return ""


## Highlights the tiles a ride's entrance or exit can go on.
func _update_marks() -> void:
	for c in _marks.get_children():
		c.queue_free()
	if mode != Mode.DOORS or ride.is_empty():
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for t in park.ride_door_tiles(ride):
		if park.door_error(ride, t) != "":
			continue
		var q := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(0.9, 0.9)
		pm.material = m
		q.mesh = pm
		q.position = ParkView.tile_center(t, 0.03)
		_marks.add_child(q)


# --- Park events ---------------------------------------------------------

func _on_sim_message(text: String) -> void:
	hud.toast(text)


func _on_goal_changed(state: String) -> void:
	hud.show_goal(state)
	LGAudio.play_sfx("res://assets/kenney/audio/sfx/confirmation_002.ogg" if state == "won" else "res://assets/kenney/audio/sfx/error_006.ogg")


## Saves the park to the library, with a picture of the view without the HUD.
func save_park() -> void:
	var img: Image = null
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		hud.visible_for_snapshot(false)
		_cursor_node.visible = false
		await RenderingServer.frame_post_draw
		img = get_viewport().get_texture().get_image()
		hud.visible_for_snapshot(true)
	ParkLibrary.save(park, sim, img)


## Saves and goes back to the title screen.
func quit_to_title() -> void:
	await save_park()
	LGScenes.change_scene("res://game/ui/title.tscn")
