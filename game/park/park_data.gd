class_name ParkData
extends RefCounted
## One park: its land, everything built on it, its rides, staff, money and
## calendar. This is what a save file holds (see ParkLibrary). The guest
## simulation (ParkSim) runs on top of it, and ParkView draws it.
##
## Tiles are Vector2i (x, z). Each built tile is a small dictionary:
##   {"k": kind, "id": piece id, "r": rotation 0..3, ...}
## with kinds path, queue, stall, scenery, entrance (the park gate),
## ride_in and ride_out (a ride's entrance and exit, with "ride": id).

const FORMAT := 1
const START_MONTH := 3  # March
const MONTHS_OPEN := 8  # March to October
const DAYS_PER_MONTH := 30
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July",
	"August", "September", "October", "November", "December"]
const MAPS := {
	"meadow": {"name": "Meadow", "size": Vector2i(36, 36), "trees": 0.09},
	"empty": {"name": "Empty lot", "size": Vector2i(36, 36), "trees": 0.0},
}
const SANDBOX_MONEY := 999999

var id := ""
var name := "New park"
var map := "meadow"
var size := Vector2i(36, 36)
var scenario := ""
var sandbox := false
var money := 10000
## Days since the park opened; the calendar comes from this.
var clock := 0.0
var entry_fee := 10
var tiles := {}
var litter := {}
var rides: Array = []
var staff: Array = []
## Guests in the park when it was saved, as compact rows (see ParkSim).
var guests: Array = []
## This month's and earlier months' takings: [{"month": n, "in": {...}, "out": {...}}].
var finances: Array = []
var total_guests := 0
var goal_state := ""  # "", "won" or "lost"
var play_seconds := 0.0
var created := 0
var updated := 0
var _next_id := 1


static func create(p_name: String, p_map: String, p_sandbox: bool, seed := 0) -> ParkData:
	var p := ParkData.new()
	p.id = new_id()
	p.name = p_name
	p.map = p_map if MAPS.has(p_map) else "meadow"
	p.size = MAPS[p.map].size
	p.sandbox = p_sandbox
	p.money = SANDBOX_MONEY if p_sandbox else 10000
	p.created = int(Time.get_unix_time_from_system())
	p.updated = p.created
	p._lay_out(seed)
	return p


static func new_id() -> String:
	return "%x%04x" % [int(Time.get_unix_time_from_system()), randi() % 0x10000]


## The gate in the middle of the bottom edge, a short path in, and trees.
func _lay_out(seed: int) -> void:
	tiles.clear()
	var gx := size.x / 2
	var gz := size.y - 1
	for dx in [-1, 0, 1]:
		tiles[Vector2i(gx + dx, gz)] = {"k": "entrance", "id": "entrance", "r": 2}
	for z in range(gz - 6, gz):
		tiles[Vector2i(gx, z)] = {"k": "path", "id": "path", "r": 0}
	var density: float = MAPS[map].trees
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else hash(id)
	for x in size.x:
		for z in size.y:
			var t := Vector2i(x, z)
			if tiles.has(t) or (absi(x - gx) <= 3 and z >= gz - 8):
				continue
			if rng.randf() < density:
				var kind := "tree" if rng.randf() < 0.7 else "tree_large"
				tiles[t] = {"k": "scenery", "id": kind, "r": rng.randi() % 4, "wild": true}


func gate_tile() -> Vector2i:
	return Vector2i(size.x / 2, size.y - 1)


## The footpath tile guests step onto from the gate.
func arrival_tile() -> Vector2i:
	return gate_tile() + Vector2i(0, -1)


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y


func kind_at(t: Vector2i) -> String:
	return str(tiles[t].k) if tiles.has(t) else ""


func is_path(t: Vector2i) -> bool:
	return kind_at(t) == "path"


func neighbours(t: Vector2i) -> Array:
	return [t + Vector2i(0, 1), t + Vector2i(1, 0), t + Vector2i(0, -1), t + Vector2i(-1, 0)]


func next_id() -> int:
	_next_id += 1
	return _next_id - 1


# --- Calendar -------------------------------------------------------------

func day() -> int:
	return int(clock)


func month_index() -> int:
	return int(clock) / DAYS_PER_MONTH


func year() -> int:
	return month_index() / MONTHS_OPEN + 1


func month_name() -> String:
	return MONTH_NAMES[START_MONTH - 1 + month_index() % MONTHS_OPEN]


func date_text() -> String:
	return "%s %d, year %d" % [month_name(), int(clock) % DAYS_PER_MONTH + 1, year()]


