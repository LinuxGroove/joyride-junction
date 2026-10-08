class_name InfoWindow
extends PanelContainer
## The window on the right for whatever the player looked at: a ride, a
## shop, a guest, or the park itself (with its money and staff). Numbers in
## it stay live; buttons act through the game.

const WIDTH := 440
const PRICES := 21

var game: Game
var _col: VBoxContainer
var _live: Callable
## What the window shows, so it can close when that thing goes away.
var _subject: Variant = null
var _confirm: Button


func setup(p_game: Game) -> void:
	game = p_game
	theme_type_variation = "DarkPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 0)
	offset_top = 64
	offset_bottom = -64
	offset_left = -WIDTH - 12
	offset_right = -12
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 8)
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_col)


func close() -> void:
	if not visible:
		return
	visible = false
	_subject = null
	_live = Callable()
	var f := get_viewport().gui_get_focus_owner()
	if f and is_ancestor_of(f):
		f.release_focus()


func refresh() -> void:
	if visible and _live.is_valid():
		_live.call()


func _begin(title: String, subject: Variant) -> void:
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	_subject = subject
	_confirm = null
	visible = true
	var t := LGUi.label(title, "HeaderMedium")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = WIDTH - 40
	t.name = "Title"
	_col.add_child(t)


func _finish() -> void:
	_col.add_child(_button("Close", close))
	refresh()
	if not LGInput.mouse_recent():
		LGUi.focus_first(_col)


func _line(text := "", variation := "") -> Label:
	var l := LGUi.label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 40
	_col.add_child(l)
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	return LGUi.button(text, on_pressed, WIDTH - 40)


func _bar(text: String) -> ProgressBar:
	var h := HBoxContainer.new()
	var l := LGUi.label(text)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.01
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(WIDTH - 180, 22)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	_col.add_child(h)
	return bar


