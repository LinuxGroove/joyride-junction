class_name HowToPanel
extends Control
## The tutorial: a few pages on running a park, building paths and shops,
## coasters, guests and the controls. Opened from the title and pause menus.

signal closed

const CONTROLS := [
	["cursor_up", "Move the cursor (the camera follows)"],
	["step_up", "Move one tile; picks track pieces in the coaster builder"],
	["cam_left", "Turn and tilt the camera"],
	["zoom_in", "Zoom in"],
	["zoom_out", "Zoom out"],
	["place", "Build, or look at what's under the cursor"],
	["cancel", "Stop building, or close a window"],
	["rotate", "Turn what you're building"],
	["build_menu", "Build menu"],
	["park_menu", "Your park: money, staff, entry fee"],
	["speed", "Change speed"],
	["pause", "Pause"],
]

var _title: Label
var _body: Label
var _extra: VBoxContainer
var _count: Label
var _prev: Button
var _next: Button
var _page := 0


static func pages() -> Array:
	return [
		{"title": "Your park", "body":
			"You run a theme park. Guests pay to come in, ride your rides, eat, drink and need the toilet. Keep them happy and more will come.\n\nIn a scenario you have a goal and a deadline, shown in the park window. In a sandbox park, money's no object."},
		{"title": "Paths and shops", "body":
			"Guests only walk on footpaths, starting at the gate. Open the build menu and lay paths: hold the button and move to keep laying.\n\nShops go beside a path and face it. Put food, drinks and toilets where guests can find them, and benches and bins along the way."},
		{"title": "Coasters", "body":
			"Pick a ready-made coaster, or build your own: place the station, then add track piece by piece until it comes back round to the station. Chain lifts pull the train up hills.\n\nThen place an entrance and an exit beside the station, lead a queue line from a path to the entrance, and open the ride."},
		{"title": "Ratings", "body":
			"Every coaster gets a test run. Excitement is how much fun it is, intensity how wild, nausea how queasy it makes people.\n\nGuests ride what's exciting but not too intense for them. A ride that's too intense for anyone can't open: make the drops gentler."},
		{"title": "Happy guests", "body":
			"Look at a guest to see what they think. Hungry, thirsty or tired guests get grumpy, and so do guests wading through litter. Hire janitors to sweep.\n\nPrices matter too: charge too much at the gate, the shops or the rides and guests say no."},
		{"title": "Your parks are kept", "body":
			"Every park you start is saved on its own, and the game saves as you play. Start a new park any time from the title screen: your other parks stay where they are, ready to pick up again."},
		{"title": "Controls", "body": "", "controls": true},
	]


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "ParchmentPanel"
	panel.custom_minimum_size = Vector2(760, 500)
	center.add_child(panel)
	LGScreenFit.center(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	_title = LGUi.label("", "InkTitle")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_body = LGUi.label("", "InkLabel")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 700
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 6)
	_extra.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_extra)
	_count = LGUi.label("", "InkLabel")
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_count)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	_prev = LGUi.button("Previous", _go.bind(-1), 200)
	row.add_child(_prev)
	_next = LGUi.button("Next", _go.bind(1), 200)
	row.add_child(_next)


func open() -> void:
	_page = 0
	visible = true
	_show_page()
	_next.grab_focus.call_deferred()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _go(dir: int) -> void:
	_page += dir
	if _page >= pages().size():
		close()
		return
	_page = maxi(_page, 0)
	_show_page()
	(_prev if dir < 0 and _prev.visible else _next).grab_focus.call_deferred()


func _show_page() -> void:
	var all := pages()
	var page: Dictionary = all[_page]
	_title.text = page.title
	_body.text = page.body
	_body.visible = page.body != ""
	for c in _extra.get_children():
		_extra.remove_child(c)
		c.queue_free()
	_extra.visible = page.get("controls", false)
	if _extra.visible:
		for pair in CONTROLS:
			var holder := PanelContainer.new()
			holder.theme_type_variation = "GlassPanel"
			holder.add_child(ActionPrompt.make(pair[0], pair[1], 32))
			_extra.add_child(holder)
	_count.text = "%d / %d" % [_page + 1, all.size()]
	_prev.visible = _page > 0
	_next.text = "Done" if _page == all.size() - 1 else "Next"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
