class_name ParkSim
extends RefCounted
## Runs a park: guests arrive, walk the footpaths, queue, ride, eat, drink,
## litter and leave; janitors sweep; trains go round; money comes and goes;
## the calendar turns and the scenario goal is checked. It has no nodes, so
## tests can run a whole season headless; ParkView draws what it holds.
##
## Call step(seconds) with game time (already multiplied by the game speed).
## Call refresh() whenever something is built or removed.

signal message(text: String)
signal goal_changed(state: String)

const STEP := 0.1
## Real seconds per park day at normal speed.
const DAY_SECONDS := 4.0
const WALK_SPEED := 1.0
const QUEUE_GAP := 0.32
const LOAD_TIME := 6.0
const SHOP_TIME := 1.5
const MAX_LITTER := 5
const MAX_GUESTS := 600
const FIRST_NAMES := ["Ada", "Ben", "Cleo", "Dev", "Ella", "Finn", "Gus", "Hana", "Ivo", "Jun", "Kit", "Lena",
	"Milo", "Nia", "Omar", "Pia", "Quin", "Rosa", "Sami", "Tess", "Uma", "Vic", "Wren", "Yara", "Zed"]
## What guests expect to pay, before they grumble.
const FAIR_PRICE := {"food": 5, "drinks": 4, "toilets": 2, "info": 3}

var park: ParkData
var rng := RandomNumberGenerator.new()
var guests: Array = []
var janitors: Array = []
## Ride id -> run state (see _make_run).
var runs := {}
var rating := 600
var now := 0.0
var recent_messages: Array = []
var _walk := {}
var _acc := 0.0
var _arrivals := 0.0
var _rating_timer := 0.0
var _next_guest := 1
var _last_month := -1


func _init(p: ParkData, seed := 0) -> void:
	park = p
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	_last_month = park.month_index()
	refresh()
	_restore_guests()
	for s in park.staff:
		_add_janitor_runtime(s)


# --- World ---------------------------------------------------------------

## Rebuilds what the simulation knows about the map. Call after building.
func refresh() -> void:
	_walk.clear()
	for t in park.tiles:
		if park.tiles[t].k == "path":
			_walk[t] = true
	var old := runs
	runs = {}
	for r in park.rides:
		var run := _make_run(r)
		if old.has(int(r.id)):
			var o: Dictionary = old[int(r.id)]
			# A ride that stays open keeps its train and queue; one that
			# closes or changes shape sends everyone off.
			if o.path_key == run.path_key and o.state != "closed" and run.state != "closed":
				for k in ["state", "s", "travelled", "timer", "riders", "queue"]:
					run[k] = o[k]
			else:
				_drop_riders(o)
		runs[int(r.id)] = run
	for id in old:
		if not runs.has(id):
			_drop_riders(old[id])
	# Guests whose way was built over look for a new one.
	for g in guests:
		if g.state == Guest.State.WALK and not g.route.is_empty():
			for t in g.route:
				if not _walk.has(t) and not _is_gate(t):
					g.route = []
					g.goal = {}
					break


func is_walkable(t: Vector2i) -> bool:
	return _walk.has(t)


func _is_gate(t: Vector2i) -> bool:
	return park.kind_at(t) == "entrance"


func _make_run(r: Dictionary) -> Dictionary:
	var path := Track.build(r)
	var run := {
		"ride": r,
		"path": path,
		"path_key": str(r.station) + str(r.pieces),
		"state": "closed",
		"s": float(r.station.length) - 0.05,
		"travelled": 0.0,
		"timer": 0.0,
		"riders": [],
		"queue": [],
		"queue_line": [],
		"join": null,
		"exit_path": null,
		"capacity": int(r.cars) * 2,
	}
	if path.complete:
		if r.stats.is_empty():
			r.stats = RidePhysics.simulate(path)
	if not r.open:
		return run
	run.state = "loading"
	# The queue: from the entrance back along queue tiles to a footpath.
	if r.has("entrance"):
		var line := _queue_line(r.entrance)
		run.queue_line = line.line
		run.join = line.join
	if r.has("exit"):
		for n in park.neighbours(r.exit):
			if park.is_path(n):
				run.exit_path = n
				break
	return run