# --- Money ---------------------------------------------------------------

## Adds to (or, negative, takes from) the park's money, booked under `what`
## in this month's accounts.
func earn(amount: int, what: String) -> void:
	if not sandbox:
		money += amount
	var m := _month_book()
	var side := "in" if amount >= 0 else "out"
	m[side][what] = int(m[side].get(what, 0)) + absi(amount)


func can_afford(amount: int) -> bool:
	return sandbox or money >= amount


func _month_book() -> Dictionary:
	var mi := month_index()
	if finances.is_empty() or int(finances[finances.size() - 1].month) != mi:
		finances.append({"month": mi, "in": {}, "out": {}})
		while finances.size() > 16:
			finances.pop_front()
	return finances[finances.size() - 1]


func month_totals(back := 0) -> Dictionary:
	var i := finances.size() - 1 - back
	if i < 0:
		return {"in": 0, "out": 0}
	var m: Dictionary = finances[i]
	var a := 0
	var b := 0
	for k in m.in:
		a += int(m.in[k])
	for k in m.out:
		b += int(m.out[k])
	return {"in": a, "out": b}


# --- Building ------------------------------------------------------------

## Heights of coaster track over each tile, from every ride.
func track_tiles() -> Dictionary:
	var out := {}
	for ride in rides:
		var tt := Track.ride_tiles(ride)
		for t in tt:
			var v: Vector2 = tt[t]
			if out.has(t):
				var o: Vector2 = out[t]
				out[t] = Vector2(minf(o.x, v.x), maxf(o.y, v.y))
			else:
				out[t] = v
	return out


func station_at(t: Vector2i) -> Dictionary:
	for ride in rides:
		if t in Track.station_tiles(ride.station):
			return ride
	return {}


## Why `id` can't go on tile `t`, or "".
func build_error(id: String, t: Vector2i) -> String:
	if not in_bounds(t):
		return "That's outside the park"
	if not station_at(t).is_empty():
		return "A ride's station is in the way"
	var kind := Pieces.kind(id)
	var here := kind_at(t)
	# Building clears scenery for a small fee, and paths and queues swap.
	var swaps := (kind == "path" and here == "queue") or (kind == "queue" and here == "path")
	if here != "" and not swaps and not (here == "scenery" and kind != "scenery"):
		return "Something is already there"
	var tt := track_tiles()
	if tt.has(t) and (tt[t] as Vector2).x < Track.CLEARANCE:
		return "Coaster track is in the way"
	if kind == "stall" and _path_beside(t) == -1:
		return "Shops need a footpath next to them"
	var price := Pieces.cost(id)
	if here == "scenery" and kind != "scenery":
		price += Pieces.CLEAR_COST
	if not can_afford(price):
		return "Not enough money"
	return ""


## Builds `id` on `t` (call build_error first). Returns what it cost.
func build(id: String, t: Vector2i, rot := 0) -> int:
	var kind := Pieces.kind(id)
	var price := Pieces.cost(id)
	if kind_at(t) == "scenery" and kind != "scenery":
		price += Pieces.CLEAR_COST
	var tile := {"k": kind, "id": id, "r": rot}
	if kind == "stall":
		var side := _path_beside(t)
		tile.r = side if side >= 0 else rot
		tile.price = int(Pieces.STALLS[id].price)
		tile.sid = next_id()
	tiles[t] = tile
	litter.erase(t)
	earn(-price, "Building")
	return price


## Rotation (index into Track.DIRS) towards a footpath next to `t`, or -1.
func _path_beside(t: Vector2i) -> int:
	for r in 4:
		if is_path(t + Track.DIRS[r]):
			return r
	return -1


## Clears a tile: half the build price back for things players built.
## Coaster stations are cleared by demolishing their ride.
func bulldoze(t: Vector2i) -> int:
	if not tiles.has(t):
		return 0
	var tile: Dictionary = tiles[t]
	if tile.k in ["entrance", "ride_in", "ride_out"]:
		return 0
	var refund := 0
	if tile.get("wild", false):
		refund = -Pieces.CLEAR_COST
	else:
		refund = Pieces.cost(str(tile.id)) / 2
	tiles.erase(t)
	litter.erase(t)
	earn(refund, "Building")
	return refund


# --- Rides ---------------------------------------------------------------

func ride(rid: int) -> Dictionary:
	for r in rides:
		if int(r.id) == rid:
			return r
	return {}


