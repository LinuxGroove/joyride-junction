class_name CoasterDesigns
extends RefCounted
## Ready-made coaster layouts (blueprints). Pieces are relative to the
## station, so a design fits any way round: only the station's tile and
## heading change. Players' own saved designs join these later.

const BUILT_IN := {
	"little_woody": {
		"name": "Little Woody",
		"blurb": "A gentle family coaster with one hill.",
		"station": 4,
		"pieces": [
			[0, 0, 0],
			[0, 1, 1], [0, 1, 1], [0, 1, 1], [0, 1, 1], [0, 1, 1],
			[0, 0, 1],
			[1, 0, 0], [1, 0, 0],
			[0, -1, 0], [0, -2, 0], [0, -1, 0], [0, 0, 0], [0, -1, 0], [0, 0, 0],
			[0, 0, 2], [0, 0, 2], [0, 0, 0], [0, 0, 0], [0, 0, 0],
			[1, 0, 0], [1, 0, 0],
		],
	},
	"timber_twister": {
		"name": "Timber Twister",
		"blurb": "A taller wooden coaster with two drops and wide turns.",
		"station": 5,
		"pieces": [
			[0, 0, 0],
			[0, 1, 1], [0, 2, 1], [0, 2, 1], [0, 2, 1], [0, 2, 1], [0, 1, 1], [0, 0, 1],
			[2, 0, 0], [2, 0, 0],
			[0, -1, 0], [0, -2, 0], [0, -2, 0], [0, -2, 0], [0, -1, 0], [0, 0, 0],
			[0, 1, 0], [0, 1, 0], [0, 0, 0],
			[0, -1, 0], [0, -1, 0], [0, -1, 0], [0, -1, 0], [0, 0, 0],
			[2, 0, 0], [2, 0, 0],
			[0, 0, 2],
		],
	},
}


static func get_design(id: String) -> Dictionary:
	return BUILT_IN.get(id, {})


## A ride dictionary for a design placed with its station at `tile`.
static func as_ride(id: String, tile: Vector2i, dir: int) -> Dictionary:
	var d := get_design(id)
	return {"station": {"tile": tile, "dir": dir, "length": int(d.station), "height": 0.0}, "pieces": d.pieces.duplicate(true)}