## Tiles from a ride's entrance back through its queue, and the footpath
## tile where the line starts.
func _queue_line(entrance: Vector2i) -> Dictionary:
	var line := [entrance]
	var seen := {entrance: true}
	var at := entrance
	var join = null
	for i in 200:
		var next = null
		for n in park.neighbours(at):
			if not seen.has(n) and park.kind_at(n) == "queue":
				next = n
				break
		if next == null:
			break
		seen[next] = true
		line.append(next)
		at = next
	for n in park.neighbours(at):
		if park.is_path(n):
			join = n
			break
	if join == null and at != entrance:
		# A line that loops back past its start still needs a footpath.
		for t in line:
			for n in park.neighbours(t):
				if park.is_path(n):
					join = n
					break
			if join != null:
				break
	return {"line": line, "join": join}


func _drop_riders(run: Dictionary) -> void:
	for g in run.riders + run.queue:
		if g in guests:
			g.state = Guest.State.WALK
			g.route = []
			g.goal = {}
			g.ride_id = -1
			var free: Variant = _nearest_walkable(g.tile)
			if free != null:
				g.tile = free
				g.pos = _center(free)


func _nearest_walkable(from: Vector2i):
	if _walk.has(from):
		return from
	var best = null
	var bd := 1 << 30
	for t in _walk:
		var d := absi(t.x - from.x) + absi(t.y - from.y)
		if d < bd:
			bd = d
			best = t
	return best


static func _center(t: Vector2i) -> Vector2:
	return Vector2(t.x + 0.5, t.y + 0.5)


# --- Running -------------------------------------------------------------

func step(seconds: float) -> void:
	_acc += seconds
	while _acc >= STEP:
		_acc -= STEP
		_tick(STEP)


func _tick(dt: float) -> void:
	now += dt
	park.clock += dt / DAY_SECONDS
	_arrive(dt)
	for g in guests.duplicate():
		_update_guest(g, dt)
	for j in janitors:
		_update_janitor(j, dt)
	for id in runs:
		_update_run(runs[id], dt)
	_rating_timer -= dt
	if _rating_timer <= 0.0:
		_rating_timer = 2.0
		_update_rating()
	if park.month_index() != _last_month:
		_last_month = park.month_index()
		_new_month()


func _new_month() -> void:
	var wages := park.staff.size() * Pieces.JANITOR_WAGE
	if wages > 0:
		park.earn(-wages, "Wages")
	_check_goal(true)
	if park.month_index() % ParkData.MONTHS_OPEN == 0:
		_say("A new year begins at %s." % park.name)


# --- Guests --------------------------------------------------------------

## How many guests the park would draw right now.
func attraction() -> float:
	var a := 15.0
	var thrills := 0.0
	for id in runs:
		var run: Dictionary = runs[id]
		if run.state != "closed" and run.ride.stats.get("ok", false):
			a += 15.0 + float(run.ride.stats.excitement) * 10.0
			thrills += float(run.ride.stats.excitement)
	for t in park.tiles:
		var k: String = park.tiles[t].k
		if k == "stall":
			a += 4.0
		elif k == "scenery" and not park.tiles[t].get("wild", false):
			a += 0.3
	var fair := 6.0 + thrills * 3.0
	var fee_factor := clampf(1.6 - float(park.entry_fee) / maxf(1.0, fair), 0.15, 1.3)
	return a * (0.5 + rating / 1000.0) * fee_factor


func _arrive(dt: float) -> void:
	if not park.is_path(park.arrival_tile()) or guests.size() >= MAX_GUESTS:
		return
	var target := attraction()
	var room := clampf((target - guests.size()) / maxf(target, 1.0), 0.0, 1.0)
	_arrivals += dt * (0.02 + 0.5 * room)
	while _arrivals >= 1.0:
		_arrivals -= 1.0
		spawn_guest()


