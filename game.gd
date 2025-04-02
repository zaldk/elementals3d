extends Node3D

var mouse = Vector2()
const DIST = 1000

var has_grabbed = false
var grabbed_object = null
var grabbed_object_side = 0 # -1 is blue; 1 is green;
var grab_distance = 1
var grabbed_object_copy = null
var grabbed_object_origin = Vector3()
var elemental_base = preload("res://elemental_base.tscn")

var cam_switch = false
var cam_time = 0
@export var cam_delta = 1000
var cam_pos = Vector3()

@onready var elementals = $Elementals
@onready var cam = $Camera3D

func norm(a: float, b: float, t: float) -> float:
	return (t-a) / (b-a)

func _ready() -> void:
	cam.look_at(Vector3.ZERO)
	#var elementals = $Elementals.get_children()
	#print(elementals.map(func(elem): return elem.global_position))
	##for elem in elementals:
		##print(elem.global_position)

func _process(_deltatime: float) -> void:
	if is_instance_valid(grabbed_object_copy):
		grabbed_object_copy.position = get_grab_position() - grabbed_object_origin
	
	if cam_switch:
		var t = norm(cam_time, cam_time + cam_delta, Time.get_ticks_msec())
		if t >= 0 and t <= 1:
			t = t * t * t * (t * (6 * t - 15) + 10)
			var angle = PI/4 + PI * t + PI * (-sign(cam_pos.x)/2+0.5)
			var radius = Vector2(cam.global_position.x, cam.global_position.z).length()
			cam.global_position.x = sin(angle) * radius
			cam.global_position.z = cos(angle) * radius
			cam.look_at(Vector3.ZERO)
		else:
			cam_switch = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse = event.global_position
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if !has_grabbed: update_grabbed_object(mouse)
				if has_grabbed:
					if is_instance_valid(grabbed_object_copy):
						grabbed_object.global_position = grabbed_object_copy.global_position
						grabbed_object_copy.free()
					grabbed_object = null
				has_grabbed = !has_grabbed
			MOUSE_BUTTON_MIDDLE:
				if !cam_switch:
					cam_switch = true
					cam_time = Time.get_ticks_msec()
					cam_pos = cam.global_position
	if event is InputEventKey and event.is_pressed():
		match event.keycode:
			KEY_Q:
				var new_elemental = elemental_base.instantiate()
				elementals.add_child(new_elemental)
				new_elemental.global_position = get_grab_position()
		

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
		grabbed_object_copy = grabbed_object.duplicate()
		grabbed_object.add_child(grabbed_object_copy)
		grabbed_object_origin = grabbed_object.global_position

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
