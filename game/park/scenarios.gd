class_name Scenarios
extends RefCounted
## Scenario parks: a map, starting money and a goal with a deadline. The
## first milestone has one; the campaign grows to ten.

const LIST := {
	"meadow_fair": {
		"name": "Meadow Fair",
		"map": "meadow",
		"money": 12000,
		"blurb": "A muddy meadow, a gate and a bench's worth of money. The valley wants a fair.",
		"guests": 100,
		"rating": 500,
		# End of October, year 1.
		"deadline_month": 8,
	},
}


static func get_def(id: String) -> Dictionary:
	return LIST.get(id, {})


static func goal_text(id: String) -> String:
	var s := get_def(id)
	if s.is_empty():
		return "No goal: build whatever you like."
	var year := int(s.deadline_month) / ParkData.MONTHS_OPEN
	return "Have %d guests in the park and a park rating of at least %d by the end of October, year %d." % [s.guests, s.rating, year]


static func start(id: String, seed := 0) -> ParkData:
	var s := get_def(id)
	var p := ParkData.create(str(s.name), str(s.map), false, seed)
	p.scenario = id
	p.money = int(s.money)
	return p
