extends Node
## Boots the game: input map, theme and window, then the title screen.
##
## Developer shortcuts (after `--`):
##   --demo              skip the menus and open a ready-built sample park
##   --new               skip the menus and start Meadow Fair
##   --set=video/fullscreen=false   any setting, for one run

func _ready() -> void:
	LGSettings.register_defaults(GameConfig.SETTING_DEFAULTS)
	LGLaunchPing.send(GameConfig.GAME_ID)
	LGPlaytest.setup(GameConfig.GAME_ID, GameConfig.PLAYTEST)
	LGInput.register_actions(GameConfig.ACTIONS, float(LGSettings.get_value("input", "stick_deadzone")))
	LGInput.extend_ui_actions()
	LGTheme.apply(get_tree().root, 22)
	get_window().title = GameConfig.TITLE
	var args := OS.get_cmdline_user_args()
	if "--demo" in args:
		LGSettings.set_value("tutorial", "welcomed", true, false)
		var p := ParkData.create("Sample park", "meadow", true, 11)
		SamplePark.build(p)
		Game.open(p)
		return
	if "--new" in args:
		LGSettings.set_value("tutorial", "welcomed", true, false)
		Game.open(Scenarios.start("meadow_fair"))
		return
	LGScenes.change_scene("res://game/ui/title.tscn")
