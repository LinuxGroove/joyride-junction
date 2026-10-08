class_name Track
extends RefCounted
## Coaster track geometry. A coaster is a station (a straight run of tiles)
## followed by a chain of pieces, each starting where the last one ended.
## Pieces are [turn, slope, chain]:
##   turn  -2 large right, -1 small right, 0 straight, 1 small left, 2 large left
##   slope the slope the piece ends on, -2 steep down .. 2 steep up; it may
##         differ from the slope it starts on by one step
##   extra 1 for a chain lift that pulls the train up this piece, 2 for
##         brakes that slow it down
## Positions are in tiles (one tile is one unit; the ground is y = 0). A pose
## is the middle of the tile edge a piece starts on, the heading and slope.

## Headings, turning left adds one. Facing +z, +x is on the left.
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
## Rise per tile for slope -2 .. 2 (index slope + 2).
const SLOPES := [-1.0, -0.5, 0.0, 0.5, 1.0]
const TURN_RADIUS := {1: 1.5, 2: 2.5}
const SAMPLE_STEP := 0.1
## How far apart two tracks on the same tile must be, and how high a track
## must be to pass over paths and other things on the ground.
const TRACK_GAP := 1.0
const CLEARANCE := 2.0
const MAX_HEIGHT := 14.0
const MIN_STATION := 3
const MAX_STATION := 8
const MAX_PIECES := 400

## Piece extras, and the station's own powered tyres (only in built paths).
const LIFT := 1
const BRAKES := 2
const STATION := 3

const TURN_NAMES := {-2: "Wide right", -1: "Right", 0: "Straight", 1: "Left", 2: "Wide left"}
const SLOPE_NAMES := {-2: "steep down", -1: "down", 0: "flat", 1: "up", 2: "steep up"}


static func forward(dir: int) -> Vector3:
	var d: Vector2i = DIRS[posmod(dir, 4)]
	return Vector3(d.x, 0, d.y)


static func left(dir: int) -> Vector3:
	return forward(dir + 1)


static func slope_rise(slope: int) -> float:
	return SLOPES[clampi(slope, -2, 2) + 2]


## The pose where a station's track begins: the middle of the edge where the
## train enters the station's first tile.
static func station_start(station: Dictionary) -> Dictionary:
	var tile: Vector2i = station.tile
	var dir: int = station.dir
	var center := Vector3(tile.x + 0.5, float(station.get("height", 0.0)), tile.y + 0.5)
	return {"pos": center - forward(dir) * 0.5, "dir": dir, "slope": 0}


static func station_end(station: Dictionary) -> Dictionary:
	var start := station_start(station)
	return {"pos": start.pos + forward(start.dir) * int(station.length), "dir": start.dir, "slope": 0}


## Tiles a station covers, front first.
static func station_tiles(station: Dictionary) -> Array:
	var out := []
	var d: Vector2i = DIRS[posmod(int(station.dir), 4)]
	for i in int(station.length):
		out.append(Vector2i(station.tile) + d * i)
	return out


## Why a piece can't follow `pose`, or "" when it can.
static func piece_error(pose: Dictionary, piece: Array) -> String:
	var turn: int = piece[0]
	var slope: int = piece[1]
	var from: int = pose.slope
	if absi(slope - from) > 1:
		return "Change the slope one step at a time"
	if turn != 0 and (from != 0 or slope != 0):
		return "Level the track out before turning"
	var extra := int(piece[2]) if piece.size() > 2 else 0
	if extra == LIFT and (slope < 0 or from < 0):
		return "Chain lifts only go up or along"
	if extra == BRAKES and (slope != 0 or from != 0 or turn != 0):
		return "Brakes go on flat, straight track"
	return ""


## Samples along one piece, start excluded, end included, and its end pose.
static func piece_points(pose: Dictionary, piece: Array) -> Dictionary:
	var turn: int = piece[0]
	var s0 := slope_rise(pose.slope)
	var s1 := slope_rise(piece[1])
	var start: Vector3 = pose.pos
	var dir: int = pose.dir
	var fwd := forward(dir)
	var length := 1.0
	var radius := 0.0
	var center := Vector3.ZERO
	var side := 0.0
	if turn != 0:
		radius = TURN_RADIUS[absi(turn)]
		length = radius * PI / 2.0
		side = 1.0 if turn > 0 else -1.0
		center = start + left(dir) * side * radius
	var n := maxi(2, ceili(length / SAMPLE_STEP))
	var pts := PackedVector3Array()
	for i in range(1, n + 1):
		var t := float(i) / n
		var p: Vector3
		if turn == 0:
			p = start + fwd * t
		else:
			# Angle swept around the centre; the start sits at -left*side.
			var a := t * PI / 2.0
			var from_center := -left(dir) * side
			p = center + (from_center * cos(a) + fwd * sin(a)) * radius
		# Horizontal length along this piece is `length`; the slope eases
		# from s0 to s1 so joints are smooth.
		var h := length * (s0 * t + (s1 - s0) * t * t / 2.0)
		p.y = start.y + h
		pts.append(p)
	var end := pts[pts.size() - 1]
	end = Vector3(snappedf(end.x, 0.5), snappedf(end.y, 0.125), snappedf(end.z, 0.5))
	pts[pts.size() - 1] = end
	var end_dir := posmod(dir + signi(turn), 4)
	return {"points": pts, "pose": {"pos": end, "dir": end_dir, "slope": int(piece[1])}, "length": length}


