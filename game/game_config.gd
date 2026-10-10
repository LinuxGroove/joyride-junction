class_name GameConfig
extends RefCounted
## Game-wide constants: identity, version, input map and setting defaults.

const GAME_ID := "joyride-junction"

## This round's own questions at the end of a play test (LGPlaytest), on top
## of the standard ones, and standard ones that don't fit the game. Change
## them for each round of play testing.
const PLAYTEST := {
	"skip": ["story"],
	"questions": [],
}
const TITLE := "Joyride Junction"

const SETTING_DEFAULTS := {
	"online": {
		"enabled": true,
		"host": OnlineServer.HOST,
		"port": OnlineServer.PORT,
		"scheme": OnlineServer.SCHEME,
		"server_key": OnlineServer.SERVER_KEY,
	},
	"tutorial": {
		"welcomed": false,
		"hints": true,
	},
	"play": {
		"edge_scroll": false,
		"autosave_minutes": 3,
	},
}

## Park music, one loop picked per visit.
const MUSIC := [
	"res://assets/kenney/audio/music/polka_train.ogg",
	"res://assets/kenney/audio/music/swinging_pants.ogg",
	"res://assets/kenney/audio/music/cheerful_annoyance.ogg",
]
const MENU_MUSIC := "res://assets/kenney/audio/music/wacky_waiting.ogg"

## Every in-game action, with keyboard and controller bindings (see LGInput).
## The cursor moves with the left stick; the D-pad steps it one tile at a
## time, and picks pieces in the coaster builder.
const ACTIONS := {
	"cursor_left": ["key:A", "axis:lx-"],
	"cursor_right": ["key:D", "axis:lx+"],
	"cursor_up": ["key:W", "axis:ly-"],
	"cursor_down": ["key:S", "axis:ly+"],
	"step_left": ["key:Left", "joy:left"],
	"step_right": ["key:Right", "joy:right"],
	"step_up": ["key:Up", "joy:up"],
	"step_down": ["key:Down", "joy:down"],
	"cam_left": ["key:Q", "axis:rx-"],
	"cam_right": ["key:E", "axis:rx+"],
	"cam_up": ["key:R", "axis:ry-"],
	"cam_down": ["key:F", "axis:ry+"],
	"zoom_in": ["key:Z", "axis:rt+"],
	"zoom_out": ["key:X", "axis:lt+"],
	"place": ["key:Space", "key:Enter", "mouse:left", "joy:a"],
	"cancel": ["key:Backspace", "mouse:right", "joy:b"],
	"rotate": ["key:T", "joy:x"],
	"build_menu": ["key:B", "joy:rb"],
	"inspect": ["key:I", "joy:y"],
	"speed": ["key:Tab", "joy:lb"],
	"park_menu": ["key:P", "joy:back"],
	"pause": ["key:Escape", "joy:start"],
}


static func version() -> String:
	return LGVersion.current()