func spawn_guest(row: Array = []) -> Guest:
	var g: Guest = Guest.from_row(row) if not row.is_empty() else Guest.new()
	g.id = _next_guest
	_next_guest += 1
	if row.is_empty():
		g.look = rng.randi() % Guest.LOOKS
		g.wheelchair = rng.randf() < 0.07
		g.money = rng.randi_range(40, 120)
		g.stay = rng.randf_range(240.0, 480.0)
		g.thrill = rng.randf_range(2.5, 9.0)
		g.happiness = rng.randf_range(0.6, 0.8)
		g.hunger = rng.randf_range(0.0, 0.4)
		g.thirst = rng.randf_range(0.0, 0.4)
		g.toilet = rng.randf_range(0.0, 0.3)
		g.name = "%s %s." % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()], char(65 + rng.randi() % 26)]
		var fee := park.entry_fee
		if g.money < fee:
			return null
		g.money -= fee
		g.spent += fee
		park.earn(fee, "Park entry")
		park.total_guests += 1
		if park.total_guests == 1:
			_say("Your first guest has arrived!")
		var gate := park.gate_tile()
		g.tile = gate
		g.pos = _center(gate) + Vector2(rng.randf_range(-0.8, 0.8), 0.45)
		g.route = [park.arrival_tile()]
	g.lane = rng.randf_range(-0.28, 0.28)
	g.goal = {"kind": "wander"}
	guests.append(g)
	return g


func _restore_guests() -> void:
	var tiles := _walk.keys()
	if tiles.is_empty():
		return
	for row in park.guests:
		var g := spawn_guest(row)
		if g == null:
			continue
		var t: Vector2i = tiles[rng.randi() % tiles.size()]
		g.tile = t
		g.pos = _center(t)
		g.route = []
	park.guests = []


func remove_guest(g: Guest) -> void:
	guests.erase(g)
	for id in runs:
		runs[id].queue.erase(g)
		runs[id].riders.erase(g)


func _update_guest(g: Guest, dt: float) -> void:
	g.seconds_in_park += dt
	if g.state != Guest.State.RIDE:
		g.hunger = minf(1.0, g.hunger + dt * 0.0045)
		g.thirst = minf(1.0, g.thirst + dt * 0.006)
		g.toilet = minf(1.0, g.toilet + dt * 0.0035)
		g.energy = maxf(0.0, g.energy - dt * (0.0012 if g.state != Guest.State.SIT else -0.02))
	g.nausea = maxf(0.0, g.nausea - dt * 0.01)
	if g.holding != "":
		g.hold_timer -= dt
		if g.hold_timer <= 0.0:
			_finish_item(g)
	if now - g.thought_time > 3.0:
		g.emote = ""
	_drift_happiness(g, dt)
	match g.state:
		Guest.State.WALK, Guest.State.LEAVE:
			_walk_guest(g, dt)
		Guest.State.QUEUE:
			_queue_guest(g, dt)
		Guest.State.SHOP:
			g.timer -= dt
			if g.timer <= 0.0:
				_buy(g)
		Guest.State.SIT:
			g.timer -= dt
			if g.timer <= 0.0:
				g.state = Guest.State.WALK
				g.goal = {}
		Guest.State.RIDE:
			pass


func _drift_happiness(g: Guest, dt: float) -> void:
	var target := 0.78
	var need: float = g.top_need()[1]
	if need > 0.6:
		target -= (need - 0.6) * 1.2
	target -= g.nausea * 0.4
	target -= minf(0.3, float(park.litter.get(g.tile, 0)) * 0.06)
	if g.energy < 0.25:
		target -= 0.15
	if g.state == Guest.State.QUEUE:
		target -= minf(0.25, g.timer / 240.0)
	target += _scenery_near(g.tile) * 0.03
	g.happiness = clampf(move_toward(g.happiness, target, dt * 0.004), 0.0, 1.0)


