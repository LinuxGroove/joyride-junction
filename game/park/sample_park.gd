class_name SamplePark
extends RefCounted
## Builds a small working park on a fresh 36 x 36 map: footpaths, a Little
## Woody coaster with its queue, shops, benches and bins. Tests, screenshots
## and the --demo shortcut start from it.


static func build(p: ParkData) -> void:
	var gate := p.gate_tile()
	var cx := gate.x
	for z in range(21, gate.y):
		_path(p, Vector2i(cx, z))
	for x in range(9, cx + 1):
		_path(p, Vector2i(x, 20))
	for z in range(8, 21):
		_path(p, Vector2i(9, z))
	_path(p, Vector2i(10, 11))
	# Little Woody: its station runs along x = 12, heading +z.
	var d := CoasterDesigns.get_design("little_woody")
	var r := p.add_coaster(Vector2i(12, 8), 0, int(d.station))
	for piece in d.pieces:
		p.add_piece(r, piece)
	r.name = "Little Woody"
	p.set_door(r, "ride_in", Vector2i(11, 9))
	p.set_door(r, "ride_out", Vector2i(11, 11))
	for q in [Vector2i(10, 9), Vector2i(10, 8)]:
		_put(p, "queue", q)
	r.open = p.ride_open_error(r) == ""
	_put(p, "food", Vector2i(cx + 1, 24))
	_put(p, "drinks", Vector2i(cx - 1, 24))
	_put(p, "toilets", Vector2i(cx + 1, 27))
	_put(p, "info", Vector2i(cx - 1, 27))
	for z in [22, 30]:
		_put(p, "bench", Vector2i(cx - 1, z))
		_put(p, "bin", Vector2i(cx + 1, z))
	for x in [11, 13, 15]:
		_put(p, "flowers", Vector2i(x, 21))
		_put(p, "tree", Vector2i(x + 1, 21))


static func _path(p: ParkData, t: Vector2i) -> void:
	if p.kind_at(t) != "path":
		_put(p, "path", t)


static func _put(p: ParkData, id: String, t: Vector2i) -> void:
	if p.kind_at(t) == "scenery":
		p.tiles.erase(t)
	var why := p.build_error(id, t)
	if why == "":
		p.build(id, t)
	else:
		push_warning("Sample park: %s at %s: %s" % [id, t, why])