static func same_pose(a: Dictionary, b: Dictionary) -> bool:
	return (a.pos as Vector3).distance_to(b.pos) < 0.01 and posmod(int(a.dir), 4) == posmod(int(b.dir), 4) and int(a.slope) == int(b.slope)


## The whole circuit: dense points from the station's start, which piece and
## chain flag each point belongs to, tile heights, and whether it closes.
## `ride` holds `station` and `pieces`.
static func build(ride: Dictionary) -> Dictionary:
	var station: Dictionary = ride.station
	var start := station_start(station)
	var pts := PackedVector3Array([start.pos])
	var chain := PackedByteArray([0])
	var piece_of := PackedInt32Array([-1])
	# The station is powered: count it as a slow lift.
	var p0: Vector3 = start.pos
	var fwd := forward(start.dir)
	var sn := int(station.length) * 10
	for i in range(1, sn + 1):
		pts.append(p0 + fwd * (float(i) / 10.0))
		chain.append(STATION)
		piece_of.append(-1)
	var pose := station_end(station)
	var ends := []
	var error := ""
	var pieces: Array = ride.get("pieces", [])
	for pi in pieces.size():
		var piece: Array = pieces[pi]
		error = piece_error(pose, piece)
		if error != "":
			break
		var r := piece_points(pose, piece)
		var c := int(piece[2]) if piece.size() > 2 else 0
		for p in r.points:
			pts.append(p)
			chain.append(c)
			piece_of.append(pi)
		pose = r.pose
		ends.append(pose)
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		lengths.append(lengths[i - 1] + pts[i].distance_to(pts[i - 1]))
	return {
		"points": pts,
		"chain": chain,
		"piece_of": piece_of,
		"lengths": lengths,
		"length": lengths[lengths.size() - 1],
		"station_length": float(station.length),
		"end": pose,
		"ends": ends,
		"complete": error == "" and pieces.size() > 0 and same_pose(pose, start),
		"error": error,
	}


## Heights over each tile the given points pass through: {tile: Vector2(min, max)}.
static func tiles_of(points: PackedVector3Array) -> Dictionary:
	var out := {}
	for i in range(1, points.size()):
		var m := (points[i] + points[i - 1]) * 0.5
		var t := Vector2i(floori(m.x), floori(m.z))
		var y := m.y
		if out.has(t):
			var v: Vector2 = out[t]
			out[t] = Vector2(minf(v.x, y), maxf(v.y, y))
		else:
			out[t] = Vector2(y, y)
	return out


## Tile heights of one ride's whole circuit, with the station included.
static func ride_tiles(ride: Dictionary) -> Dictionary:
	var path := build(ride)
	return tiles_of(path.points)


## Point and tangent `s` units along the circuit (wrapping round).
static func sample(path: Dictionary, s: float) -> Array:
	var lengths: PackedFloat32Array = path.lengths
	var pts: PackedVector3Array = path.points
	var total: float = path.length
	if pts.size() < 2 or total <= 0.0:
		return [pts[0] if pts.size() > 0 else Vector3.ZERO, Vector3.FORWARD]
	s = fposmod(s, total)
	var i := lengths.bsearch(s)
	i = clampi(i, 1, pts.size() - 1)
	var seg := lengths[i] - lengths[i - 1]
	var t := 0.0 if seg <= 0.0 else (s - lengths[i - 1]) / seg
	var p := pts[i - 1].lerp(pts[i], t)
	var tan := (pts[i] - pts[i - 1]).normalized()
	return [p, tan]


## Index of the point at or just before `s`.
static func index_at(path: Dictionary, s: float) -> int:
	var lengths: PackedFloat32Array = path.lengths
	return clampi(lengths.bsearch(fposmod(s, path.length)) - 1, 0, lengths.size() - 1)
