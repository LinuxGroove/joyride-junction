class_name PauseMenu
extends Control
## The pause menu. The park stops while it's open.

var game: Game
var _col: VBoxContainer
var _panel: PanelContainer
var _was_paused := false


func setup(p_game: Game) -> void:
	game = p_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "DarkPanel"
	center.add_child(_panel)
	LGScreenFit.center(_panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 10)
	_panel.add_child(_col)
	_col.add_child(LGUi.label("Paused", "HeaderMedium"))
	_col.add_child(LGUi.button("Resume", close, 440))
	_col.add_child(LGPlaytestButton.make(440))
	_col.add_child(LGUi.button("Save the park", _save, 440))
	_col.add_child(LGUi.button("How to play", _show_howto, 440))
	for row in [["Tips during play", "tutorial", "hints", SettingsPanel.ON_OFF],
			["Autosave", "play", "autosave_minutes", [[1, "Every minute"], [3, "Every 3 minutes"], [10, "Every 10 minutes"]]]]:
		_col.add_child(LGCycler.make(row[0], row[3], LGSettings.get_value(row[1], row[2]), _set_value.bind(row[1], row[2]), 440))
	var leave := LGUi.button("Save and go to the title screen", _leave, 440)
	leave.theme_type_variation = "DangerButton"
	_col.add_child(leave)


func _set_value(value: Variant, section: String, key: String) -> void:
	LGSettings.set_value(section, key, value)


func open() -> void:
	visible = true
	_panel.visible = true
	_was_paused = game.paused
	game.paused = true
	game.hud.refresh()
	LGUi.focus_first(_col)


func close() -> void:
	if not visible:
		return
	visible = false
	game.paused = _was_paused
	game.hud.refresh()
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()


func _save() -> void:
	close()
	await game.save_park()
	game.hud.toast("Saved %s." % game.park.name)


func _leave() -> void:
	visible = false
	game.quit_to_title()


func _show_howto() -> void:
	_panel.visible = false
	game.hud.howto.closed.connect(_back_from_howto, CONNECT_ONE_SHOT)
	game.hud.howto.open()


func _back_from_howto() -> void:
	if visible:
		_panel.visible = true
		LGUi.focus_first(_col)


func _unhandled_input(event: InputEvent) -> void:
	if visible and _panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