## Tiles a station would cover and why it can't go there ("" if it can).
func station_error(tile: Vector2i, dir: int, length: int) -> String:
	var st := {"tile": tile, "dir": dir, "length": length, "height": 0.0}
	var tt := track_tiles()
	for t in Track.station_tiles(st):
		if not in_bounds(t):
			return "That's outside the park"
		if tiles.has(t) and kind_at(t) != "scenery":
			return "Something is in the way"
		if tt.has(t):
			return "Coaster track is in the way"
	var cost := Pieces.cost("coaster_wood") + Pieces.STATION_COST * length
	if not can_afford(cost):
		return "Not enough money"
	return ""


func add_coaster(tile: Vector2i, dir: int, length: int) -> Dictionary:
	var st := {"tile": tile, "dir": dir, "length": length, "height": 0.0}
	var clear := 0
	for t in Track.station_tiles(st):
		if kind_at(t) == "scenery":
			tiles.erase(t)
			clear += Pieces.CLEAR_COST
	var n := 1
	for r in rides:
		n += 1
	var r := {
		"id": next_id(),
		"name": "Wooden Coaster %d" % n,
		"type": "coaster_wood",
		"station": st,
		"pieces": [],
		"open": false,
		"price": 3,
		"cars": 4,
		"stats": {},
		"riders": 0,
		"income": 0,
	}
	rides.append(r)
	earn(-(Pieces.cost("coaster_wood") + Pieces.STATION_COST * length + clear), "Building")
	return r


## What a piece costs.
static func piece_cost(piece: Array) -> int:
	var c := Pieces.TRACK_COST
	if absi(int(piece[0])) > 0:
		c += Pieces.TRACK_COST * absi(int(piece[0]))
	if piece.size() > 2 and int(piece[2]) != 0:
		c += Pieces.LIFT_COST
	return c


## Why `piece` can't be added to the end of the ride's track, or "".
func piece_error(r: Dictionary, piece: Array) -> String:
	if r.pieces.size() >= Track.MAX_PIECES:
		return "That's as long as a coaster can be"
	var path := Track.build(r)
	if path.complete:
		return "The track is finished"
	var pose: Dictionary = path.end
	var why := Track.piece_error(pose, piece)
	if why != "":
		return why
	var pts: PackedVector3Array = Track.piece_points(pose, piece).points
	var mine := Track.tiles_of(path.points)
	var others := {}
	for o in rides:
		if int(o.id) != int(r.id):
			var ot := Track.ride_tiles(o)
			for t in ot:
				others[t] = ot[t]
	var start := Track.station_start(r.station)
	var closes := Track.same_pose(Track.piece_points(pose, piece).pose, start)
	# The newest points can touch the tile the last piece ended on.
	var recent := {}
	if path.ends.size() > 0:
		var last_end: Vector3 = (path.ends[path.ends.size() - 1] as Dictionary).pos
		for t in [Vector2i(floori(last_end.x - 0.01), floori(last_end.z - 0.01)), Vector2i(floori(last_end.x + 0.01), floori(last_end.z + 0.01)),
				Vector2i(floori(last_end.x - 0.01), floori(last_end.z + 0.01)), Vector2i(floori(last_end.x + 0.01), floori(last_end.z - 0.01))]:
			recent[t] = true
	var st_tiles := Track.station_tiles(r.station)
	var piece_tiles := Track.tiles_of(PackedVector3Array([pose.pos]) + pts)
	for t in piece_tiles:
		var h: Vector2 = piece_tiles[t]
		if not in_bounds(t):
			return "The track would leave the park"
		if h.x < -0.01:
			return "The track can't go underground"
		if h.y > Track.MAX_HEIGHT:
			return "That's too high"
		if tiles.has(t) and kind_at(t) != "scenery" and h.x < Track.CLEARANCE:
			return "Something is in the way"
		if others.has(t) and _overlaps(h, others[t]):
			return "Another ride's track is in the way"
		if mine.has(t) and not recent.has(t) and _overlaps(h, mine[t]):
			if not (closes and t in st_tiles):
				return "The track would run into itself"
	if not can_afford(piece_cost(piece)):
		return "Not enough money"
	return ""


