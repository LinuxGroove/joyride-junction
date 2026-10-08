extends Node
## The title screen: carry on with the last park, the park library (every
## park the player has made, to open, copy, rename or delete), a new park,
## how to play, settings, about and quit.

const TITLE_COLOR := Color("ffd23f")
const GAME := "res://game/game.tscn"

## Shown once when arriving here.
var message := ""

var _ui: Control
var _col: VBoxContainer
var _status: Label
var _about_scroll: ScrollContainer
var _list_scroll: ScrollContainer
## Set once a button has started leaving this screen, so a double press
## can't open two parks.
var _leaving := false


func _ready() -> void:
	add_child(MenuBackdrop.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.12, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	var version := LGUi.label("v%s" % GameConfig.version(), "HintLabel")
	_ui.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_col = LGUi.centered_column(_ui, 600)
	LGScreenFit.center(_col)
	LGAudio.play_music(GameConfig.MENU_MUSIC, -8.0)
	if not bool(LGSettings.get_value("tutorial", "welcomed", false)):
		_show_welcome()
	else:
		_show_main()


func _clear() -> void:
	# Detach before freeing, so focus_first can't grab a button on its way out.
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	_about_scroll = null
	_list_scroll = null
	_status = null


func _add_title() -> void:
	var title := LGUi.label(GameConfig.TITLE, "HeaderLarge")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_font_override("font", load("res://assets/kenney/fonts/Kenney Blocks.ttf"))
	_col.add_child(title)
	var tag := LGUi.label("Build the coasters. Feed the crowds. Keep the toilets clean.", "HintLabel")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(tag)


func _add_status(text := "") -> void:
	_status = LGUi.label(text, "HintLabel")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(_status)


func _show_main() -> void:
	_clear()
	_add_title()
	var parks := ParkLibrary.list()
	if not parks.is_empty():
		_col.add_child(LGUi.button("Carry on: %s" % parks[0].name, _play.bind(str(parks[0].id))))
		_col.add_child(LGUi.button("Your parks (%d)" % parks.size(), _show_library))
	_col.add_child(LGUi.button("New park", _show_new))
	_col.add_child(LGUi.button("How to play", _show_tutorial))
	_col.add_child(LGUi.button("Settings", _show_settings))
	_col.add_child(LGUi.button("About %s" % GameConfig.TITLE, _show_about))
	var quit := LGUi.button("Quit", _quit)
	quit.theme_type_variation = "DangerButton"
	_col.add_child(quit)
	_add_status(message)
	message = ""
	LGUi.focus_first(_col)


func _quit() -> void:
	get_tree().quit()


## Shown the first time the game starts.
func _show_welcome() -> void:
	LGSettings.set_value("tutorial", "welcomed", true)
	_clear()
	_add_title()
	var l := LGUi.label("New here? The tutorial is a few short pages on running a park. Then start Meadow Fair, the first scenario.", "HintLabel")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(l)
	_col.add_child(LGUi.button("Tutorial", _show_tutorial))
	_col.add_child(LGUi.button("Start Meadow Fair", _start_scenario.bind("meadow_fair")))
	_col.add_child(LGUi.button("Not now", _show_main))
	LGUi.focus_first(_col)


func _show_tutorial() -> void:
	_col.visible = false
	var panel := HowToPanel.new()
	_ui.add_child(panel)
	panel.closed.connect(_on_howto_closed.bind(panel))
	panel.open()


func _on_howto_closed(panel: HowToPanel) -> void:
	panel.queue_free()
	_col.visible = true
	_show_main()


# --- The park library ----------------------------------------------------

func _show_library() -> void:
	_clear()
	_col.add_child(LGUi.label("Your parks", "HeaderMedium"))
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.follow_focus = true
	_list_scroll.custom_minimum_size = Vector2(600, 470)
	_col.add_child(_list_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(list)
	for meta in ParkLibrary.list():
		list.add_child(_park_card(meta))
	_col.add_child(LGUi.button("Back", _show_main))
	LGUi.focus_first(_col)


func _park_card(meta: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(580, 108)
	b.pressed.connect(_show_park.bind(str(meta.id)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(148, 92)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture = ParkLibrary.thumbnail(str(meta.id))
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name := LGUi.label(str(meta.name), "NameLabel")
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name)
	var details := LGUi.label(_details(meta), "HintLabel")
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(details)
	return b


static func _details(meta: Dictionary) -> String:
	var kind: String = "Sandbox" if bool(meta.get("sandbox", false)) else str(Scenarios.get_def(str(meta.get("scenario", ""))).get("name", "Park"))
	if str(meta.get("goal_state", "")) == "won":
		kind += ", goal met"
	var money := "" if bool(meta.get("sandbox", false)) else ", %s" % Hud.money(int(meta.get("money", 0)))
	return "%s. %s\n%s, %s%s" % [kind, meta.get("date", ""), InfoWindow._count(int(meta.get("guests", 0)), "guest"), InfoWindow._count(int(meta.get("rides", 0)), "ride"), money]


func _show_park(id: String) -> void:
	var meta := {}
	for m in ParkLibrary.list():
		if str(m.id) == id:
			meta = m
	if meta.is_empty():
		_show_library()
		return
	_clear()
	_col.add_child(LGUi.label(str(meta.name), "HeaderMedium"))
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(400, 250)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = ParkLibrary.thumbnail(id)
	pic.visible = pic.texture != null
	_col.add_child(pic)
	_col.add_child(LGUi.label(_details(meta), "HintLabel"))
	_col.add_child(LGUi.button("Play", _play.bind(id)))
	_col.add_child(LGUi.button("Make a copy", _copy.bind(id, str(meta.name))))
	_col.add_child(LGUi.button("Rename", _ask_name.bind("Rename the park", str(meta.name), _rename.bind(id))))
	var del := LGUi.button("Delete", _confirm_delete.bind(id, str(meta.name)))
	del.theme_type_variation = "DangerButton"
	_col.add_child(del)
	_col.add_child(LGUi.button("Back", _show_library))
	_add_status()
	LGUi.focus_first(_col)


func _play(id: String) -> void:
	if _leaving or LGScenes.is_busy():
		return
	var p := ParkLibrary.load_park(id)
	if p == null:
		message = "That park couldn't be opened."
		_show_main()
		return
	_leaving = true
	Game.open(p)


func _copy(id: String, park_name: String) -> void:
	var new_id := ParkLibrary.copy(id, ParkLibrary.unique_name(park_name + " copy"))
	if new_id == "":
		_status.text = "The copy couldn't be saved."
		return
	_show_park(new_id)


func _rename(text: String, id: String) -> void:
	if text != "":
		ParkLibrary.rename(id, text)
	_show_park(id)


func _confirm_delete(id: String, park_name: String) -> void:
	_clear()
	_col.add_child(LGUi.label("Delete %s?" % park_name, "HeaderMedium"))
	var l := LGUi.label("It's gone for good. Your other parks stay.", "HintLabel")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(l)
	_col.add_child(LGUi.button("Keep it", _show_park.bind(id)))
	var del := LGUi.button("Delete it", _delete.bind(id))
	del.theme_type_variation = "DangerButton"
	_col.add_child(del)
	LGUi.focus_first(_col)


func _delete(id: String) -> void:
	ParkLibrary.delete(id)
	if ParkLibrary.list().is_empty():
		_show_main()
	else:
		_show_library()


## A name box; `done` gets the name typed ("" to go back).
func _ask_name(title: String, current: String, done: Callable) -> void:
	_clear()
	_col.add_child(LGUi.label(title, "HeaderMedium"))
	var edit := LineEdit.new()
	edit.max_length = 24
	edit.text = current
	edit.custom_minimum_size = Vector2(520, 56)
	LGUi.gamepad_text_entry(edit)
	_col.add_child(edit)
	edit.text_submitted.connect(_on_name_submitted.bind(done))
	_col.add_child(LGUi.button("OK", _on_name_ok.bind(edit, done)))
	_col.add_child(LGUi.button("Back", done.bind("")))
	edit.grab_focus.call_deferred()


func _on_name_submitted(text: String, done: Callable) -> void:
	done.call(text.strip_edges())


func _on_name_ok(edit: LineEdit, done: Callable) -> void:
	done.call(edit.text.strip_edges())


# --- New parks -----------------------------------------------------------

func _show_new() -> void:
	_clear()
	_col.add_child(LGUi.label("New park", "HeaderMedium"))
	var l := LGUi.label("Your other parks stay saved. You can go back to them any time.", "HintLabel")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(l)
	for id in Scenarios.LIST:
		var s: Dictionary = Scenarios.LIST[id]
		_col.add_child(LGUi.button("Scenario: %s" % s.name, _show_scenario.bind(id)))
	for map in ParkData.MAPS:
		_col.add_child(LGUi.button("Sandbox: %s" % ParkData.MAPS[map].name, _ask_name.bind("Name your park", ParkLibrary.unique_name("My park"), _start_sandbox.bind(map))))
	_col.add_child(LGUi.button("Back", _show_main))
	LGUi.focus_first(_col)


func _show_scenario(id: String) -> void:
	var s := Scenarios.get_def(id)
	_clear()
	_col.add_child(LGUi.label(str(s.name), "HeaderMedium"))
	for text in [str(s.blurb), "Goal: " + Scenarios.goal_text(id), "You start with %s." % Hud.money(int(s.money))]:
		var l := LGUi.label(text, "HintLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_col.add_child(l)
	_col.add_child(LGUi.button("Start", _start_scenario.bind(id)))
	_col.add_child(LGUi.button("Back", _show_new))
	LGUi.focus_first(_col)


func _start_scenario(id: String) -> void:
	if _leaving:
		return
	var p := Scenarios.start(id)
	p.name = ParkLibrary.unique_name(p.name)
	_start(p)


func _start_sandbox(text: String, map: String) -> void:
	if text == "":
		_show_new()
		return
	_start(ParkData.create(text, map, true))


func _start(p: ParkData) -> void:
	if _leaving or LGScenes.is_busy():
		return
	_leaving = true
	ParkLibrary.save(p)
	Game.open(p)


# --- Settings and about --------------------------------------------------

func _show_settings() -> void:
	_clear()
	_col.add_child(LGUi.label("Settings", "HeaderMedium"))
	var panel := SettingsPanel.new()
	_col.add_child(panel)
	for row in [["Tips during play", "tutorial", "hints", SettingsPanel.ON_OFF],
			["Autosave", "play", "autosave_minutes", [[1, "Every minute"], [3, "Every 3 minutes"], [10, "Every 10 minutes"]]]]:
		panel.add_child(LGCycler.make(row[0], row[3], LGSettings.get_value(row[1], row[2]), _set_value.bind(row[1], row[2])))
	_col.add_child(LGUi.button("Back", _show_main))
	LGUi.focus_first(_col)


func _set_value(value: Variant, section: String, key: String) -> void:
	LGSettings.set_value(section, key, value)


## Credits. Up and down scroll the page, since Back is the only button.
func _show_about() -> void:
	_clear()
	_col.add_child(LGUi.label("About %s" % GameConfig.TITLE, "HeaderMedium"))
	_about_scroll = ScrollContainer.new()
	_about_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_about_scroll.custom_minimum_size = Vector2(620, 460)
	_col.add_child(_about_scroll)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "GlassPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_about_scroll.add_child(panel)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = ABOUT_TEXT % [GameConfig.TITLE, GameConfig.version(), GameConfig.TITLE]
	panel.add_child(text)
	var back := LGUi.button("Back", _show_main)
	_col.add_child(back)
	back.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _about_scroll == null or not is_instance_valid(_about_scroll):
		return
	var step := 0
	if event.is_action_pressed("ui_down", true):
		step = 1
	elif event.is_action_pressed("ui_up", true):
		step = -1
	if step != 0:
		_about_scroll.scroll_vertical += step * 60
		get_viewport().set_input_as_handled()


const ABOUT_TEXT := """[center][b]%s[/b]  v%s
A LinuxGroove game

[b]Made by[/b]
The LinuxGroove team

[b]Art, sound, music and fonts[/b]
Kenney (kenney.nl)
Released under CC0. Thank you, Kenney!

Coaster Kit, Mini Characters, Emote Pack,
Input Prompts, UI Pack - Adventure, Kenney Fonts,
Music Loops, Interface Sounds, Casino Audio

[b]Made with[/b]
Godot Engine (godotengine.org), MIT
Nakama Godot client by Heroic Labs, Apache-2.0

Copyright (c) 2026 The LinuxGroove team
%s is free software under the MIT license.[/center]"""
