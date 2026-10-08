class_name ParkView
extends Node3D
## Draws a park and its simulation: the ground, everything built on the
## tiles, coaster track and trains, guests, janitors, litter and the guests'
## emotes. It only reads ParkData and ParkSim; call refresh() after building.

const KIT := "res://assets/kenney/coaster-kit/"
const CHARACTERS := "res://assets/kenney/mini-characters/"
const EMOTES := "res://assets/kenney/emotes/emote_%s.png"
const LOOKS := ["character-female-a", "character-male-a", "character-female-b", "character-male-b",
	"character-female-c", "character-male-c", "character-female-d", "character-male-d",
	"character-female-e", "character-male-e", "character-female-f", "character-male-f"]
const GUEST_SCALE := 0.62
const TRAIN_SCALE := 0.75
const CAR_SPACING := 1.0
## Rails sit this high over the points the track is built from, so track
## on the ground rests on its sleepers.
const TRACK_Y := 0.2
const WALK_Y := 0.04
## Kenney's path pieces: which sides each opens to (Track.DIRS indices), as
## modelled, before rotating.
const PATH_SHAPES := {
	"crossing": [0, 1, 2, 3],
	"split": [0, 2, 3],
	"straight": [0, 2],
	"corner": [0, 3],
	"exit": [0],
}
const GRASS := Color("55913f")
const GRASS_OUTSIDE := Color("4a7a36")

var park: ParkData
var sim: ParkSim
## Game speed (set by Game) so trains run ahead at the right pace.
var sim_speed := 1.0
## Show the build grid on the ground.
var grid := false:
	set(v):
		grid = v
		if _ground_mat:
			_ground_mat.set_shader_parameter("grid", 1.0 if v else 0.0)

var _scenes := {}
var _tiles_root: Node3D
var _tile_nodes := {}
var _tile_sigs := {}
var _rides_root: Node3D
var _ride_nodes := {}
var _guests_root: Node3D
var _guest_nodes := {}
var _janitor_nodes := {}
var _trains := {}
var _litter: MultiMeshInstance3D
var _litter_timer := 0.0
var _ground_mat: ShaderMaterial
var _emote_tex := {}
var _track_mat: StandardMaterial3D


func setup(p_park: ParkData, p_sim: ParkSim) -> void:
	park = p_park
	sim = p_sim
	_track_mat = StandardMaterial3D.new()
	_track_mat.vertex_color_use_as_albedo = true
	_track_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_track_mat.roughness = 0.85
	_build_world()
	_tiles_root = Node3D.new()
	add_child(_tiles_root)
	_rides_root = Node3D.new()
	add_child(_rides_root)
	_guests_root = Node3D.new()
	add_child(_guests_root)
	_litter = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var paper := BoxMesh.new()
	paper.size = Vector3(0.07, 0.012, 0.09)
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	paper.material = pm
	mm.mesh = paper
	_litter.multimesh = mm
	add_child(_litter)
	refresh()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4f93d8")
	sm.sky_horizon_color = Color("bfe0f5")
	sm.ground_horizon_color = Color("bfe0f5")
	sm.ground_bottom_color = Color("6a9a50")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	# The ground: the park's land, a darker margin round it, and a grid.
	var margin := 24.0
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(park.size.x + margin * 2, park.size.y + margin * 2)
	ground.mesh = plane
	ground.position = Vector3(park.size.x * 0.5, 0, park.size.y * 0.5)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec3 grass : source_color;
