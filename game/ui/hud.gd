class_name Hud
extends CanvasLayer
## What's on screen over the park: the top bar (money, guests, rating, date,
## speed), button prompts for the current tool, messages, the build menu,
## the track builder's panel, info windows and the pause menu.

const TOAST_TIME := 5.0
const SPEED_TEXT := ["Normal speed", "Fast", "Fastest"]

var game: Game
var root: Control
var build_menu: BuildMenu
var window: InfoWindow
var pause_menu: PauseMenu
var howto: HowToPanel
var _money: Label
var _guests: Label
var _rating: Label
var _date: Label
var _speed: Label
var _name: Label
var _prompts: HBoxContainer
var _toasts: VBoxContainer
var _ghost_error: Label
var _track_panel: PanelContainer
var _track_labels := {}
var _tool_label: Label
var _goal_panel: PanelContainer
var _refresh_timer := 0.0


func setup(p_game: Game) -> void:
	game = p_game
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_bar()
	_prompts = HBoxContainer.new()
	_prompts.add_theme_constant_override("separation", 22)
	_prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompts)
	_prompts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	_prompts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tool_label = LGUi.label("", "NameLabel")
	_tool_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_tool_label)
	_tool_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	_tool_label.position.y -= 50
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(_toasts)
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.position.y = 70
	_toasts.custom_minimum_size.x = 700
	_toasts.position.x -= 350
	_ghost_error = LGUi.label("")
	_ghost_error.add_theme_color_override("font_color", Color("ff8a7a"))
	_ghost_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost_error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ghost_error)
	_ghost_error.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ghost_error.offset_top -= 150
	_ghost_error.offset_bottom -= 150
	_build_track_panel()
	build_menu = BuildMenu.new()
	root.add_child(build_menu)
	build_menu.setup(game)
	window = InfoWindow.new()
	root.add_child(window)
	window.setup(game)
	howto = HowToPanel.new()
	root.add_child(howto)
	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	pause_menu.setup(game)
	refresh()


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "DarkPanel"
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)
	_name = LGUi.label("", "NameLabel")
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	row.add_child(_name)
	_money = LGUi.label("")
	_money.add_theme_color_override("font_color", Color("ffd54a"))
	row.add_child(_money)
	_guests = LGUi.label("")
	row.add_child(_guests)
	_rating = LGUi.label("")
	row.add_child(_rating)
	_date = LGUi.label("")
	row.add_child(_date)
	_speed = LGUi.label("")
	_speed.add_theme_color_override("font_color", Color("9fe0ff"))
	row.add_child(_speed)


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		refresh()
	for t in _toasts.get_children():
		var age: float = Time.get_ticks_msec() / 1000.0 - float(t.get_meta("born"))
		if age > TOAST_TIME:
			t.queue_free()
		elif age > TOAST_TIME - 1.0:
			t.modulate.a = TOAST_TIME - age


func refresh() -> void:
	var p := game.park
	_name.text = p.name
	_money.text = "Sandbox" if p.sandbox else money(p.money)
	_guests.text = "%d guests" % game.sim.guests.size()
	_rating.text = "Rating %d" % game.sim.rating
	_date.text = p.date_text()
	_speed.text = "Paused" if game.paused else SPEED_TEXT[game.speed_index]
	window.refresh()


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if n < 0 else "$") + s + out


func has_focus_inside() -> bool:
	return root.get_viewport().gui_get_focus_owner() != null or pause_menu.visible or howto.visible


func visible_for_snapshot(on: bool) -> void:
	root.visible = on


## A message across the top for a few seconds.
func toast(text: String) -> void:
	while _toasts.get_child_count() >= 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = "GlassPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("born", Time.get_ticks_msec() / 1000.0)
	var l := LGUi.label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	_toasts.add_child(panel)


func set_ghost_error(text: String) -> void:
	_ghost_error.text = text


# --- Tools ---------------------------------------------------------------

func on_mode_changed() -> void:
	for c in _prompts.get_children():
		_prompts.remove_child(c)
		c.queue_free()
	_ghost_error.text = ""
	var rows := []
	var tool := ""
	match game.mode:
		Game.Mode.EXPLORE:
			rows = [["place", "Look"], ["build_menu", "Build"], ["park_menu", "Park"], ["speed", "Speed"], ["pause", "Menu"]]
		Game.Mode.BUILD:
			tool = "%s  %s" % [Pieces.name_of(game.build_id), money(Pieces.cost(game.build_id))]
			rows = [["place", "Build (hold to keep going)" if Pieces.kind(game.build_id) != "stall" else "Build"], ["cancel", "Done"]]
			if Pieces.kind(game.build_id) == "scenery" and game.build_id != "bench":
				rows.append(["rotate", "Turn"])
			rows.append(["build_menu", "Build menu"])
		Game.Mode.BULLDOZE:
			tool = "Bulldozer"
			rows = [["place", "Clear (hold to keep going)"], ["cancel", "Done"]]
		Game.Mode.STATION:
			tool = "Wooden coaster station, %d tiles  %s" % [game.station_len, money(Pieces.cost("coaster_wood") + Pieces.STATION_COST * game.station_len)]
			rows = [["place", "Place the station"], ["rotate", "Turn"], ["inspect", "Length"], ["cancel", "Back"]]
		Game.Mode.DESIGN:
			var d := CoasterDesigns.get_design(game.design_id)
			tool = "%s  %s" % [d.get("name", ""), money(ParkData.design_cost(game.design_id))]
			rows = [["place", "Place"], ["rotate", "Turn"], ["cancel", "Back"]]
		Game.Mode.TRACK:
			tool = "Building %s" % game.ride.get("name", "")
			rows = [["place", "Add piece"], ["cancel", "Remove last piece"], ["inspect", "Stop building"]]
		Game.Mode.DOORS:
			tool = "Place the %s for %s" % ["entrance" if game.door_kind == "ride_in" else "exit", game.ride.get("name", "")]
			rows = [["place", "Place it beside the station"], ["cancel", "Done"]]
	for r in rows:
		_prompts.add_child(ActionPrompt.make(r[0], r[1], 34))
	_tool_label.text = tool
	_tool_label.visible = tool != ""
	_track_panel.visible = game.mode == Game.Mode.TRACK
	# Why a piece won't go stays clear of the track builder's panel.
	_ghost_error.offset_right = -_track_panel.get_combined_minimum_size().x - 24.0 if _track_panel.visible else 0.0
	if _track_panel.visible:
		_refresh_track_panel()


