class_name ParkCamera
extends Node3D
## The park camera: it orbits a point on the ground, tilts and zooms.
## The game moves `focus`; the camera eases after it.

const MIN_DIST := 5.0
const MAX_DIST := 48.0
const MIN_PITCH := deg_to_rad(28.0)
const MAX_PITCH := deg_to_rad(82.0)

var focus := Vector3.ZERO
var yaw := deg_to_rad(35.0)
var pitch := deg_to_rad(50.0)
var distance := 18.0
## Keeps the focus inside this rectangle (the park and a little round it).
var bounds := Rect2(-4, -4, 44, 44)
var camera: Camera3D
var _shown_focus := Vector3.ZERO
var _shown_distance := 18.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 400.0
	add_child(camera)
	_shown_focus = focus
	_shown_distance = distance
	_place()


func snap() -> void:
	_shown_focus = focus
	_shown_distance = distance
	_place()


func orbit(d_yaw: float, d_pitch: float) -> void:
	yaw = wrapf(yaw + d_yaw, -PI, PI)
	pitch = clampf(pitch + d_pitch, MIN_PITCH, MAX_PITCH)


func zoom(factor: float) -> void:
	distance = clampf(distance * factor, MIN_DIST, MAX_DIST)


## Moves the focus by `v` in screen terms: x to the right, y up the screen.
func pan(v: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var ahead := Vector3(-sin(yaw), 0, -cos(yaw))
	focus += right * v.x + ahead * v.y
	_clamp()


## Turns a stick or key direction (x right, y down the screen) into a
## direction on the ground, so "up" always moves away from the camera.
func screen_to_ground(v: Vector2) -> Vector2:
	var right := Vector2(cos(yaw), -sin(yaw))
	var ahead := Vector2(-sin(yaw), -cos(yaw))
	return right * v.x - ahead * v.y


## The nearest of the four headings (Track.DIRS index) to the screen's "up".
func heading_up() -> int:
	var ahead := Vector2(-sin(yaw), -cos(yaw))
	var best := 0
	var bd := -2.0
	for d in 4:
		var v := Vector2(Track.DIRS[d])
		if v.dot(ahead) > bd:
			bd = v.dot(ahead)
			best = d
	return best


func _clamp() -> void:
	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 10.0)
	_shown_focus = _shown_focus.lerp(focus, k)
	_shown_distance = lerpf(_shown_distance, distance, k)
	_place()


func _place() -> void:
	if camera == null:
		return
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.global_transform = Transform3D(Basis(), _shown_focus + back * _shown_distance).looking_at(_shown_focus, Vector3.UP)


## Where a screen point lands on the ground (y = 0), or null.
func ground_at(screen: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t
