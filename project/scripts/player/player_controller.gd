class_name RavagePlayer
extends CharacterBody3D

signal reset_performed
signal motion_requested(motion: Vector3, incoming_velocity: Vector3)
signal motion_completed(delta: float)
signal fall_recovered
signal wall_launched
@export var profile: MovementProfile = preload("res://assets/placeholders/movement.tres")
@export var spawn_position: Vector3 = Vector3(0, 43, 18)
@export var fall_recovery_enabled: bool = false
@export var danger_depth: float = -90.0
@export var hard_fall_limit: float = -800.0
@export var wall_experiment: bool = false
@onready var camera_rig: Node3D = $CameraRig
var controls_enabled: bool = true
var external_acceleration: Vector3 = Vector3.ZERO
var previous_position: Vector3
var peak_speed: float = 0.0
var hooks: Array[GrappleController] = []
var kick_cooldown: float = 0.0
var release_cooldown: float = 0.0
var fall_grace: bool = false
var fall_clock: float = 0.0
var rescue_clock: float = 0.0
var rescue_available: bool = true
var recovered_episode: bool = false
var reset_reason: String = "initial"
var wall_normal := Vector3.ZERO
var wall_age: float = 10.0
var adhesion_time: float = 0.0

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
		reset_player("manual")
		return
	kick_cooldown = maxf(0.0,kick_cooldown-delta)
	release_cooldown = maxf(0.0,release_cooldown-delta)
	wall_age += delta
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
	if wall_experiment and not is_on_floor() and wall_age<0.15:
		if Input.is_action_just_pressed("jump"):
			perform_wall_launch()
		elif Input.is_action_pressed("wall_hold") and velocity.length()<18 and adhesion_time<0.45:
			velocity = velocity.slide(wall_normal)*exp(-12.0*delta)-wall_normal*2.0
			velocity.y = maxf(velocity.y,-1.5)
			adhesion_time += delta
	else:
		adhesion_time=0
	velocity += external_acceleration * delta
	external_acceleration = Vector3.ZERO
	velocity *= exp(-profile.air_drag * delta)
	if not velocity.is_finite():
		reset_player("invalid_velocity")
		return
	for hook in hooks:
		hook.constrain_velocity(delta)
	velocity = velocity.limit_length(profile.max_speed)
	peak_speed = maxf(peak_speed, velocity.length())
	motion_requested.emit(velocity * delta, velocity)
	move_and_slide()
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if absf(normal.y)<0.3:
			wall_normal=normal
			wall_age=0
	motion_completed.emit(delta)
	update_fall_recovery(delta)

func update_fall_recovery(delta: float) -> void:
	if not global_position.is_finite():
		reset_player("invalid_position")
		return
	if not fall_recovery_enabled:
		if global_position.y < profile.reset_depth:
			reset_player("void")
		return
	if global_position.y > danger_depth+25:
		fall_grace=false
		fall_clock=0
		recovered_episode=false
	if global_position.y < danger_depth:
		fall_grace=true
	if not fall_grace:
		return
	fall_clock += delta
	rescue_clock -= delta
	if rescue_clock<=0:
		rescue_clock=0.3
		rescue_available=has_rescue_surface()
	if not recovered_episode and velocity.y>4.0:
		for hook in hooks:
			if hook.active:
				recovered_episode=true
				fall_recovered.emit()
				break
	var anchored:=false
	for hook in hooks:
		if hook.active and is_instance_valid(hook.target) and hook.target.collision_layer!=0:
			anchored=true
	if global_position.y<hard_fall_limit or (fall_clock>4.0 and not rescue_available and not anchored and velocity.y<=0):
		reset_player("unrecoverable_fall")

func has_rescue_surface() -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 180.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY,global_position)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func perform_wall_launch() -> void:
	var facing := -camera_rig.global_basis.z
	var along := facing.slide(wall_normal).normalized()
	velocity = (wall_normal*23.0+along*14.0+Vector3.UP*19.0).limit_length(profile.max_speed)
	wall_age=10.0
	adhesion_time=0.45
	wall_launched.emit()

func reset_player(reason: String = "manual") -> void:
	reset_reason=reason
	velocity = Vector3.ZERO
	external_acceleration = Vector3.ZERO
	global_position = spawn_position
	previous_position = spawn_position
	fall_grace=false
	fall_clock=0
	rescue_clock=0
	recovered_episode=false
	wall_age=10
	adhesion_time=0
	kick_cooldown=0
	release_cooldown=0
	reset_performed.emit()
