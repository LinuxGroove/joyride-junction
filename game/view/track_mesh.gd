class_name TrackMesh
extends RefCounted
## Builds the wooden coaster's track and supports as one mesh, straight from
## the circuit's points (see Track.build), so any layout the builder allows
## has a track to match. Rails sit on the points; the train rides on them.

const RAIL_GAP := 0.2
const SLEEPER_EVERY := 0.3
const SUPPORT_EVERY := 1.0

const STEEL := Color("b7bcc4")
const BEAM := Color("8a5a35")
const SLEEPER := Color("c08a55")
const POST := Color("9a6a40")
const CHAIN := Color("3a3a40")
const BRAKE := Color("d8463c")


## The frame at each point: [tangent, up, side], with turns banked by
## `banks` (radians, from RidePhysics) when given.
static func frames(points: PackedVector3Array, banks: PackedFloat32Array, closed: bool) -> Array:
	var out := []
	var n := points.size()
	for i in n:
		var a := points[i - 1] if i > 0 else (points[n - 2] if closed and n > 2 else points[i])
		var b := points[i + 1] if i < n - 1 else (points[1] if closed and n > 2 else points[i])
		var tan := (b - a).normalized()
		if tan == Vector3.ZERO:
			tan = Vector3.FORWARD
		var up := Vector3.UP - tan * tan.dot(Vector3.UP)
		up = up.normalized() if up.length() > 0.001 else Vector3.BACK
		var side := tan.cross(up).normalized()
		var bank := banks[i] if i < banks.size() else 0.0
		if bank != 0.0:
			up = (up * cos(bank) + side * sin(bank)).normalized()
			side = tan.cross(up).normalized()
		out.append([tan, up, side])
	return out


## The track mesh for a circuit. `chain` flags lifts and brakes per point;
## `tint` (when not white) colours the whole thing, for the builder's ghost.
static func build(points: PackedVector3Array, chain: PackedByteArray, banks: PackedFloat32Array,
		closed: bool, supports := true, tint := Color.WHITE) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	if n < 2:
		return ArrayMesh.new()
	var fr := frames(points, banks, closed)
	var c := func(col: Color) -> Color: return col if tint == Color.WHITE else tint
	for s in [-1.0, 1.0]:
		_tube(st, points, fr, s * RAIL_GAP, 0.0, 0.05, 0.06, c.call(STEEL))
		_tube(st, points, fr, s * RAIL_GAP, -0.05, 0.11, 0.1, c.call(BEAM))
	# Sleepers across the rails, a chain up lifts and fins on brakes.
	var since := SLEEPER_EVERY
	for i in range(1, n):
		var step := points[i].distance_to(points[i - 1])
		since += step
		if since >= SLEEPER_EVERY:
			since = 0.0
			_box(st, points[i], fr[i], Vector3(0.56, 0.04, 0.07), -0.18, c.call(SLEEPER))
		var flag := chain[i] if i < chain.size() else 0
		if flag == Track.LIFT or flag == Track.BRAKES:
			var col: Color = c.call(CHAIN if flag == Track.LIFT else BRAKE)
			var w := 0.07 if flag == Track.LIFT else 0.04
			_quad_strip(st, points[i - 1], points[i], fr[i - 1], fr[i], w, -0.06 if flag == Track.LIFT else -0.02, col)
	if supports:
		_supports(st, points, fr, chain, c.call(POST))
	st.generate_normals()
	return st.commit()


## A box-section beam along the points, `offset` to the side, its top
## `top` above the rail line.
static func _tube(st: SurfaceTool, pts: PackedVector3Array, fr: Array, offset: float, top: float, height: float, width: float, col: Color) -> void:
	var prev: Array = []
	for i in pts.size():
		var f: Array = fr[i]
		var c: Vector3 = pts[i] + f[2] * offset + f[1] * (top - height * 0.5)
		var hx: Vector3 = f[2] * width * 0.5
		var hy: Vector3 = f[1] * height * 0.5
		var ring := [c - hx + hy, c + hx + hy, c + hx - hy, c - hx - hy]
		if not prev.is_empty():
			for k in 4:
				_quad(st, prev[k], prev[(k + 1) % 4], ring[(k + 1) % 4], ring[k], col)
		prev = ring


static func _quad_strip(st: SurfaceTool, a: Vector3, b: Vector3, fa: Array, fb: Array, width: float, y: float, col: Color) -> void:
	var a0: Vector3 = a + fa[1] * y - fa[2] * width * 0.5
	var a1: Vector3 = a + fa[1] * y + fa[2] * width * 0.5
	var b0: Vector3 = b + fb[1] * y - fb[2] * width * 0.5
	var b1: Vector3 = b + fb[1] * y + fb[2] * width * 0.5
	_quad(st, a0, a1, b1, b0, col)


## A box centred on `p` in the frame `f` (size across, up, along).
static func _box(st: SurfaceTool, p: Vector3, f: Array, size: Vector3, y: float, col: Color) -> void:
	var c: Vector3 = p + f[1] * y
	var x: Vector3 = f[2] * size.x * 0.5
	var u: Vector3 = f[1] * size.y * 0.5
	var z: Vector3 = f[0] * size.z * 0.5
	_box_axes(st, c, x, u, z, col)


static func _box_axes(st: SurfaceTool, c: Vector3, x: Vector3, u: Vector3, z: Vector3, col: Color) -> void:
	var v := [c - x - u - z, c + x - u - z, c + x + u - z, c - x + u - z,
		c - x - u + z, c + x - u + z, c + x + u + z, c - x + u + z]
	for q in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_quad(st, v[q[0]], v[q[1]], v[q[2]], v[q[3]], col)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col)
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)


## Wooden posts from the track down to the ground, with cross braces.
static func _supports(st: SurfaceTool, pts: PackedVector3Array, fr: Array, chain: PackedByteArray, col: Color) -> void:
	var since := SUPPORT_EVERY
	for i in range(1, pts.size()):
		since += pts[i].distance_to(pts[i - 1])
		if since < SUPPORT_EVERY:
			continue
		var flag := chain[i] if i < chain.size() else 0
		var bottom: float = pts[i].y - 0.2
		if flag == Track.STATION or bottom < 0.15:
			continue
		since = 0.0
		var f: Array = fr[i]
		var flat := Vector3(f[2].x, 0, f[2].z).normalized()
		if flat == Vector3.ZERO:
			continue
		var along := Vector3(f[0].x, 0, f[0].z).normalized()
		var h := bottom
		for s in [-1.0, 1.0]:
			var base: Vector3 = Vector3(pts[i].x, 0, pts[i].z) + flat * s * 0.26
			_box_axes(st, base + Vector3(0, h * 0.5, 0), flat * 0.035, Vector3(0, h * 0.5, 0), along * 0.035, col)
		var y := 0.9
		while y < h:
			var mid := Vector3(pts[i].x, y, pts[i].z)
			_box_axes(st, mid, flat * 0.28, Vector3(0, 0.025, 0), along * 0.025, col)
			y += 1.2
