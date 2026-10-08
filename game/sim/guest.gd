class_name Guest
extends RefCounted
## One visitor. Needs run from 0 (fine) to 1 (urgent); happiness and energy
## from 0 (miserable, worn out) to 1.

enum State { WALK, QUEUE, RIDE, SHOP, SIT, LEAVE }

const LOOKS := 12

var id := 0
var name := ""
var look := 0
var wheelchair := false
## World position on the ground (x, z), and the tile it's on.
var pos := Vector2.ZERO
var tile := Vector2i.ZERO
## Tiles still to walk, nearest first.
var route: Array = []
## Where on a tile this guest walks, so crowds spread out.
var lane := 0.0
var state := State.WALK
## What the guest is heading for: {"kind": "ride"|"stall"|"bench"|"wander"|"exit", ...}.
var goal := {}
var money := 50
var spent := 0
var happiness := 0.7
var energy := 1.0
var hunger := 0.2
var thirst := 0.2
var toilet := 0.1
var nausea := 0.0
## The most intense ride this guest will go on.
var thrill := 5.0
var timer := 0.0
var ride_id := -1
## Food or a drink in hand, finished when the timer runs out.
var holding := ""
var hold_timer := 0.0
var rides_taken := 0
var last_ride := -1
var thought := ""
var thought_time := 0.0
## An emote to show over the guest's head (see ParkView), "" for none.
var emote := ""
var seconds_in_park := 0.0
## How long this guest means to stay, in seconds.
var stay := 360.0
var facing := Vector2(0, -1)


func think(text: String, emote_name := "", now := 0.0) -> void:
	thought = text
	thought_time = now
	if emote_name != "":
		emote = emote_name


## The most pressing need: [name, value].
func top_need() -> Array:
	var best := ["", 0.0]
	for n in [["toilet", toilet], ["hunger", hunger], ["thirst", thirst]]:
		if n[1] > best[1]:
			best = n
	return best


func mood_word() -> String:
	if happiness > 0.8:
		return "Delighted"
	if happiness > 0.6:
		return "Happy"
	if happiness > 0.4:
		return "Fine"
	if happiness > 0.2:
		return "Unhappy"
	return "Miserable"


## Compact row for saves: guests come back where they were in spirit, if
## not in place.
func to_row() -> Array:
	return [money, snappedf(happiness, 0.01), snappedf(hunger, 0.01), snappedf(thirst, 0.01),
		snappedf(toilet, 0.01), snappedf(energy, 0.01), look, snappedf(thrill, 0.1), 1 if wheelchair else 0, name, spent]


static func from_row(row: Array) -> Guest:
	var g := Guest.new()
	if row.size() < 9:
		return g
	g.money = int(row[0])
	g.happiness = float(row[1])
	g.hunger = float(row[2])
	g.thirst = float(row[3])
	g.toilet = float(row[4])
	g.energy = float(row[5])
	g.look = int(row[6])
	g.thrill = float(row[7])
	g.wheelchair = int(row[8]) == 1
	if row.size() > 9:
		g.name = str(row[9])
	if row.size() > 10:
		g.spent = int(row[10])
	return g
