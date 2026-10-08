class_name RidePhysics
extends RefCounted
## Runs a train round a finished circuit and rates the ride. The train is a
## point moving along the track: gravity, rolling friction and air drag act
## on it, chain lifts pull it up at a steady speed, and the station's tyres
## push it out and brake it on the way back in.
##
## One tile is TILE_METRES, so speeds and forces come out in real units.

const TILE_METRES := 2.4
const G := 9.81 / TILE_METRES
const CHAIN_SPEED := 1.4
const STATION_SPEED := 1.0
const BRAKE_SPEED := 2.2
## Turns bank by themselves, up to this far, to take the sideways push away.
const MAX_BANK := deg_to_rad(70.0)
const FRICTION := 0.012
const DRAG := 0.0025
## Over this many g the ride is too much for anyone.
const MAX_SAFE_VG := 5.5
const MAX_SAFE_LAT := 2.2
## Riders feel curves this many times wider than they're drawn: the little
## Kenney tracks are far tighter than a real coaster's.
const CURVE_SCALE := 3.0
## Window for smoothing forces, in track units.
const FORCE_WINDOW := 1.2


static func kmh(units_per_second: float) -> float:
	return units_per_second * TILE_METRES * 3.6


## Speeds at every point, how long a lap takes, the forces riders feel and
## the ratings. "ok" is false (with "error") when the train can't finish.
static func simulate(path: Dictionary) -> Dictionary:
	var pts: PackedVector3Array = path.points
	var lengths: PackedFloat32Array = path.lengths
	var chain: PackedByteArray = path.chain
	var n := pts.size()
	var out := {"ok": false, "error": "", "speeds": PackedFloat32Array()}
	if not path.complete or n < 3:
		out.error = "The track doesn't make it back to the station yet"
		return out
	var v := STATION_SPEED
	var speeds := PackedFloat32Array([v])
	var duration := 0.0
	for i in range(1, n):
		var ds := lengths[i] - lengths[i - 1]
		var dy := pts[i].y - pts[i - 1].y
		var v2 := v * v - 2.0 * G * dy - 2.0 * FRICTION * G * ds - 2.0 * DRAG * v * v * ds
		var powered := chain[i]
		if powered == Track.STATION:
			# Station tyres: speed up to, or brake down to, station speed.
			v2 = STATION_SPEED * STATION_SPEED
		elif powered == Track.LIFT and v2 < CHAIN_SPEED * CHAIN_SPEED:
			v2 = CHAIN_SPEED * CHAIN_SPEED
		elif powered == Track.BRAKES and v2 > BRAKE_SPEED * BRAKE_SPEED:
			v2 = BRAKE_SPEED * BRAKE_SPEED
		if v2 <= 0.0001:
			out.error = "The train can't make it over a hill. Add a chain lift or a bigger drop before it"
			out.stall_index = i
			return out
		var nv := sqrt(v2)
		duration += ds / maxf(0.05, (v + nv) * 0.5)
		v = nv
		speeds.append(v)
	out.speeds = speeds
	out.duration = duration
	out.ok = true
	_forces(path, speeds, out)
	_rate(path, speeds, out)
	return out


