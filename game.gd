extends Node3D

var grabbed_object = null
var grabbed_object_side = 0 # -1 is blue; 1 is green;
var grab_distance = 1
var mouse = Vector2()
const DIST = 1000

var cam_switch = false
var cam_times = Vector2() # .x = start; .y = end;
var cam_pos_start = Vector3()
var cam_pos_end = Vector3()


@onready var cam = $Camera3D

func norm(a: float, b: float, t: float) -> float:
	return (t-a) / (b-a)

func _ready() -> void:
	cam.look_at(Vector3.ZERO)
	var elementals = $Elementals.get_children()
	print(elementals.map(func(elem): return elem.global_position))
	#for elem in elementals:
		#print(elem.global_position)

func _process(_deltatime: float) -> void:
	if grabbed_object:
		grabbed_object.position = get_grab_position()
	
	if cam_switch:
		var t = norm(cam_times.x, cam_times.y, Time.get_ticks_msec())
		if t >= 0 and t <= 1:
			t = t * t * t * (t * (6 * t - 15) + 10)
			var angle = PI/4 + PI * t + PI * (-sign(cam_pos_start.x)/2+0.5)
			var radius = Vector2(cam.global_position.x, cam.global_position.z).length()
			cam.global_position.x = sin(angle) * radius
			cam.global_position.z = cos(angle) * radius
			cam.look_at(Vector3.ZERO)
		else:
			cam_switch = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.global_position
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			update_grabbed_object(mouse)
		if event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			grabbed_object = null
		if event.is_released() and event.button_index == MOUSE_BUTTON_MIDDLE and not cam_switch:
			cam_switch = true
			cam_times.x = Time.get_ticks_msec()
			cam_times.y = Time.get_ticks_msec() + 1000
			cam_pos_start = cam.global_position
			cam_pos_end = cam.global_position; cam_pos_end.x *= -1; cam_pos_end.z *= -1;

func update_grabbed_object(M: Vector2):
	var space = get_world_3d().direct_space_state
	var ray_origin = get_viewport().get_camera_3d().project_ray_origin(M)
	var ray_dir = get_viewport().get_camera_3d().project_position(M, DIST)
	var params = PhysicsRayQueryParameters3D.new()
	params.from = ray_origin
	params.to = ray_dir
	var result = space.intersect_ray(params)
	if !result.is_empty():
		grabbed_object = result.collider
		grabbed_object_side = sign(grabbed_object.global_position.z)

func get_grab_position():
	var ro = get_viewport().get_camera_3d().project_ray_origin(mouse)
	var rd = get_viewport().get_camera_3d().project_position(mouse, DIST)
	var t = (0.375 - ro.y) / rd.y
	var re = ro + rd * t
	
	re.x += 6
	re.z += 6
	re.x = clamp(re.x - fmod(re.x, 1.0) + 0.5, 0.5, 11.5)
	re.z = clamp(re.z - fmod(re.z, 1.0) + 0.5, 0.5, 11.5)
	re.x -= 6
	re.z -= 6
	
	if sign(re.z) != grabbed_object_side:
		re.z = grabbed_object_side * 0.5
	
	return re
