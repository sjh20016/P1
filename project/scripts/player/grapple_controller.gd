class_name GrappleController
extends Node3D

signal attached
signal released
@export var profile: GrappleProfile = preload("res://assets/placeholders/grapple.tres")
@export var action: StringName = &"hook_left"
@export var enabled: bool = true
@export var tint: Color = Color(0.55, 0.94, 0.8)
var active: bool = false
var grapple_point: Vector3 = Vector3.ZERO
var rest_length: float = 0.0
var tension: float = 0.0
var current_length: float = 0.0
var cooldown: float = 0.0
var target: StaticBody3D
var previous_start: Vector3
var previous_end: Vector3
var history_valid: bool = false
var last_ray_end: Vector3
var ray_flash: float = 0.0
var debug_previous_start: Vector3
var debug_previous_end: Vector3
@onready var player: RavagePlayer = get_parent()
@onready var camera: Camera3D = player.get_node("CameraRig/SpringArm3D/Camera3D")

func _ready() -> void:
	player.reset_performed.connect(release)

func update_input(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	ray_flash = maxf(0.0, ray_flash - delta)
	if not enabled:
		release()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed(action) and cooldown <= 0:
			shoot()
		if Input.is_action_just_released(action):
			release()
	if active and is_instance_valid(target) and target.collision_layer == 0 and target.has_method("resolve_grapple"):
		target = target.resolve_grapple(grapple_point)
	if active and (not is_instance_valid(target) or target.collision_layer == 0):
		release()
	if active:
		var reel := Input.get_axis("reel_in", "reel_out")
		rest_length = clampf(rest_length + reel * profile.reel_speed * delta, profile.minimum_rope_length, profile.maximum_rope_length)

func aim_result() -> Dictionary:
	var start := camera.global_position
	var end := start - camera.global_basis.z * profile.maximum_rope_length
	var query := PhysicsRayQueryParameters3D.create(start, end, 3, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func shoot() -> bool:
	var hit := aim_result()
	ray_flash = 0.22
	last_ray_end = camera.global_position - camera.global_basis.z * profile.maximum_rope_length
	if hit.is_empty() or not hit.collider is StaticBody3D:
		return false
	last_ray_end = hit.position
	# Camera cannot hook through a wall that blocks the player's hand.
	var sight := PhysicsRayQueryParameters3D.create(player.global_position, hit.position, 3, [player.get_rid()])
	var obstruction := get_world_3d().direct_space_state.intersect_ray(sight)
	if not obstruction.is_empty() and obstruction.collider != hit.collider:
		return false
	return attach_to(hit.position, hit.collider)

func attach_to(point: Vector3, body: StaticBody3D) -> bool:
	if not enabled or not point.is_finite() or not is_instance_valid(body):
		return false
	var distance := player.global_position.distance_to(point)
	if distance > profile.maximum_rope_length or distance < 0.5:
		return false
	grapple_point = point
	target = body
	rest_length = clampf(distance * profile.rest_ratio, profile.minimum_rope_length, profile.maximum_rope_length)
	active = true
	tension = 0.0
	history_valid = false
	attached.emit()
	return true

func acceleration() -> Vector3:
	tension = 0.0
	if not active:
		return Vector3.ZERO
	var offset := grapple_point - player.global_position
	current_length = offset.length()
	if current_length < 0.01 or not is_finite(current_length):
		return Vector3.ZERO
	var extension := maxf(current_length - rest_length, 0.0)
	if extension <= 0.0:
		return Vector3.ZERO
	var direction := offset / current_length
	# Motion toward anchor damps the spring. Motion away increases restoring force.
	tension = clampf(extension * profile.spring_strength - player.velocity.dot(direction) * profile.damping, 0.0, profile.maximum_hook_force)
	return direction * tension

func release() -> void:
	if active:
		released.emit()
	active = false
	tension = 0.0
	target = null
	history_valid = false
	cooldown = profile.reattach_cooldown

func remember_segment() -> void:
	debug_previous_start = previous_start
	debug_previous_end = previous_end
	previous_start = player.global_position
	previous_end = grapple_point
	history_valid = active