uniform vec3 outside : source_color;
uniform vec2 park_size;
uniform float grid = 0.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world.xz;
	bool inside = p.x >= 0.0 && p.y >= 0.0 && p.x <= park_size.x && p.y <= park_size.y;
	vec2 f = fract(p);
	float speck = fract(sin(dot(floor(p * 4.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = inside ? grass : outside;
	col *= 0.95 + speck * 0.08;
	float line = step(min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)), 0.014);
	if (inside) col = mix(col, vec3(0.92, 1.0, 0.85), line * grid * 0.25);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = shader
	_ground_mat.set_shader_parameter("grass", GRASS)
	_ground_mat.set_shader_parameter("outside", GRASS_OUTSIDE)
	_ground_mat.set_shader_parameter("park_size", Vector2(park.size))
	_ground_mat.set_shader_parameter("grid", 1.0 if grid else 0.0)
	ground.material_override = _ground_mat
	add_child(ground)
	# Woods all round the outside, so the park sits in a valley.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var woods := Node3D.new()
	add_child(woods)
	for i in 260:
		var p := Vector2(rng.randf_range(-margin + 1, park.size.x + margin - 1), rng.randf_range(-margin + 1, park.size.y + margin - 1))
		var d := maxf(maxf(-p.x, p.x - park.size.x), maxf(-p.y, p.y - park.size.y))
		if d < 1.5 or (absf(p.x - park.size.x * 0.5) < 3.0 and p.y > park.size.y):
			continue
		var tree := _instance("tree-large" if rng.randf() < 0.5 else "tree")
		tree.position = Vector3(p.x, 0, p.y)
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(1.0, 1.8)
		woods.add_child(tree)


func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var path := name if name.begins_with("res://") else KIT + name + ".glb"
		_scenes[name] = load(path)
	return _scenes[name]


func _instance(name: String) -> Node3D:
	return (_scene(name) as PackedScene).instantiate()


static func tile_center(t: Vector2i, y := 0.0) -> Vector3:
	return Vector3(t.x + 0.5, y, t.y + 0.5)


## Rotation about y that turns a model facing (or opening) towards
## Track.DIRS[from] to face Track.DIRS[to].
static func turn(from: int, to: int) -> float:
	return posmod(to - from, 4) * PI * 0.5


# --- Tiles ---------------------------------------------------------------

## Brings the drawing up to date with the park after anything was built.
func refresh() -> void:
	var seen := {}
	for t in park.tiles:
		var sig := _signature(t)
		seen[t] = true
		if _tile_sigs.get(t, "") == sig:
			continue
		if _tile_nodes.has(t):
			_tile_nodes[t].queue_free()
		_tile_sigs[t] = sig
		var node := _make_tile(t)
		_tile_nodes[t] = node
		if node:
			_tiles_root.add_child(node)
	for t in _tile_nodes.keys():
		if not seen.has(t):
			if _tile_nodes[t]:
				_tile_nodes[t].queue_free()
			_tile_nodes.erase(t)
			_tile_sigs.erase(t)
	_refresh_rides()
	_update_litter()


func _signature(t: Vector2i) -> String:
	var tile: Dictionary = park.tiles[t]
	var s := "%s/%s/%d" % [tile.k, tile.id, int(tile.r)]
	if tile.k in ["path", "queue"]:
		s += "/%s" % [_open_sides(t)]
	return s


## Which sides of a path or queue tile lead somewhere.
func _open_sides(t: Vector2i) -> Array:
	var k := park.kind_at(t)
	var out := []
	for d in 4:
		var n: Vector2i = t + Track.DIRS[d]
		if _connects(t, k, n, d):
			out.append(d)
	return out


func _connects(t: Vector2i, k: String, n: Vector2i, d: int) -> bool:
	var nk := park.kind_at(n)
	var back := posmod(d + 2, 4)
	if k == "path":
		match nk:
			"path":
				return true
			"entrance":
				return n == park.gate_tile()
			"stall", "ride_out":
				return int(park.tiles[n].r) == back
			"queue":
				return _queue_end(n)
		return false
	# Queue lines join each other, the ride's entrance and, at their ends, a path.
	match nk:
		"queue":
			return true
		"ride_in":
			return int(park.tiles[n].r) == back
		"path":
			return _queue_end(t)
	return false


func _queue_end(t: Vector2i) -> bool:
	var links := 0
	for n in park.neighbours(t):
		var nk := park.kind_at(n)
		if nk == "queue" or (nk == "ride_in" and n - t == Track.DIRS[posmod(int(park.tiles[n].r) + 2, 4)]):
			links += 1
	return links <= 1


func _make_tile(t: Vector2i) -> Node3D:
	var tile: Dictionary = park.tiles[t]
	var node: Node3D
	match str(tile.k):
		"path", "queue":
			node = _path_piece(str(tile.k), _open_sides(t))
		"entrance":
			if t != park.gate_tile():
				return null
			node = _instance("park-entrance")
			node.rotation.y = turn(2, int(tile.r))
		"stall":
			node = _instance(Pieces.model(str(tile.id)))
			node.rotation.y = turn(2, int(tile.r))
		"ride_in", "ride_out":
			node = _instance("ride-entrance" if tile.k == "ride_in" else "ride-exit")
			node.rotation.y = turn(2, int(tile.r))
		"scenery":
			node = _instance(Pieces.model(str(tile.id)))
			node.rotation.y = turn(0, int(tile.r))
			if tile.get("wild", false):
				node.scale = Vector3.ONE * (1.0 + float(hash(t) % 40) / 100.0)
	if node == null:
		return null
	var holder := Node3D.new()
	holder.position = tile_center(t)
	holder.add_child(node)
	return holder


## The Kenney piece (and its turn) for a path or queue open on `sides`.
func _path_piece(kind: String, sides: Array) -> Node3D:
	var shape := "crossing"
	var from := 0
	var to := 0
	match sides.size():
		4:
			shape = "crossing"
		3:
			shape = "split"
			var missing := 0
			for d in 4:
				if not d in sides:
					missing = d
			# The split is closed on +x (1).
			from = 1
			to = missing
		2:
			if posmod(sides[1] - sides[0], 4) == 2:
				shape = "straight"
				to = sides[0]
			else:
				shape = "corner"
				# The corner opens on 3 and 0; find the side whose next is open.
				var a: int = sides[0] if posmod(sides[0] + 1, 4) == sides[1] else sides[1]
				from = 3
				to = a
		1:
			shape = "exit"
			to = sides[0]
		0:
			shape = "straight"
	var name := "%s-%s" % [kind, shape]
	if kind == "queue":
		if shape == "exit":
			name = "queue-entrance"
		elif shape == "crossing":
			name = "queue-crossing"
	var node := _instance(name)
	node.rotation.y = turn(from, to)
	return node


# --- Rides ---------------------------------------------------------------

func _refresh_rides() -> void:
	var seen := {}
	for r in park.rides:
		var id := int(r.id)
		seen[id] = true
		var key := str(r.station) + str(r.pieces) + str(not r.stats.is_empty())
		if _ride_nodes.has(id) and _ride_nodes[id].get_meta("key") == key:
			continue
		if _ride_nodes.has(id):
			_ride_nodes[id].queue_free()
		var node := _make_ride(r)
		node.set_meta("key", key)
		_ride_nodes[id] = node
		_rides_root.add_child(node)
	for id in _ride_nodes.keys():
		if not seen.has(id):
			_ride_nodes[id].queue_free()
			_ride_nodes.erase(id)
	for id in _trains.keys():
		if not seen.has(id):
			_trains[id].node.queue_free()
			_trains.erase(id)


func _make_ride(r: Dictionary) -> Node3D:
	var node := Node3D.new()
	var path := Track.build(r)
	var banks := PackedFloat32Array()
	if path.complete and r.stats.get("ok", false):
		banks = r.stats.banks
	var mi := MeshInstance3D.new()
	mi.mesh = TrackMesh.build(path.points, path.chain, banks, path.complete)
	mi.material_override = _track_mat
	mi.position.y = TRACK_Y
	node.add_child(mi)
	var st: Dictionary = r.station
	for t in Track.station_tiles(st):
		var s := _instance("station")
		s.position = tile_center(t)
		s.rotation.y = turn(0, int(st.dir))
		node.add_child(s)
	return node


## A ghost of track points, for the coaster builder's next piece.
func make_ghost_track(points: PackedVector3Array, ok: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tint := Color(0.35, 0.95, 0.45) if ok else Color(0.95, 0.3, 0.25)
	mi.mesh = TrackMesh.build(points, PackedByteArray(), PackedFloat32Array(), false, true, tint)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.6)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position.y = TRACK_Y
	return mi


# --- Every frame ---------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	_update_guests(delta)
	_update_janitors(delta)
	_update_trains(delta)
	_litter_timer -= delta
	if _litter_timer <= 0.0:
		_litter_timer = 0.5
		_update_litter()


## How fast drawn things catch up with the simulation, which moves in steps.
static func _follow(delta: float) -> float:
	return 1.0 - exp(-delta * 14.0)


func _make_person(look: int, wheelchair := false) -> Node3D:
	var root := Node3D.new()
	var rc := RigCharacter.create(_scene(CHARACTERS + LOOKS[posmod(look, LOOKS.size())] + ".glb"), GUEST_SCALE)
	rc.name = "Rig"
	root.add_child(rc)
	if wheelchair:
		var chair: Node3D = _scene(CHARACTERS + "wheelchair.glb").instantiate()
		chair.scale = Vector3.ONE * GUEST_SCALE
		root.add_child(chair)
		rc.play("wheelchair-sit")
	return root


func _emote_sprite(holder: Node3D) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Emote"
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = 0.0045
	s.position.y = 0.75
	s.visible = false
	holder.add_child(s)
	return s


func _emote(name: String) -> Texture2D:
	if not _emote_tex.has(name):
		var path := EMOTES % name
		_emote_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _emote_tex[name]


func _update_guests(delta: float) -> void:
	var seen := {}
	var k := _follow(delta)
	for g: Guest in sim.guests:
		seen[g.id] = true
		var node: Node3D = _guest_nodes.get(g.id)
		if node == null:
			node = _make_person(g.look, g.wheelchair)
			_emote_sprite(node)
			node.position = Vector3(g.pos.x, WALK_Y, g.pos.y)
			_guests_root.add_child(node)
			_guest_nodes[g.id] = node
		# Riders are drawn in the train.
		node.visible = g.state != Guest.State.RIDE
		if not node.visible:
			continue
		var target := Vector3(g.pos.x, WALK_Y, g.pos.y)
		var facing := g.facing
		if g.state == Guest.State.SIT and g.goal.get("kind", "") == "bench":
			var bench: Vector2i = g.goal.bench
			var away := g.pos - Vector2(bench.x + 0.5, bench.y + 0.5)
			target = Vector3(bench.x + 0.5, 0.0, bench.y + 0.5) + Vector3(away.x, 0, away.y).normalized() * 0.15
			facing = away.normalized()
		var before := node.position
		node.position = before.lerp(target, k)
		var moving := before.distance_to(node.position) / maxf(delta, 0.001)
		if facing != Vector2.ZERO:
			var want := atan2(facing.x, facing.y)
			node.rotation.y = lerp_angle(node.rotation.y, want, k)
		var rc: RigCharacter = node.get_node("Rig")
		if g.wheelchair:
			rc.play("wheelchair-move-forward" if moving > 0.1 else "wheelchair-sit")
		elif g.state == Guest.State.SIT:
			rc.play("sit")
		elif moving > 0.1:
			rc.play("walk", 0.15, clampf(moving * 1.6, 0.5, 2.5))
		else:
			rc.play("holding-right" if g.holding != "" else "idle")
		var em: Sprite3D = node.get_node("Emote")
		em.visible = g.emote != ""
		if em.visible:
			em.texture = _emote(g.emote)
	for id in _guest_nodes.keys():
		if not seen.has(id):
			_guest_nodes[id].queue_free()
			_guest_nodes.erase(id)


func _update_janitors(delta: float) -> void:
	var seen := {}
	var k := _follow(delta)
	for j in sim.janitors:
		var id := int(j.staff.id)
		seen[id] = true
		var node: Node3D = _janitor_nodes.get(id)
		if node == null:
			node = _make_person(5)
			# Janitors wear a cap so players can tell them apart.
			var cap := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.09
			cm.bottom_radius = 0.1
			cm.height = 0.05
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("2f6fd6")
			cm.material = mat
			cap.mesh = cm
			cap.position.y = 0.44
			node.add_child(cap)
			node.position = Vector3(j.pos.x, WALK_Y, j.pos.y)
			_guests_root.add_child(node)
			_janitor_nodes[id] = node
		var before := node.position
		node.position = before.lerp(Vector3(j.pos.x, WALK_Y, j.pos.y), k)
		var moving := before.distance_to(node.position) / maxf(delta, 0.001)
		var f: Vector2 = j.facing
		node.rotation.y = lerp_angle(node.rotation.y, atan2(f.x, f.y), k)
		var rc: RigCharacter = node.get_node("Rig")
		if j.sweeping:
			rc.play("interact-right")
			rc.set_looping("interact-right")
		else:
			rc.play("walk" if moving > 0.1 else "idle")
	for id in _janitor_nodes.keys():
		if not seen.has(id):
			_janitor_nodes[id].queue_free()
			_janitor_nodes.erase(id)


func _update_trains(delta: float) -> void:
	for id in sim.runs:
		var run: Dictionary = sim.runs[id]
		var r: Dictionary = run.ride
		var want: bool = run.path.complete and r.stats.get("ok", false)
		var tr: Dictionary = _trains.get(id, {})
		if not want:
			if not tr.is_empty():
				tr.node.queue_free()
				_trains.erase(id)
			continue
		var cars := clampi(int(r.cars), 1, int(r.station.length))
		if tr.is_empty() or tr.cars != cars or tr.key != run.path_key:
			if not tr.is_empty():
				tr.node.queue_free()
			tr = _make_train(cars)
			tr.key = run.path_key
			tr.s = float(run.s)
			_trains[id] = tr
			_rides_root.add_child(tr.node)
		# Run ahead with the ride's own speeds, easing towards the simulation.
		var path: Dictionary = run.path
		var total: float = path.length
		if run.state == "running":
			var speeds: PackedFloat32Array = r.stats.speeds
			var v := maxf(0.3, speeds[Track.index_at(path, tr.s)])
			tr.s = fposmod(float(tr.s) + v * delta * sim_speed, total)
		var err := wrapf(float(run.s) - float(tr.s), -total * 0.5, total * 0.5)
		tr.s = fposmod(float(tr.s) + err * minf(1.0, delta * 4.0), total)
		var banks: PackedFloat32Array = r.stats.banks
		for i in cars:
			var s := float(tr.s) - 0.55 - i * CAR_SPACING
			var at := Track.sample(path, s)
			var p: Vector3 = at[0]
			var tan: Vector3 = at[1]
			var bank := banks[Track.index_at(path, s)] if banks.size() > 0 else 0.0
			var up := Vector3.UP - tan * tan.dot(Vector3.UP)
			up = up.normalized() if up.length() > 0.001 else Vector3.BACK
			var side := tan.cross(up).normalized()
			up = (up * cos(bank) + side * sin(bank)).normalized()
			var x := up.cross(tan).normalized()
			var car: Node3D = tr.cars_nodes[i]
			car.transform = Transform3D(Basis(x, up, tan), p + Vector3(0, TRACK_Y, 0))
		# Riders sit two to a car, front first.
		var riders: Array = run.riders
		var seats: Array = tr.seats
		for i in seats.size():
			var seat: Dictionary = seats[i]
			var g: Guest = riders[i] if i < riders.size() else null
			seat.holder.visible = g != null
			if g != null and seat.look != g.look:
				seat.look = g.look
				for c in seat.holder.get_children():
					c.queue_free()
				var rc := RigCharacter.create(_scene(CHARACTERS + LOOKS[posmod(g.look, LOOKS.size())] + ".glb"), GUEST_SCALE * 0.9)
				rc.play("sit")
				seat.holder.add_child(rc)


func _make_train(cars: int) -> Dictionary:
	var node := Node3D.new()
	var nodes := []
	var seats := []
	for i in cars:
		var car := Node3D.new()
		var model := _instance("coaster-train-front" if i == 0 else "coaster-train")
		model.scale = Vector3.ONE * TRAIN_SCALE
		car.add_child(model)
		node.add_child(car)
		nodes.append(car)
		for row in 2:
			var holder := Node3D.new()
			holder.position = Vector3(0, 0.2, 0.18 - row * 0.4)
			holder.visible = false
			car.add_child(holder)
			seats.append({"holder": holder, "look": -1})
	return {"node": node, "cars": cars, "cars_nodes": nodes, "seats": seats, "s": 0.0, "key": ""}


func _update_litter() -> void:
	var mm := _litter.multimesh
	var items := []
	for t in park.litter:
		for i in int(park.litter[t]):
			items.append([t, i])
	mm.instance_count = items.size()
	var colors := [Color("f4f1e8"), Color("e8c84a"), Color("e86a5a"), Color("8fc4e8")]
	for i in items.size():
		var t: Vector2i = items[i][0]
		var h := hash(Vector3i(t.x, t.y, items[i][1]))
		var off := Vector3(float(h % 100) / 100.0 - 0.5, 0, float((h / 100) % 100) / 100.0 - 0.5) * 0.7
		var b := Basis(Vector3.UP, float(h % 628) / 100.0)
		mm.set_instance_transform(i, Transform3D(b, tile_center(t, WALK_Y + 0.01) + off))
		mm.set_instance_color(i, colors[h % colors.size()])


## The guest nearest `p` (tile units on the ground), within `reach`.
func guest_near(p: Vector2, reach := 0.45) -> Guest:
	var best: Guest = null
	var bd := reach
	for g: Guest in sim.guests:
		if g.state == Guest.State.RIDE:
			continue
		var d := g.pos.distance_to(p)
		if d < bd:
			bd = d
			best = g
	return best


## Where a guest is drawn, for following them with the camera.
func guest_position(id: int) -> Vector3:
	var n: Node3D = _guest_nodes.get(id)
	return n.global_position if n else Vector3.ZERO


## A see-through copy of a model, for showing where something will go.
func make_ghost(model_name: String, ok: bool) -> Node3D:
	var n := _instance(model_name)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 1.0, 0.5, 0.55) if ok else Color(1.0, 0.35, 0.3, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n