func _build_track_panel() -> void:
	_track_panel = PanelContainer.new()
	_track_panel.theme_type_variation = "DarkPanel"
	_track_panel.visible = false
	root.add_child(_track_panel)
	_track_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_track_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_track_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_track_panel.add_child(col)
	col.add_child(LGUi.label("Next piece", "HeaderMedium"))
	for row in [["turn", "step_left", "Turn"], ["slope", "step_up", "Slope"], ["extra", "rotate", "Extra"]]:
		var h := HBoxContainer.new()
		var prev := _small_button("", _track_step.bind(row[0], -1))
		prev.icon = _arrow(true)
		var next := _small_button("", _track_step.bind(row[0], 1))
		next.icon = _arrow(false)
		var l := LGUi.label("")
		l.custom_minimum_size.x = 230
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(prev)
		h.add_child(l)
		h.add_child(next)
		col.add_child(ActionPrompt.make(row[1], row[2], 28))
		col.add_child(h)
		_track_labels[row[0]] = l
	_track_labels.cost = LGUi.label("", "HintLabel")
	col.add_child(_track_labels.cost)
	var add := _small_button("Add piece", game.build_piece)
	add.custom_minimum_size.x = 300
	col.add_child(add)
	var undo := _small_button("Remove last piece", _track_undo)
	undo.custom_minimum_size.x = 300
	col.add_child(undo)
	var done := _small_button("Stop building", game._leave_track)
	done.custom_minimum_size.x = 300
	col.add_child(done)


## Buttons for the mouse only: the controller picks pieces with the D-pad,
## so these never take focus away from the park.
func _small_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(48, 44)
	b.pressed.connect(on_pressed)
	return b


## A small triangle pointing left or right, for the piece pickers.
static func _arrow(left: bool) -> ImageTexture:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	for y in 20:
		var half := 9 - absi(y - 9) if y < 19 else 0
		for x in half + 1:
			var px := 15 - x if left else 4 + x
			img.set_pixel(px, y, LGTheme.INK)
	return ImageTexture.create_from_image(img)


func _track_undo() -> void:
	game._cancel()


func _track_step(what: String, dir: int) -> void:
	var p: Array = game.piece.duplicate()
	match what:
		"turn":
			var i := clampi(Game.TURNS.find(int(p[0])) + dir, 0, Game.TURNS.size() - 1)
			p[0] = Game.TURNS[i]
			if p[0] != 0:
				p[1] = 0
		"slope":
			p[1] = clampi(int(p[1]) + dir, -2, 2)
			if p[1] != 0:
				p[0] = 0
		"extra":
			p[2] = posmod(int(p[2]) + dir, 3)
	game.set_piece(p)


func _refresh_track_panel() -> void:
	var p: Array = game.piece
	_track_labels.turn.text = Track.TURN_NAMES[int(p[0])]
	_track_labels.slope.text = str(Track.SLOPE_NAMES[int(p[1])]).capitalize()
	_track_labels.extra.text = ["Plain track", "Chain lift", "Brakes"][int(p[2])]
	_track_labels.cost.text = "Costs %s" % money(ParkData.piece_cost(p))


# --- Windows -------------------------------------------------------------

func open_build_menu() -> void:
	window.close()
	build_menu.open()


func close_window() -> void:
	window.close()


func show_ride(r: Dictionary) -> void:
	build_menu.close()
	window.show_ride(r)


func show_stall(t: Vector2i) -> void:
	build_menu.close()
	window.show_stall(t)


func show_guest(g: Guest) -> void:
	build_menu.close()
	window.show_guest(g)


func show_park(tab := "park") -> void:
	build_menu.close()
	window.show_park(tab)


func open_pause() -> void:
	build_menu.close()
	window.close()
	pause_menu.open()


## The scenario's result, over everything until it's dismissed.
func show_goal(state: String) -> void:
	if _goal_panel:
		_goal_panel.queue_free()
	_goal_panel = PanelContainer.new()
	_goal_panel.theme_type_variation = "ParchmentPanel"
	root.add_child(_goal_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_goal_panel.add_child(col)
	var won := state == "won"
	col.add_child(LGUi.label("Scenario complete!" if won else "Out of time", "InkTitle"))
	var goal := Scenarios.goal_text(game.park.scenario)
	var text := LGUi.label("%s did it: %s\n\nThe park is yours to keep building." % [game.park.name, goal] if won else
		"The goal wasn't met in time: %s\n\nYou can keep playing this park, or start it again from the title screen." % goal, "InkLabel")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 560
	col.add_child(text)
	col.add_child(LGUi.button("OK", _close_goal))
	_goal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	LGScreenFit.center(_goal_panel)
	LGUi.focus_first(col)


func _close_goal() -> void:
	if _goal_panel:
		_goal_panel.queue_free()
		_goal_panel = null