## Scenery appeal around a tile.
func _scenery_near(t: Vector2i) -> float:
	var a := 0.0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var n := t + Vector2i(dx, dz)
			if park.kind_at(n) == "scenery":
				a += float(Pieces.SCENERY_APPEAL.get(str(park.tiles[n].id), 0.5))
	return minf(a, 4.0)


func _walk_guest(g: Guest, dt: float) -> void:
	if g.route.is_empty():
		_arrived(g)
		return
	var next: Vector2i = g.route[0]
	if not _walk.has(next) and not _is_gate(next) and park.kind_at(next) not in ["ride_out", "queue", "ride_in"]:
		g.route = []
		g.goal = {}
		return
	# Keep to this guest's lane: offset sideways from the way between tiles.
	var dest := _center(next)
	var way := Vector2(next - g.tile)
	if way != Vector2.ZERO:
		dest += Vector2(-way.y, way.x).normalized() * g.lane
	var dir := dest - g.pos
	var speed := WALK_SPEED * (0.85 if g.wheelchair else 1.0) * (0.75 if g.energy < 0.25 else 1.0)
	var d := speed * dt
	if dir.length() <= d:
		g.pos = dest
		g.tile = next
		g.route.pop_front()
	else:
		g.facing = dir.normalized()
		g.pos += g.facing * d


func _arrived(g: Guest) -> void:
	var kind := str(g.goal.get("kind", ""))
	if g.state == Guest.State.LEAVE:
		if _is_gate(g.tile):
			remove_guest(g)
			return
		_head_out(g)
		return
	match kind:
		"ride":
			_join_queue(g, int(g.goal.ride))
			return
		"stall":
			if g.tile == g.goal.service and park.tiles.has(g.goal.stall):
				g.state = Guest.State.SHOP
				g.timer = SHOP_TIME
				g.facing = (_center(g.goal.stall) - g.pos).normalized()
				return
		"bench":
			if park.kind_at(g.goal.bench) == "scenery":
				g.state = Guest.State.SIT
				g.timer = rng.randf_range(8.0, 16.0)
				return
	_decide(g)


## Picks what to do next.
func _decide(g: Guest) -> void:
	g.goal = {}
	if g.energy < 0.12 or g.happiness < 0.18 or g.seconds_in_park > g.stay or g.money < 3:
		if g.happiness < 0.18:
			g.think("I want to go home.", "faceSad", now)
		elif g.energy < 0.12:
			g.think("I'm worn out. Time to go home.", "sleeps", now)
		elif g.money < 3:
			g.think("I've spent all my money.", "cash", now)
		_head_out(g)
		return
	var need: Array = g.top_need()
	if need[1] > 0.55:
		var stall_id: String = {"toilet": "toilets", "hunger": "food", "thirst": "drinks"}[need[0]]
		if _go_to_stall(g, stall_id):
			return
		if rng.randf() < 0.3:
			var text: String = {"toilet": "I need a toilet!", "hunger": "I'm hungry. Where's the food?", "thirst": "I'm thirsty."}[need[0]]
			var emote: String = {"toilet": "exclamation", "hunger": "cloud", "thirst": "drop"}[need[0]]
			g.think(text, emote, now)
	if g.energy < 0.35 and _go_to_bench(g):
		return
	if g.nausea < 0.5 and _go_to_ride(g):
		return
	_wander(g)


func _head_out(g: Guest) -> void:
	g.state = Guest.State.LEAVE
	g.goal = {"kind": "exit"}
	if g.tile == park.arrival_tile():
		g.route = [park.gate_tile()]
		return
	var r = _route(g.tile, {park.arrival_tile(): true})
	if r == null:
		# Lost: walk anywhere and try again later.
		_wander(g)
		g.state = Guest.State.LEAVE
		return
	g.route = r + [park.gate_tile()]