static func _forces(path: Dictionary, speeds: PackedFloat32Array, out: Dictionary) -> void:
	var pts: PackedVector3Array = path.points
	var lengths: PackedFloat32Array = path.lengths
	var n := pts.size()
	var max_vg := 1.0
	var min_vg := 1.0
	var max_lat := 0.0
	var air := 0.0
	var lat_sum := 0.0
	var banks := PackedFloat32Array()
	banks.resize(n)
	# Points about FORCE_WINDOW apart either side, for a smooth curvature.
	var k := maxi(1, int(FORCE_WINDOW / Track.SAMPLE_STEP))
	for i in n:
		var a := pts[posmod(i - k, n - 1)] if i - k < 0 else pts[i - k]
		var b := pts[(i + k) % (n - 1)] if i + k >= n else pts[i + k]
		var ta := (pts[i] - a).normalized()
		var tb := (b - pts[i]).normalized()
		var span := a.distance_to(pts[i]) + pts[i].distance_to(b)
		if span <= 0.0:
			continue
		var kappa := (tb - ta) / (span * 0.5) / CURVE_SCALE
		var tan := (b - a).normalized()
		var v := speeds[i]
		var felt := kappa * v * v + Vector3(0, G, 0)
		var up := (Vector3.UP - tan * tan.dot(Vector3.UP))
		if up.length() < 0.001:
			continue
		up = up.normalized()
		var side := tan.cross(up).normalized()
		var vg := felt.dot(up) / G
		var lat := felt.dot(side) / G
		# Bank into the turn: the push riders feel tips towards their seats.
		var bank := clampf(atan2(lat, maxf(vg, 0.1)), -MAX_BANK, MAX_BANK)
		banks[i] = bank
		var vg_b := vg * cos(bank) + lat * sin(bank)
		lat = absf(lat * cos(bank) - vg * sin(bank))
		vg = vg_b
		max_vg = maxf(max_vg, vg)
		min_vg = minf(min_vg, vg)
		max_lat = maxf(max_lat, lat)
		var ds := lengths[i] - lengths[i - 1] if i > 0 else 0.0
		if vg < 0.35 and v > 0.0:
			air += ds / v
		lat_sum += lat * ds
	out.banks = banks
	out.max_vg = max_vg
	out.min_vg = min_vg
	out.max_lat = max_lat
	out.air_time = air
	out.lat_sum = lat_sum


static func _rate(path: Dictionary, speeds: PackedFloat32Array, out: Dictionary) -> void:
	var pts: PackedVector3Array = path.points
	var max_v := 0.0
	for v in speeds:
		max_v = maxf(max_v, v)
	# Drops: each fall from a local peak to the next low point.
	var drops := 0
	var biggest := 0.0
	var peak := pts[0].y
	var low := pts[0].y
	var falling := false
	for i in range(1, pts.size()):
		var y := pts[i].y
		if y < pts[i - 1].y - 0.0001:
			if not falling:
				peak = pts[i - 1].y
				falling = true
			low = y
		elif y > pts[i - 1].y + 0.0001 and falling:
			falling = false
			if peak - low >= 0.5:
				drops += 1
				biggest = maxf(biggest, peak - low)
	if falling and peak - low >= 0.5:
		drops += 1
		biggest = maxf(biggest, peak - low)
	var highest := 0.0
	for p in pts:
		highest = maxf(highest, p.y)
	# How much the ride swings riders round, in radians.
	var turning := 0.0
	for i in range(2, pts.size()):
		var a := Vector2(pts[i - 1].x - pts[i - 2].x, pts[i - 1].z - pts[i - 2].z)
		var b := Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z)
		if a.length() > 0.0001 and b.length() > 0.0001:
			turning += absf(a.angle_to(b))
	var speed := kmh(max_v)
	var length_m: float = path.length * TILE_METRES
	var air: float = out.air_time
	var excitement := 0.6 + speed / 22.0 + 0.3 * mini(drops, 8) + biggest * 0.12 + air * 0.9 + minf(length_m, 600.0) / 220.0
	var intensity: float = 0.6 + speed / 22.0 + maxf(0.0, out.max_vg - 1.0) * 1.5 + out.max_lat * 3.0 + maxf(0.0, 0.5 - out.min_vg) * 2.5
	var nausea: float = 0.3 + out.max_lat * 2.2 + out.lat_sum / 60.0 + air * 0.4 + turning / 8.0
	if intensity > 9.0:
		excitement -= (intensity - 9.0) * 0.8
	out.max_speed = max_v
	out.max_speed_kmh = speed
	out.length_m = length_m
	out.drops = drops
	out.biggest_drop_m = biggest * TILE_METRES
	out.highest_m = highest * TILE_METRES
	out.excitement = clampf(excitement, 0.0, 10.0)
	out.intensity = clampf(intensity, 0.0, 12.0)
	out.nausea = clampf(nausea, 0.0, 10.0)
	out.too_intense = out.max_vg > MAX_SAFE_VG or out.max_lat > MAX_SAFE_LAT


## A word for a rating, as guests and the ride window describe it.
static func describe(value: float) -> String:
	if value < 2.0:
		return "Low"
	if value < 4.0:
		return "Medium"
	if value < 6.0:
		return "High"
	if value < 8.0:
		return "Very high"
	return "Extreme"
