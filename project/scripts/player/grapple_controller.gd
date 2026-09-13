class_name GrappleController
extends Node3D

signal attached
signal released
signal fired(success: bool)
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
var targeting := GrappleTargeting.new()
var selection: Dictionary = {}
var status_text: String = "READY"
var status_time: float = 0.0
var held_time: float = 0.0
var charge: float = 0.0
var release_flash: float = 0.0
var intentional_release: bool = false
# Keep the owner reference at the native body interface. A reciprocal script type
# (RavagePlayer -> GrappleController -> RavagePlayer) survives until GDScript's
# shutdown cycle cleanup in Godot 4.7.2, where script-list iteration can use freed memory.
@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = player.get_node("CameraRig/SpringArm3D/Camera3D")

func _ready() -> void:
	player.reset_performed.connect(release)

func update_input(delta: float) -> void:
	status_time = maxf(0.0,status_time-delta)
	release_flash = maxf(0.0,release_flash-delta)
	cooldown = maxf(0.0, cooldown - delta)
	ray_flash = maxf(0.0, ray_flash - delta)
	if not enabled:
		release()
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed(action) and cooldown <= 0:
			shoot()
		if Input.is_action_just_released(action):
			intentional_release = true
			release()
	if active and is_instance_valid(target) and target.collision_layer == 0 and target.has_method("resolve_grapple"):
		target = target.resolve_grapple(grapple_point)
	if active and (not is_instance_valid(target) or target.collision_layer == 0):
		release()
	if active:
		held_time += delta
		var reel := Input.get_axis("reel_in", "reel_out")
		rest_length = clampf(rest_length + reel * profile.reel_speed * delta, profile.minimum_rope_length, profile.maximum_rope_length)
		charge = clampf(charge+delta*(1.1 if reel<0 and tension>6 else -0.35),0.0,1.0)

func aim_result() -> Dictionary:
	selection = targeting.select(self)
	return selection

func shoot() -> bool:
	var hit := aim_result()
	ray_flash = 0.22
	last_ray_end = camera.global_position - camera.global_basis.z * profile.maximum_rope_length
	if hit.is_empty():
		status_text = targeting.reason
		status_time = 0.9
		fired.emit(false)
		return false
	last_ray_end = hit.position
	var success := attach_to(hit.position, hit.collider)
	fired.emit(success)
	return success

func attach_to(point: Vector3, body: StaticBody3D) -> bool:
	if not enabled or not point.is_finite() or not is_instance_valid(body) or body.collision_layer==0:
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
	held_time = 0.0
	charge = 0.0
	status_text = "ATTACHED"
	status_time = 0.45
	if profile.movement_model==2 and player.kick_cooldown<=0:
		var direction := (point-player.global_position).normalized()
		var kick := maxf(profile.kick_speed-maxf(player.velocity.dot(direction),0.0)*0.3,0.0)*clampf(distance/12.0,0.25,1.0)
		player.velocity = (player.velocity+direction*kick).limit_length(player.profile.max_speed)
		player.kick_cooldown = 0.28
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
	var direction := offset / current_length
	# Motion toward anchor damps the spring. Motion away increases restoring force.
	var spring := maxf(extension*profile.spring_strength-player.velocity.dot(direction)*profile.damping,0.0) if extension>0 else 0.0
	if profile.movement_model==1:
		spring = minf(extension*8.0,profile.maximum_hook_force)
	var motor := profile.motor_acceleration*clampf((current_length-3.0)/12.0,0.0,1.0)
	if Input.is_action_pressed("reel_in"):
		motor *= 1.7
	tension = clampf(spring+motor,0.0,profile.maximum_hook_force)
	return direction * tension

func constrain_velocity(delta: float) -> void:
	if not active or profile.radial_correction<=0 or delta<=0:
		return
	var offset := grapple_point-player.global_position
	var distance := offset.length()
	if distance<0.01:
		return
	var direction := offset/distance
	var allowed_away := maxf(rest_length-distance,0.0)/delta
	var excess := maxf(-player.velocity.dot(direction)-allowed_away,0.0)
	var correction := excess*profile.radial_correction
	player.velocity += direction*correction
	tension = minf(profile.maximum_hook_force,tension+correction/delta)

func release() -> void:
	if active:
		if intentional_release and charge>0.25 and profile.slingshot_boost>0 and player.release_cooldown<=0:
			var launch := player.velocity.normalized()
			if launch.length_squared()<0.1:
				launch = (grapple_point-player.global_position).normalized()
			player.velocity = (player.velocity+launch*profile.slingshot_boost*charge).limit_length(player.profile.max_speed)
			player.release_cooldown = 0.4
			status_text = "SLINGSHOT"
		else:
			status_text = "ZIP" if held_time<0.18 and intentional_release else "RELEASE"
		status_time = 0.6
		release_flash = 0.12
		released.emit()
	intentional_release = false
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