func _go_to_stall(g: Guest, stall_id: String) -> bool:
	var targets := {}
	for t in park.tiles:
		var tile: Dictionary = park.tiles[t]
		if tile.k == "stall" and tile.id == stall_id:
			var service: Vector2i = t + Track.DIRS[int(tile.r)]
			if _walk.has(service):
				targets[service] = t
	if targets.is_empty():
		return false
	var r = _route(g.tile, targets, 60)
	if r == null:
		return false
	var service: Vector2i = r[r.size() - 1] if not r.is_empty() else g.tile
	g.goal = {"kind": "stall", "stall": targets[service], "service": service}
	g.route = r
	return true


func _go_to_bench(g: Guest) -> bool:
	var targets := {}
	for t in park.tiles:
		if park.tiles[t].k == "scenery" and park.tiles[t].id == "bench":
			for n in park.neighbours(t):
				if _walk.has(n):
					targets[n] = t
	if targets.is_empty():
		return false
	var r = _route(g.tile, targets, 30)
	if r == null:
		return false
	var at: Vector2i = r[r.size() - 1] if not r.is_empty() else g.tile
	g.goal = {"kind": "bench", "bench": targets[at]}
	g.route = r
	return true


func _go_to_ride(g: Guest) -> bool:
	var choices := []
	var weights := []
	for id in runs:
		var run: Dictionary = runs[id]
		if run.state == "closed" or run.join == null or not run.ride.stats.get("ok", false):
			continue
		if int(id) == g.last_ride and rng.randf() < 0.7:
			continue
		var st: Dictionary = run.ride.stats
		if float(st.intensity) > g.thrill + 1.5:
			continue
		choices.append(id)
		weights.append(1.0 + float(st.excitement))
	if choices.is_empty():
		return false
	var total := 0.0
	for w in weights:
		total += w
	var pick := rng.randf() * total
	var chosen = choices[0]
	for i in choices.size():
		pick -= weights[i]
		if pick <= 0.0:
			chosen = choices[i]
			break
	var run: Dictionary = runs[chosen]
	var r = _route(g.tile, {run.join: true}, 80)
	if r == null:
		return false
	g.goal = {"kind": "ride", "ride": int(chosen)}
	g.route = r
	return true


func _wander(g: Guest) -> void:
	g.goal = {"kind": "wander"}
	var at := g.tile
	var out := []
	var prev := Vector2i(-999, -999)
	for i in rng.randi_range(2, 6):
		var options := []
		for n in park.neighbours(at):
			if _walk.has(n) and n != prev:
				options.append(n)
		if options.is_empty():
			for n in park.neighbours(at):
				if _walk.has(n):
					options.append(n)
		if options.is_empty():
			break
		prev = at
		at = options[rng.randi() % options.size()]
		out.append(at)
	if out.is_empty() and not _walk.has(g.tile):
		var back = _nearest_walkable(g.tile)
		if back != null:
			out.append(back)
	g.route = out
	if out.is_empty():
		# Nowhere to go: stand a moment.
		g.state = Guest.State.SIT
		g.timer = 2.0


## Breadth-first route over footpaths from `from` to the nearest of
## `targets` (a dictionary of tiles). The route leaves out `from`; null if
## there's no way there within `limit` steps.
func _route(from: Vector2i, targets: Dictionary, limit := 400):
	if targets.has(from):
		return []
	var came := {from: from}
	var frontier := [from]
	var depth := 0
	while not frontier.is_empty() and depth < limit:
		depth += 1
		var next_frontier := []
		for t in frontier:
			for n in park.neighbours(t):
				if came.has(n) or not _walk.has(n):
					continue
				came[n] = t
				if targets.has(n):
					var out := [n]
					var c: Vector2i = t
					while c != from:
						out.push_front(c)
						c = came[c]
					return out
				next_frontier.append(n)
		frontier = next_frontier
	return null