## A danger button that asks to be pressed twice.
func _danger(text: String, on_confirmed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(WIDTH - 40, 56)
	b.theme_type_variation = "DangerButton"
	b.pressed.connect(_on_danger.bind(b, text, on_confirmed))
	return b


func _on_danger(b: Button, text: String, on_confirmed: Callable) -> void:
	if _confirm == b:
		_confirm = null
		on_confirmed.call()
		return
	_confirm = b
	b.text = "Press again to confirm"
	get_tree().create_timer(3.0).timeout.connect(_reset_danger.bind(b, text))


func _reset_danger(b: Button, text: String) -> void:
	if is_instance_valid(b) and _confirm == b:
		_confirm = null
		b.text = text


static func _count(n: int, what: String) -> String:
	return "%d %s%s" % [n, what, "" if n == 1 else "s"]


static func _price_options(top := PRICES) -> Array:
	var out := []
	for i in top:
		out.append([i, "Free" if i == 0 else "$%d" % i])
	return out


# --- Rides ---------------------------------------------------------------

func show_ride(r: Dictionary) -> void:
	_begin(str(r.name), r)
	var status := _line()
	var stats := _line("", "HintLabel")
	var path := Track.build(r)
	if path.complete:
		_col.add_child(_button("Close the ride" if r.open else "Open the ride", _toggle_ride.bind(r)))
		_col.add_child(LGCycler.make("Ticket", _price_options(), int(r.price), _set_ride_price.bind(r), WIDTH - 40))
		var cars := []
		for i in range(1, int(r.station.length) + 1):
			cars.append([i, "%d car%s, %d seats" % [i, "" if i == 1 else "s", i * 2]])
		_col.add_child(LGCycler.make("Train", cars, clampi(int(r.cars), 1, int(r.station.length)), _set_cars.bind(r), WIDTH - 40))
		_col.add_child(_button("Move the entrance", _doors.bind(r, "ride_in")))
		_col.add_child(_button("Move the exit", _doors.bind(r, "ride_out")))
	else:
		_col.add_child(_button("Build the track", _edit_track.bind(r)))
	_col.add_child(_button("Rename", _rename_ride.bind(r)))
	_col.add_child(_danger("Demolish", _demolish.bind(r)))
	_live = _live_ride.bind(r, status, stats)
	_finish()


func _live_ride(r: Dictionary, status: Label, stats: Label) -> void:
	if not r in game.park.rides:
		close()
		return
	var run: Dictionary = game.sim.runs.get(int(r.id), {})
	var why := game.park.ride_open_error(r) if not r.open else ""
	if r.open and run.get("join") == null:
		status.text = "Open, but guests can't get in: lead a queue line from a footpath to the entrance, or put the entrance beside a path."
	elif r.open:
		status.text = "Open. %d in the queue, %d riding." % [run.get("queue", []).size(), run.get("riders", []).size()]
	else:
		status.text = "Closed. " + (why if why != "" else "Ready to open.")
	var st: Dictionary = r.stats
	if st.get("ok", false):
		stats.text = "Excitement %.2f (%s)\nIntensity %.2f (%s)\nNausea %.2f (%s)\nTop speed %d km/h, %d m of track\n%s, the biggest %.1f m. A ride takes %d s.\n%d riders so far, %s taken." % [
			st.excitement, RidePhysics.describe(st.excitement), st.intensity, RidePhysics.describe(st.intensity),
			st.nausea, RidePhysics.describe(st.nausea), roundi(st.max_speed_kmh), roundi(st.length_m),
			_count(int(st.drops), "drop"), st.biggest_drop_m, roundi(st.duration), int(r.riders), Hud.money(int(r.income))]
	else:
		stats.text = "Ratings appear once the track is finished."


func _toggle_ride(r: Dictionary) -> void:
	var why := game.sim.set_ride_open(r, not r.open)
	if why != "":
		game.hud.toast(why)
	game._changed()
	show_ride(r)


func _set_ride_price(v: Variant, r: Dictionary) -> void:
	r.price = int(v)


func _set_cars(v: Variant, r: Dictionary) -> void:
	r.cars = int(v)
	game.sim.refresh()


func _doors(r: Dictionary, kind: String) -> void:
	close()
	game.edit_doors(r, kind)


func _edit_track(r: Dictionary) -> void:
	close()
	game.edit_track(r)


func _demolish(r: Dictionary) -> void:
	var refund := game.park.demolish_ride(r)
	game._changed()
	game.hud.toast("%s was demolished. %s back." % [r.name, Hud.money(refund)])
	close()


func _rename_ride(r: Dictionary) -> void:
	_ask_name("Rename the ride", str(r.name), _on_ride_named.bind(r))


func _on_ride_named(text: String, r: Dictionary) -> void:
	if text != "":
		r.name = text
	show_ride(r)


## A name box in the window; `done` gets the new name ("" to keep the old).
func _ask_name(title: String, current: String, done: Callable) -> void:
	_begin(title, _subject)
	var edit := LineEdit.new()
	edit.max_length = 24
	edit.text = current
	edit.custom_minimum_size = Vector2(WIDTH - 40, 52)
	LGUi.gamepad_text_entry(edit)
	_col.add_child(edit)
	edit.text_submitted.connect(_on_name_submitted.bind(done))
	_col.add_child(_button("OK", _on_name_ok.bind(edit, done)))
	_live = Callable()
	visible = true
	edit.grab_focus.call_deferred()


func _on_name_submitted(text: String, done: Callable) -> void:
	done.call(text.strip_edges())


func _on_name_ok(edit: LineEdit, done: Callable) -> void:
	done.call(edit.text.strip_edges())


# --- Shops ---------------------------------------------------------------

func show_stall(t: Vector2i) -> void:
	var tile: Dictionary = game.park.tiles[t]
	var info: Dictionary = Pieces.STALLS[str(tile.id)]
	_begin(Pieces.name_of(str(tile.id)), t)
	_line("Sells: %s" % info.item)
	var takings := _line("", "HintLabel")
	_col.add_child(LGCycler.make("Price", _price_options(13), int(tile.get("price", 0)), _set_stall_price.bind(t), WIDTH - 40))
	_col.add_child(_danger("Demolish", _demolish_stall.bind(t)))
	_live = _live_stall.bind(t, takings)
	_finish()


func _live_stall(t: Vector2i, takings: Label) -> void:
	if game.park.kind_at(t) != "stall":
		close()
		return
	takings.text = "Taken so far: %s" % Hud.money(int(game.park.tiles[t].get("income", 0)))


func _set_stall_price(v: Variant, t: Vector2i) -> void:
	if game.park.kind_at(t) == "stall":
		game.park.tiles[t].price = int(v)


func _demolish_stall(t: Vector2i) -> void:
	game.park.bulldoze(t)
	game._changed()
	close()


# --- Guests --------------------------------------------------------------

func show_guest(g: Guest) -> void:
	_begin(g.name, g)
	var mood := _line()
	var thought := _line("", "HintLabel")
	var money := _line()
	var bars := {}
	for n in [["hunger", "Hunger"], ["thirst", "Thirst"], ["toilet", "Toilet"], ["energy", "Energy"]]:
		bars[n[0]] = _bar(n[1])
	var likes := _line("", "HintLabel")
	_live = _live_guest.bind(g, mood, thought, money, bars, likes)
	_finish()


func _live_guest(g: Guest, mood: Label, thought: Label, money: Label, bars: Dictionary, likes: Label) -> void:
	if not g in game.sim.guests:
		mood.text = "Gone home."
		_live = Callable()
		return
	mood.text = "%s. %s" % [g.mood_word(), _doing(g)]
	thought.text = "\"%s\"" % g.thought if g.thought != "" else ""
	money.text = "Has %s and has spent %s. %s so far." % [Hud.money(g.money), Hud.money(g.spent), _count(g.rides_taken, "ride")]
	for k in bars:
		(bars[k] as ProgressBar).value = float(g.get(k))
	likes.text = "Rides up to intensity %.1f." % g.thrill


func _doing(g: Guest) -> String:
	match g.state:
		Guest.State.QUEUE:
			return "Queuing for %s." % _ride_name(g.ride_id)
		Guest.State.RIDE:
			return "Riding %s." % _ride_name(g.ride_id)
		Guest.State.SHOP:
			return "Buying something."
		Guest.State.SIT:
			return "Having a rest."
		Guest.State.LEAVE:
			return "Heading home."
	match str(g.goal.get("kind", "")):
		"ride":
			return "Going to %s." % _ride_name(int(g.goal.ride))
		"stall":
			return "Looking for a shop."
		"bench":
			return "Looking for a bench."
	return "Walking around."


func _ride_name(id: int) -> String:
	var r := game.park.ride(id)
	return str(r.name) if not r.is_empty() else "a ride"


# --- The park ------------------------------------------------------------

func show_park(tab := "park") -> void:
	var p := game.park
	_begin(p.name, "park:" + tab)
	var tabs := HBoxContainer.new()
	for t in [["park", "Park"], ["money", "Money"], ["staff", "Staff"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_pressed = t[0] == tab
		b.custom_minimum_size = Vector2((WIDTH - 52) / 3.0, 48)
		b.pressed.connect(show_park.bind(t[0]))
		tabs.add_child(b)
	_col.add_child(tabs)
	match tab:
		"park":
			var info := _line()
			var goal := _line("", "HintLabel")
			goal.text = Scenarios.goal_text(p.scenario) if p.scenario != "" else "Sandbox: build whatever you like, money's no object."
			if p.goal_state == "won":
				goal.text += " Done!"
			elif p.goal_state == "lost":
				goal.text += " Time ran out, but you can keep building."
			var fees := [[0, "Free"]]
			for i in range(2, 61, 2):
				fees.append([i, "$%d" % i])
			_col.add_child(LGCycler.make("Entry fee", fees, p.entry_fee, _set_fee, WIDTH - 40))
			_col.add_child(_button("Rename the park", _rename_park))
			_live = _live_park.bind(info)
		"money":
			var lines := _line()
			_live = _live_money.bind(lines)
		"staff":
			_line("Janitors sweep up litter. They cost %s to hire and %s a month." % [Hud.money(Pieces.JANITOR_HIRE), Hud.money(Pieces.JANITOR_WAGE)], "HintLabel")
			for s in p.staff:
				_col.add_child(_danger("Let %s go" % s.name, _fire.bind(int(s.id))))
			_col.add_child(_button("Hire a janitor", _hire))
			_live = Callable()
	_finish()


func _live_park(info: Label) -> void:
	var p := game.park
	var s := game.sim
	info.text = "Rating %d. %d guests in the park, %d visits in all.\nHappiness %d%%. %s." % [
		s.rating, s.guests.size(), p.total_guests, roundi(s.average_happiness() * 100.0), p.date_text()]


func _live_money(lines: Label) -> void:
	var p := game.park
	var out := ["Cash: %s" % ("unlimited" if p.sandbox else Hud.money(p.money))]
	if p.finances.is_empty():
		out.append("Nothing earned or spent yet this month.")
	else:
		var m: Dictionary = p.finances[p.finances.size() - 1]
		out.append("\nThis month")
		for k in m.in:
			out.append("  %s: +%s" % [k, Hud.money(int(m.in[k]))])
		for k in m.out:
			out.append("  %s: -%s" % [k, Hud.money(int(m.out[k]))])
		if p.finances.size() > 1:
			var last := p.month_totals(1)
			out.append("\nLast month: in %s, out %s" % [Hud.money(int(last.in)), Hud.money(int(last.out))])
	lines.text = "\n".join(out)


func _set_fee(v: Variant) -> void:
	game.park.entry_fee = int(v)


func _rename_park() -> void:
	_ask_name("Rename the park", game.park.name, _on_park_named)


func _on_park_named(text: String) -> void:
	if text != "":
		game.park.name = text
	game.hud.refresh()
	show_park("park")


func _hire() -> void:
	var why := game.sim.hire_janitor()
	if why != "":
		game.hud.toast(why)
	show_park("staff")


func _fire(id: int) -> void:
	game.sim.fire_janitor(id)
	show_park("staff")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and get_viewport().gui_get_focus_owner() != null and is_ancestor_of(get_viewport().gui_get_focus_owner()):
		get_viewport().set_input_as_handled()
		close()