static func _overlaps(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y + Track.TRACK_GAP and b.x < a.y + Track.TRACK_GAP


func add_piece(r: Dictionary, piece: Array) -> void:
	r.pieces.append(piece)
	# Track built over trees clears them.
	var tt := Track.ride_tiles(r)
	for t in tt:
		if kind_at(t) == "scenery" and (tt[t] as Vector2).x < Track.CLEARANCE:
			tiles.erase(t)
	r.stats = {}
	earn(-piece_cost(piece), "Building")


func remove_last_piece(r: Dictionary) -> void:
	if r.pieces.is_empty():
		return
	var piece: Array = r.pieces.pop_back()
	r.stats = {}
	r.open = false
	earn(piece_cost(piece) / 2, "Building")


## Why a ready-made design (see CoasterDesigns) can't go with its station
## on `tile` heading `dir`, or "". Checks every piece without building.
func design_error(design_id: String, tile: Vector2i, dir: int) -> String:
	var d := CoasterDesigns.get_design(design_id)
	if d.is_empty():
		return "There's no such design"
	var why := station_error(tile, dir, int(d.station))
	if why != "":
		return why
	var trial := {"id": -1, "station": {"tile": tile, "dir": dir, "length": int(d.station), "height": 0.0}, "pieces": []}
	var cost := design_cost(design_id)
	for piece in d.pieces:
		why = piece_error(trial, piece)
		if why != "" and why != "Not enough money":
			return why
		trial.pieces.append(piece)
	if not can_afford(cost):
		return "Not enough money"
	return ""


static func design_cost(design_id: String) -> int:
	var d := CoasterDesigns.get_design(design_id)
	var cost := Pieces.cost("coaster_wood") + Pieces.STATION_COST * int(d.station)
	for piece in d.pieces:
		cost += piece_cost(piece)
	return cost


## Builds a ready-made design (call design_error first).
func add_design(design_id: String, tile: Vector2i, dir: int) -> Dictionary:
	var d := CoasterDesigns.get_design(design_id)
	var r := add_coaster(tile, dir, int(d.station))
	for piece in d.pieces:
		add_piece(r, piece)
	r.name = _unused_ride_name(str(d.name))
	return r


func _unused_ride_name(base: String) -> String:
	var used := {}
	for r in rides:
		used[str(r.name)] = true
	if not used.has(base):
		return base
	var n := 2
	while used.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


## Places for the ride's entrance and exit: tiles beside the station.
func ride_door_tiles(r: Dictionary) -> Array:
	var out := []
	var side := Track.left(r.station.dir)
	for t in Track.station_tiles(r.station):
		for s in [-1, 1]:
			var n: Vector2i = t + Vector2i(int(side.x) * s, int(side.z) * s)
			if in_bounds(n) and not out.has(n):
				out.append(n)
	return out


func door_error(r: Dictionary, t: Vector2i) -> String:
	if not t in ride_door_tiles(r):
		return "Put it right beside the station"
	if tiles.has(t) and kind_at(t) != "scenery":
		return "Something is already there"
	var tt := track_tiles()
	if tt.has(t) and (tt[t] as Vector2).x < Track.CLEARANCE:
		return "Coaster track is in the way"
	return ""


## Sets the ride's entrance ("ride_in") or exit ("ride_out"), moving it if
## it was somewhere else. Doors face away from the station.
func set_door(r: Dictionary, kind: String, t: Vector2i) -> void:
	for tt in tiles.keys():
		if tiles[tt].k == kind and int(tiles[tt].get("ride", -1)) == int(r.id):
			tiles.erase(tt)
	var st_tiles := Track.station_tiles(r.station)
	var face := 0
	for d in 4:
		if (t - Track.DIRS[d]) in st_tiles:
			face = d
	tiles[t] = {"k": kind, "id": kind, "r": face, "ride": int(r.id)}
	if kind == "ride_in":
		r.entrance = t
	else:
		r.exit = t
	earn(-Pieces.RIDE_ENTRANCE_COST, "Building")


## Whether the ride can open, or why not.
func ride_open_error(r: Dictionary) -> String:
	var path := Track.build(r)
	if not path.complete:
		return "Finish the track back to the station first"
	if not r.has("entrance") or kind_at(r.entrance) != "ride_in":
		return "Add an entrance beside the station"
	if not r.has("exit") or kind_at(r.exit) != "ride_out":
		return "Add an exit beside the station"
	if r.stats.is_empty():
		r.stats = RidePhysics.simulate(path)
	if not r.stats.get("ok", false):
		return str(r.stats.get("error", "The test run failed"))
	if r.stats.get("too_intense", false):
		return "The forces on this ride are too strong for anyone. Make the drops gentler"
	return ""


func demolish_ride(r: Dictionary) -> int:
	var refund := Pieces.cost("coaster_wood") / 2 + Pieces.STATION_COST * int(r.station.length) / 2
	for p in r.pieces:
		refund += piece_cost(p) / 2
	for t in tiles.keys():
		if int(tiles[t].get("ride", -1)) == int(r.id):
			tiles.erase(t)
	rides.erase(r)
	earn(refund, "Building")
	return refund


# --- Saving --------------------------------------------------------------

static func _key(t: Vector2i) -> String:
	return "%d,%d" % [t.x, t.y]


static func _tile(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i.ZERO


func to_dict() -> Dictionary:
	var t := {}
	for k in tiles:
		t[_key(k)] = tiles[k]
	var l := {}
	for k in litter:
		l[_key(k)] = litter[k]
	var rs := []
	for r in rides:
		var c: Dictionary = r.duplicate(true)
		c.station = {"tile": _key(r.station.tile), "dir": r.station.dir, "length": r.station.length, "height": r.station.height}
		if r.has("entrance"):
			c.entrance = _key(r.entrance)
		if r.has("exit"):
			c.exit = _key(r.exit)
		# Ratings are cheap to work out again, and the speeds are long.
		c.stats = {}
		rs.append(c)
	var sf := []
	for s in staff:
		var c: Dictionary = s.duplicate()
		c.tile = _key(s.tile)
		sf.append(c)
	return {
		"format": FORMAT,
		"game": GameConfig.GAME_ID,
		"id": id, "name": name, "map": map, "size": [size.x, size.y],
		"scenario": scenario, "sandbox": sandbox, "money": money, "clock": clock,
		"entry_fee": entry_fee, "tiles": t, "litter": l, "rides": rs, "staff": sf,
		"guests": guests, "finances": finances, "total_guests": total_guests,
		"goal_state": goal_state, "play_seconds": play_seconds,
		"created": created, "updated": updated, "next_id": _next_id,
	}


## A park from a save, or null when the data isn't a park this build can open.
static func from_dict(d: Dictionary) -> ParkData:
	if int(d.get("format", 0)) < 1 or int(d.get("format", 0)) > FORMAT:
		return null
	var p := ParkData.new()
	p.id = str(d.get("id", new_id()))
	p.name = str(d.get("name", "Park"))
	p.map = str(d.get("map", "meadow"))
	var sz: Array = d.get("size", [36, 36])
	p.size = Vector2i(int(sz[0]), int(sz[1]))
	p.scenario = str(d.get("scenario", ""))
	p.sandbox = bool(d.get("sandbox", false))
	p.money = int(d.get("money", 0))
	p.clock = float(d.get("clock", 0.0))
	p.entry_fee = int(d.get("entry_fee", 10))
	var t: Dictionary = d.get("tiles", {})
	for k in t:
		var tile: Dictionary = t[k]
		tile.r = int(tile.get("r", 0))
		if tile.has("ride"):
			tile.ride = int(tile.ride)
		if tile.has("price"):
			tile.price = int(tile.price)
		if tile.has("sid"):
			tile.sid = int(tile.sid)
		p.tiles[_tile(k)] = tile
	var l: Dictionary = d.get("litter", {})
	for k in l:
		p.litter[_tile(k)] = int(l[k])
	for r in d.get("rides", []):
		var c: Dictionary = r
		c.id = int(c.id)
		c.station = {"tile": _tile(str(c.station.tile)), "dir": int(c.station.dir), "length": int(c.station.length), "height": float(c.station.height)}
		var pieces := []
		for piece in c.get("pieces", []):
			pieces.append([int(piece[0]), int(piece[1]), int(piece[2]) if piece.size() > 2 else 0])
		c.pieces = pieces
		if c.has("entrance"):
			c.entrance = _tile(str(c.entrance))
		if c.has("exit"):
			c.exit = _tile(str(c.exit))
		c.price = int(c.get("price", 3))
		c.cars = int(c.get("cars", 4))
		c.riders = int(c.get("riders", 0))
		c.income = int(c.get("income", 0))
		c.stats = {}
		p.rides.append(c)
	for s in d.get("staff", []):
		var c: Dictionary = s
		c.tile = _tile(str(c.tile))
		c.id = int(c.get("id", 0))
		p.staff.append(c)
	for row in d.get("guests", []):
		if row is Array:
			p.guests.append(Guest.from_row(row).to_row())
	for m in d.get("finances", []):
		var book := {"month": int(m.get("month", 0)), "in": {}, "out": {}}
		for side in ["in", "out"]:
			for k in m.get(side, {}):
				book[side][k] = int(m[side][k])
		p.finances.append(book)
	p.total_guests = int(d.get("total_guests", 0))
	p.goal_state = str(d.get("goal_state", ""))
	p.play_seconds = float(d.get("play_seconds", 0.0))
	p.created = int(d.get("created", 0))
	p.updated = int(d.get("updated", 0))
	p._next_id = int(d.get("next_id", 1))
	return p