func _buy(g: Guest) -> void:
	g.state = Guest.State.WALK
	var t: Vector2i = g.goal.get("stall", Vector2i(-1, -1))
	g.goal = {}
	if not park.tiles.has(t) or park.tiles[t].k != "stall":
		return
	var tile: Dictionary = park.tiles[t]
	var sid: String = tile.id
	var price := int(tile.get("price", 0))
	var info: Dictionary = Pieces.STALLS[sid]
	if price > g.money:
		g.think("I can't afford a %s." % str(info.item).to_lower(), "cash", now)
		return
	if price > int(FAIR_PRICE[sid]) * 2:
		g.think("%s for a %s? No thanks." % [_money(price), str(info.item).to_lower()], "cash", now)
		return
	g.money -= price
	g.spent += price
	park.earn(price, "Shops")
	park.earn(-int(info.cost), "Shop stock")
	tile.income = int(tile.get("income", 0)) + price
	match sid:
		"food":
			g.hunger = 0.0
			g.holding = "food"
			g.hold_timer = 8.0
			g.think("Yum!", "heart", now)
		"drinks":
			g.thirst = 0.0
			g.toilet = minf(1.0, g.toilet + 0.15)
			g.holding = "drink"
			g.hold_timer = 6.0
			g.think("Lovely lemonade.", "heart", now)
		"toilets":
			g.toilet = 0.0
			g.think("What a relief.", "faceHappy", now)
		"info":
			g.think("Now I know where everything is.", "idea", now)
	if price > int(FAIR_PRICE[sid]):
		g.happiness = maxf(0.0, g.happiness - 0.05)


func _finish_item(g: Guest) -> void:
	g.holding = ""
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var n := g.tile + Vector2i(dx, dz)
			if park.kind_at(n) == "scenery" and park.tiles[n].id == "bin":
				return
	if _walk.has(g.tile):
		park.litter[g.tile] = mini(MAX_LITTER, int(park.litter.get(g.tile, 0)) + 1)


static func _money(n: int) -> String:
	return "$%d" % n


# --- Rides ---------------------------------------------------------------

func _join_queue(g: Guest, id: int) -> void:
	if not runs.has(id):
		_decide(g)
		return
	var run: Dictionary = runs[id]
	var r: Dictionary = run.ride
	if run.state == "closed" or run.join == null or g.tile != run.join:
		_decide(g)
		return
	if run.queue.size() >= maxi(6, run.queue_line.size() * 3):
		g.think("The queue for %s is too long." % r.name, "dots3", now)
		g.last_ride = id
		_wander(g)
		return
	var value := 1.0 + float(r.stats.get("excitement", 0.0)) * 0.9
	var price := int(r.price)
	if price > value * 1.6 + 1.0:
		g.think("%s for %s? Too expensive." % [_money(price), r.name], "cash", now)
		g.last_ride = id
		_wander(g)
		return
	if price > g.money:
		g.think("I can't afford %s." % r.name, "cash", now)
		g.last_ride = id
		_wander(g)
		return
	g.money -= price
	g.spent += price
	park.earn(price, "Rides")
	r.income = int(r.get("income", 0)) + price
	g.state = Guest.State.QUEUE
	g.ride_id = id
	g.timer = 0.0
	run.queue.append(g)


## Where in the queue line a guest at `index` stands.
func queue_spot(run: Dictionary, index: int) -> Vector2:
	var line: Array = run.queue_line
	var pts := []
	for t in line:
		pts.append(_center(t))
	if run.join != null:
		pts.append(_center(run.join))
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector2.ZERO
	var d := index * QUEUE_GAP + 0.3
	for i in range(1, pts.size()):
		var seg: float = (pts[i] - pts[i - 1]).length()
		if d <= seg:
			return pts[i - 1].lerp(pts[i], d / seg)
		d -= seg
	return pts[pts.size() - 1]


func _queue_guest(g: Guest, dt: float) -> void:
	g.timer += dt
	var run: Dictionary = runs.get(g.ride_id, {})
	if run.is_empty():
		g.state = Guest.State.WALK
		return
	var i: int = run.queue.find(g)
	var spot := queue_spot(run, i)
	var dir := spot - g.pos
	var d := WALK_SPEED * 0.8 * dt
	if dir.length() > d:
		g.facing = dir.normalized()
		g.pos += g.facing * d
	else:
		g.pos = spot
	g.tile = Vector2i(floori(g.pos.x), floori(g.pos.y))
	if g.timer > 150.0 and rng.randf() < dt * 0.05:
		g.think("I've been queuing for ages.", "anger", now)
		run.queue.erase(g)
		g.state = Guest.State.WALK
		g.ride_id = -1
		g.last_ride = int(run.ride.id)
		var back = _nearest_walkable(g.tile)
		if back != null:
			g.route = [back]


