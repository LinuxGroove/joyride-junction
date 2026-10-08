class_name BuildMenu
extends PanelContainer
## The build menu: tabs along the top (paths, rides, shops, scenery,
## clear) and what each one builds, with prices. Picking something hands
## it to the game as the tool to build with.

var game: Game
var tab := "paths"
var _tabs: HBoxContainer
var _items: GridContainer
var _hint: Label


func setup(p_game: Game) -> void:
	game = p_game
	theme_type_variation = "DarkPanel"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 12)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	col.add_child(_tabs)
	for t in Pieces.TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 48)
		b.set_meta("tab", t[0])
		b.pressed.connect(_show_tab.bind(t[0], false))
		b.focus_entered.connect(_show_tab.bind(t[0], true))
		_tabs.add_child(b)
	_items = GridContainer.new()
	_items.columns = 4
	_items.add_theme_constant_override("h_separation", 8)
	_items.add_theme_constant_override("v_separation", 8)
	col.add_child(_items)
	_hint = LGUi.label("", "HintLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 760
	col.add_child(_hint)


func open() -> void:
	visible = true
	_show_tab(tab, false)
	var first := _items.get_child(0) as Control if _items.get_child_count() > 0 else null
	if first and not LGInput.mouse_recent():
		first.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	var f := get_viewport().gui_get_focus_owner()
	if f and is_ancestor_of(f):
		f.release_focus()


## Shows a tab's items. Moving focus onto a tab shows it without leaving
## the tab row, so the controller can browse tabs with left and right.
func _show_tab(t: String, from_focus: bool) -> void:
	if t == tab and _items.get_child_count() > 0 and from_focus:
		return
	tab = t
	for b in _tabs.get_children():
		(b as Button).button_pressed = b.get_meta("tab") == t
	for c in _items.get_children():
		_items.remove_child(c)
		c.queue_free()
	for entry in _entries(t):
		var b := Button.new()
		b.text = "%s\n%s" % [entry[1], Hud.money(entry[2]) if entry[2] > 0 else ""]
		b.custom_minimum_size = Vector2(190, 76)
		b.pressed.connect(_choose.bind(entry[0]))
		b.focus_entered.connect(_set_hint.bind(entry[3]))
		b.mouse_entered.connect(_set_hint.bind(entry[3]))
		_items.add_child(b)
	# Up from the items goes back to the tabs.
	for i in mini(_items.columns, _items.get_child_count()):
		var b := _items.get_child(i) as Control
		b.focus_neighbor_top = b.get_path_to(_tab_button(t))
	_tab_button(t).focus_neighbor_bottom = _tab_button(t).get_path_to(_items.get_child(0)) if _items.get_child_count() > 0 else NodePath()
	_set_hint("")


func _tab_button(t: String) -> Button:
	for b in _tabs.get_children():
		if b.get_meta("tab") == t:
			return b
	return null


## [id, name, cost, hint] for each thing on a tab. The rides tab has the
## build-your-own coaster and the ready-made designs.
static func _entries(t: String) -> Array:
	var out := []
	for id in Pieces.tab_items(t):
		var item := Pieces.item(id)
		out.append([id, item[1], int(item[2]), item[5]])
	if t == "rides":
		for d in CoasterDesigns.BUILT_IN:
			var design: Dictionary = CoasterDesigns.BUILT_IN[d]
			out.append(["design:" + d, design.name, ParkData.design_cost(d), "Ready-made: " + design.blurb])
	return out


func _set_hint(text: String) -> void:
	_hint.text = text


func _choose(id: String) -> void:
	close()
	game.choose(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("build_menu")):
		get_viewport().set_input_as_handled()
		close()
