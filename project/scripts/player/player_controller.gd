class_name RavagePlayer
extends CharacterBody3D

signal reset_performed
@export var profile: MovementProfile = preload("res://assets/placeholders/movement.tres")
@export var spawn_position: Vector3 = Vector3(0, 43, 18)
@onready var camera_rig: Node3D = $CameraRig
var controls_enabled: bool = true
var external_acceleration: Vector3 = Vector3.ZERO
var previous_position: Vector3
var peak_speed: float = 0.0
var hooks: Array[GrappleController] = []

func _ready() -> void:
	add_to_group("player")
	for child in get_children():
		if child is GrappleController:
			hooks.append(child)
	reset_player()

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		return
	if Input.is_action_just_pressed("reset"):
		reset_player()
		return
	previous_position = global_position
	var hook_acceleration := Vector3.ZERO
	for hook in hooks:
		hook.update_input(delta)
		hook_acceleration += hook.acceleration()
	if not hooks.is_empty():
		hook_acceleration = hook_acceleration.limit_length(hooks[0].profile.maximum_combined_force)
	velocity += hook_acceleration * delta
	var axis := Input.get_vector("left", "right", "forward", "back")
	var direction: Vector3 = Basis(Vector3.UP, camera_rig.rotation.y) * Vector3(axis.x, 0, axis.y)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, direction.x * profile.ground_speed, profile.ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * profile.ground_speed, profile.ground_acceleration * delta)
		if Input.is_action_just_pressed("jump"):
			velocity.y = profile.jump_speed
	else:
		velocity += direction * profile.air_control * delta
	velocity.y -= profile.gravity * delta
	velocity += external_acceleration * delta
	external_acceleration = Vector3.ZERO
	velocity *= exp(-profile.air_drag * delta)
	if not velocity.is_finite():
		reset_player()
		return
	velocity = velocity.limit_length(profile.max_speed)
	peak_speed = maxf(peak_speed, velocity.length())
	move_and_slide()
	if global_position.y < profile.reset_depth or not global_position.is_finite():
		reset_player()

func reset_player() -> void:
	velocity = Vector3.ZERO
	external_acceleration = Vector3.ZERO
	global_position = spawn_position
	previous_position = spawn_position
	reset_performed.emit()
