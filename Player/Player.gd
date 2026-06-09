extends CharacterBody3D
class_name Player

@export var base_speed := 6.0
@export var jump_height := 1.2
@export var fall_multiplier := 2.5

@export_category("Hook")
@export var hook_speed := 5.0
@export var reel_speed := 1.0
@export var swing_acceleration := 5.0
@export var attach_length := 10

@export_category("Camera")
@export var mouse_sensitivity: float = 0.00075
@export var bottom_clamp: float = -90.0
@export var top_clamp: float = 90.0

@export_category("Third Person")
@export var min_zoom: float = 1.5
@export var max_zoom: float = 6.0
@export var zoom_sensitivity: float = 0.4

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _look := Vector2.ZERO

enum VIEW {
	FIRST_PERSON,
	THIRD_PERSON_BACK
}

var view := VIEW.FIRST_PERSON:
	set(value):
		view = value
		match view:
			VIEW.FIRST_PERSON:
				camera.fov = get_viewport().get_camera_3d().fov
				camera.current = true
				UserInterface.hide_reticle(false)
			VIEW.THIRD_PERSON_BACK:
				third_person_camera.fov = get_viewport().get_camera_3d().fov
				third_person_camera.current = true
				UserInterface.hide_reticle(true)

var zoom := min_zoom:
	set(value):
		zoom = clamp(value, min_zoom, max_zoom)
		if value < min_zoom:
			view = VIEW.FIRST_PERSON
		elif value > min_zoom:
			view = VIEW.THIRD_PERSON_BACK

@onready var camera: Camera3D = $SmoothCamera
@onready var third_person_camera: Camera3D = %ThirdPersonCamera
@onready var spring_arm_3d: SpringArm3D = %SpringArm3D

@onready var camera_target: Node3D = $CameraTarget
@onready var camera_origin = camera_target.position

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var run_particles: GPUParticles3D = $BasePivot/RunParticles
@onready var jump_particles: GPUParticles3D = $BasePivot/JumpParticles

@onready var jump_audio: AudioStreamPlayer3D = %JumpAudio
@onready var run_audio: AudioStreamPlayer3D = %RunAudio


func _ready() -> void:
	$SmoothCamera/HookCast.target_position.z = -attach_length
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	UserInterface.update_player(self)

var hook_pos := Vector3.ZERO
var hook_len: float
var swinging := false
func _physics_process(delta: float) -> void:
	frame_camera_rotation()
	smooth_camera_zoom(delta)
	if not is_on_floor():
		if velocity.y >= 0 and Input.is_action_pressed("ui_accept"): velocity.y -= gravity * delta
		else: velocity.y -= gravity * delta * fall_multiplier

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = sqrt(jump_height * 2.0 * gravity)
		jump_particles.restart()
		jump_audio.play()
		run_audio.play()

	if $SmoothCamera/HookCast.is_colliding():
		if Input.is_action_just_pressed("click"):
			hook_pos = $SmoothCamera/HookCast.get_collision_point()
			hook_len = global_position.distance_to(hook_pos)
			swinging = true
		UserInterface.hide_can_hook(false)
	else: UserInterface.hide_can_hook(true)

	if Input.is_action_pressed("reel_in"): hook_len -= reel_speed * delta
	if Input.is_action_pressed("reel_out"): hook_len += reel_speed * delta
	if Input.is_action_just_pressed("release"): swinging = false ; hook_pos = Vector3.ZERO
	var direction = get_movement_direction()

	if swinging:
		$HookIndicator.show()
		$HookIndicator.global_position = hook_pos
		var offset = global_position - hook_pos
		var dist = offset.length()
		if dist > hook_len:
			offset = offset.normalized() * hook_len
			global_position = hook_pos + offset
			var rope_dir = offset.normalized()
			var radial_vel = velocity.dot(rope_dir)
			if radial_vel > 0: velocity -= rope_dir * radial_vel
		if is_on_floor():
			if direction:
				velocity.x = lerp(velocity.x, direction.x * base_speed, base_speed * delta)
				velocity.z = lerp(velocity.z, direction.z * base_speed, base_speed * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, base_speed * delta * 5.0)
				velocity.z = move_toward(velocity.z, 0, base_speed * delta * 5.0)

		elif Input.is_action_pressed("move_forward"):
			var rope_dir = (global_position - hook_pos).normalized()
			var forward = -transform.basis.z
			var tangent = (forward - rope_dir * forward.dot(rope_dir)).normalized()
			velocity += tangent * swing_acceleration * delta

	#if Input.is_action_pressed("click"):
		#if $SmoothCamera/HookCast.is_colliding() and hook_pos == Vector3.ZERO: hook_pos = $SmoothCamera/HookCast.get_collision_point()
		#if hook_pos == Vector3.ZERO: return
		#gravity = 0.0
		#global_position = global_position.move_toward(hook_pos, get_process_delta_time() * hook_speed)
	#else:
		#hook_pos = Vector3.ZERO
		#gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	
	else:
		$HookIndicator.hide()
		if direction:
			velocity.x = lerp(velocity.x, direction.x * base_speed, base_speed * delta)
			velocity.z =  lerp(velocity.z, direction.z * base_speed, base_speed * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, base_speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0, base_speed * delta * 5.0)
	
		run_particles.emitting = not direction.is_zero_approx() and is_on_floor()
		
	update_animation_tree()
	move_and_slide()

func get_movement_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func frame_camera_rotation() -> void:
	rotate_y(_look.x)
	camera_target.rotate_x(_look.y)
	camera_target.rotation.x = clamp(camera_target.rotation.x, 
		deg_to_rad(bottom_clamp), 
		deg_to_rad(top_clamp)
	)
	_look = Vector2.ZERO

func update_animation_tree() -> void:
	var movement_direction = basis.inverse() * velocity / base_speed
	var animation_target = Vector2(movement_direction.x, -movement_direction.z)
	animation_tree.set("parameters/blend_position", animation_target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_look = -event.relative * mouse_sensitivity
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	if event.is_action_pressed("toggle_view"): cycle_view()
	if event.is_action_pressed("zoom_in"): zoom -= zoom_sensitivity
	elif event.is_action_pressed("zoom_out"): zoom += zoom_sensitivity

func cycle_view() -> void:
	match view:
		VIEW.FIRST_PERSON:
			view = VIEW.THIRD_PERSON_BACK
			zoom = lerp(min_zoom, max_zoom, 0.5)
		VIEW.THIRD_PERSON_BACK: view = VIEW.FIRST_PERSON
		_: view = VIEW.FIRST_PERSON

func smooth_camera_zoom(delta: float) -> void:
	spring_arm_3d.spring_length = lerp(
		spring_arm_3d.spring_length,
		zoom,
		delta * 10.0
	)

func _on_footstep_timer_timeout() -> void:
	if is_on_floor() and get_movement_direction(): run_audio.play()
