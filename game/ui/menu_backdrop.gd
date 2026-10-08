class_name MenuBackdrop
extends Node3D
## Behind the menus: the sample park, open and busy, with the camera
## drifting slowly round it.

var sim: ParkSim
var view: ParkView
var _cam: ParkCamera


func _ready() -> void:
	var p := ParkData.create("Backdrop", "meadow", true, 11)
	SamplePark.build(p)
	sim = ParkSim.new(p, 5)
	# A minute of play first, so there's a crowd.
	for i in 900:
		sim.step(0.1)
	view = ParkView.new()
	add_child(view)
	view.setup(p, sim)
	_cam = ParkCamera.new()
	_cam.focus = Vector3(14, 0, 17)
	_cam.distance = 22.0
	_cam.pitch = deg_to_rad(38.0)
	add_child(_cam)
	_cam.snap()


func _process(delta: float) -> void:
	sim.step(delta)
	_cam.orbit(delta * 0.05, 0.0)
