class_name Pieces
extends RefCounted
## Everything that can be built on a tile: what it's called, what it costs,
## which model draws it and which build menu tab it sits in.

const COASTER_KIT := "res://assets/kenney/coaster-kit/"

## Build menu tabs, in order.
const TABS := [
	["paths", "Paths"],
	["rides", "Rides"],
	["shops", "Shops"],
	["scenery", "Scenery"],
	["clear", "Clear"],
]

## id: [tab, name, cost, kind, model, hint]
## kind is the tile kind it makes: path, queue, stall, scenery, or a tool.
const ITEMS := {
	"path": ["paths", "Footpath", 10, "path", "path-straight", "Guests walk along these"],
	"queue": ["paths", "Queue line", 15, "queue", "queue-straight", "Lead it from a footpath to a ride's entrance"],
	"coaster_wood": ["rides", "Wooden coaster", 600, "coaster", "coaster-train-wooden", "Lay a station, then the track, piece by piece"],
	"food": ["shops", "Burger stall", 300, "stall", "stall-food", "Guests buy food here when they're hungry"],
	"drinks": ["shops", "Drinks stall", 250, "stall", "stall-drinks", "Guests buy drinks here when they're thirsty"],
	"toilets": ["shops", "Toilets", 200, "stall", "stall-toilets", "Everyone needs to go sometime"],
	"info": ["shops", "Information kiosk", 250, "stall", "stall-information", "Sells park maps; guests get lost less"],
	"bench": ["scenery", "Bench", 30, "scenery", "bench", "Tired guests sit here"],
	"bin": ["scenery", "Litter bin", 25, "scenery", "trash", "Guests drop less litter near bins"],
	"tree": ["scenery", "Tree", 20, "scenery", "tree", "Guests like greenery"],
	"tree_large": ["scenery", "Big tree", 35, "scenery", "tree-large", "Guests like greenery"],
	"flowers": ["scenery", "Flower bed", 15, "scenery", "flowers", "Guests like flowers"],
	"grass": ["scenery", "Tall grass", 5, "scenery", "grass", "A little greenery"],
	"bulldoze": ["clear", "Bulldozer", 0, "tool", "", "Clear what's on a tile; you get half its cost back"],
}

## Stall menus: what guests buy, and the starting price.
const STALLS := {
	"food": {"item": "Burger", "price": 4, "need": "hunger", "cost": 1},
	"drinks": {"item": "Lemonade", "price": 3, "need": "thirst", "cost": 1},
	"toilets": {"item": "Toilet", "price": 1, "need": "toilet", "cost": 0},
	"info": {"item": "Park map", "price": 2, "need": "", "cost": 0},
}

const SCENERY_APPEAL := {"tree": 1.0, "tree_large": 1.4, "flowers": 1.2, "grass": 0.4, "bench": 0.3, "bin": 0.0}

## Coaster track prices.
const TRACK_COST := 20
const LIFT_COST := 15
const STATION_COST := 40
const RIDE_ENTRANCE_COST := 50
## Clearing anything a player didn't build (trees on a new map).
const CLEAR_COST := 10

const JANITOR_HIRE := 100
const JANITOR_WAGE := 60


static func item(id: String) -> Array:
	return ITEMS.get(id, [])


static func tab_items(tab: String) -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id][0] == tab:
			out.append(id)
	return out


static func name_of(id: String) -> String:
	return ITEMS[id][1] if ITEMS.has(id) else id.capitalize()


static func cost(id: String) -> int:
	return int(ITEMS[id][2]) if ITEMS.has(id) else 0


static func kind(id: String) -> String:
	return ITEMS[id][3] if ITEMS.has(id) else ""


static func model(id: String) -> String:
	var m: String = ITEMS[id][4] if ITEMS.has(id) else ""
	return "" if m == "" else COASTER_KIT + m + ".glb"