func _update_run(run: Dictionary, dt: float) -> void:
	if run.state == "closed" or not run.ride.stats.get("ok", false):
		return
	var path: Dictionary = run.path
	var station_len: float = path.station_length
	if run.state == "loading":
		run.timer += dt
		run.s = station_len - 0.05
		# Board from the front of the queue, once they've reached the gate.
		while run.riders.size() < run.capacity and not run.queue.is_empty():
			var g: Guest = run.queue[0]
			if g.pos.distance_to(queue_spot(run, 0)) > 0.6:
				break
			run.queue.pop_front()
			run.riders.append(g)
			g.state = Guest.State.RIDE
			g.ride_id = int(run.ride.id)
		var full: bool = run.riders.size() >= run.capacity
		if (run.timer >= LOAD_TIME and (not run.riders.is_empty() or run.timer >= LOAD_TIME * 3.0)) or (full and run.timer >= 2.0):
			run.state = "running"
			run.timer = 0.0
			run.travelled = 0.0
	elif run.state == "running":
		var speeds: PackedFloat32Array = run.ride.stats.speeds
		var v: float = speeds[Track.index_at(path, run.s)]
		var d := maxf(0.3, v) * dt
		run.s = fposmod(run.s + d, path.length)
		run.travelled += d
		for g in run.riders:
			var p: Vector3 = Track.sample(path, run.s)[0]
			g.pos = Vector2(p.x, p.z)
		if run.travelled >= path.length:
			_unload(run)


func _unload(run: Dictionary) -> void:
	var r: Dictionary = run.ride
	var st: Dictionary = r.stats
	r.riders = int(r.get("riders", 0)) + run.riders.size()
	for g in run.riders:
		g.state = Guest.State.WALK
		g.ride_id = -1
		g.rides_taken += 1
		g.last_ride = int(r.id)
		g.energy = maxf(0.0, g.energy - 0.03)
		g.nausea = minf(1.0, g.nausea + float(st.nausea) * 0.04)
		if float(st.intensity) > g.thrill:
			g.happiness = maxf(0.0, g.happiness - 0.08)
			g.think("%s was too intense for me!" % r.name, "faceSad", now)
		else:
			g.happiness = minf(1.0, g.happiness + 0.06 + float(st.excitement) * 0.025)
			g.think("%s was great!" % r.name, "heart" if float(st.excitement) > 4.0 else "faceHappy", now)
		var out: Vector2i = r.get("exit", g.tile)
		g.tile = out
		g.pos = _center(out)
		g.goal = {}
		g.route = [run.exit_path] if run.exit_path != null else []
	run.riders = []
	run.state = "loading"
	run.timer = 0.0


## Opens or closes a ride. Opening runs the test first; returns why it
## couldn't open, or "".
func set_ride_open(r: Dictionary, open: bool) -> String:
	if open:
		var why := park.ride_open_error(r)
		if why != "":
			return why
		r.open = true
		refresh()
		_say("%s is open!" % r.name)
	else:
		r.open = false
		refresh()
	return ""


# --- Staff ---------------------------------------------------------------

func hire_janitor() -> String:
	if not park.can_afford(Pieces.JANITOR_HIRE):
		return "Not enough money"
	if not _walk.has(park.arrival_tile()):
		return "Janitors need a footpath from the gate"
	var names := []
	for s in park.staff:
		names.append(s.name)
	var s := {"id": park.next_id(), "kind": "janitor", "name": LGNameMaker.make(names, rng), "tile": park.arrival_tile()}
	park.staff.append(s)
	park.earn(-Pieces.JANITOR_HIRE, "Wages")
	_add_janitor_runtime(s)
	return ""


func fire_janitor(id: int) -> void:
	for s in park.staff.duplicate():
		if int(s.id) == id:
			park.staff.erase(s)
	for j in janitors.duplicate():
		if int(j.staff.id) == id:
			janitors.erase(j)


func _add_janitor_runtime(s: Dictionary) -> void:
	var t: Vector2i = s.tile
	if not _walk.has(t):
		var w = _nearest_walkable(t)
		if w != null:
			t = w
	janitors.append({"staff": s, "pos": _center(t), "tile": t, "route": [], "timer": 0.0, "sweeping": false, "facing": Vector2(0, -1)})


func _update_janitor(j: Dictionary, dt: float) -> void:
	j.staff.tile = j.tile
	if j.sweeping:
		j.timer -= dt
		if j.timer <= 0.0:
			var n := int(park.litter.get(j.tile, 0)) - 1
			if n <= 0:
				park.litter.erase(j.tile)
				j.sweeping = false
			else:
				park.litter[j.tile] = n
				j.timer = 1.2
		return
	if j.route.is_empty():
		if park.litter.has(j.tile):
			j.sweeping = true
			j.timer = 1.2
			return
		var targets := {}
		for t in park.litter:
			targets[t] = true
		var r = _route(j.tile, targets, 14) if not targets.is_empty() else null
		if r != null and not r.is_empty():
			j.route = r
		else:
			var g := Guest.new()
			g.tile = j.tile
			_wander(g)
			j.route = g.route
		return
	var next: Vector2i = j.route[0]
	if not _walk.has(next):
		j.route = []
		return
	var dest := _center(next)
	var dir: Vector2 = dest - j.pos
	var d := WALK_SPEED * 0.9 * dt
	if dir.length() <= d:
		j.pos = dest
		j.tile = next
		j.route.pop_front()
	else:
		j.facing = dir.normalized()
		j.pos += j.facing * d


# --- Rating and goals ----------------------------------------------------

func _update_rating() -> void:
	var happy := 0.65
	if not guests.is_empty():
		var sum := 0.0
		for g in guests:
			sum += g.happiness
		happy = sum / guests.size()
	var open := 0
	var thrills := 0.0
	for id in runs:
		var run: Dictionary = runs[id]
		if run.state != "closed" and run.ride.stats.get("ok", false):
			open += 1
			thrills += float(run.ride.stats.excitement)
	var litter := 0
	for t in park.litter:
		litter += int(park.litter[t])
	var r := 150.0 + 500.0 * happy + minf(150.0, 40.0 * open) + minf(120.0, thrills * 10.0) - minf(250.0, litter * 4.0)
	rating = clampi(int(r), 0, 999)
	_check_goal(false)


## Wins as soon as the goal is met; loses when the deadline passes first.
func _check_goal(month_end: bool) -> void:
	if park.scenario == "" or park.goal_state != "":
		return
	var s := Scenarios.get_def(park.scenario)
	if s.is_empty():
		return
	if guests.size() >= int(s.guests) and rating >= int(s.rating):
		park.goal_state = "won"
		_say("Scenario complete! %s is the talk of the valley. Keep building as long as you like." % park.name)
		goal_changed.emit("won")
	elif month_end and park.month_index() >= int(s.deadline_month):
		park.goal_state = "lost"
		_say("The deadline has passed without reaching the goal. You can keep playing this park.")
		goal_changed.emit("lost")


func _say(text: String) -> void:
	recent_messages.append({"text": text, "time": now})
	while recent_messages.size() > 20:
		recent_messages.pop_front()
	message.emit(text)


## Writes the guests back into the park for saving.
func store() -> void:
	var rows := []
	for g in guests:
		if g.state != Guest.State.LEAVE:
			rows.append(g.to_row())
	park.guests = rows


func average_happiness() -> float:
	if guests.is_empty():
		return 0.0
	var s := 0.0
	for g in guests:
		s += g.happiness
	return s / guests.size()
