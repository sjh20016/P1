extends Node

var amplitude: float = 0.0
var remaining: float = 0.0
var duration: float = 0.25
@onready var camera: Camera3D = get_parent().get_node("CameraRig/SpringArm3D/Camera3D")

func kick(profile: ImpactProfile) -> void:
	amplitude = maxf(amplitude, profile.camera_shake)
	remaining = profile.shake_duration
	duration = remaining

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var weight := remaining / maxf(duration, 0.01)
	var time := Time.get_ticks_msec() * 0.001
	camera.h_offset = sin(time * 91.0) * amplitude * weight * weight
	camera.v_offset = cos(time * 73.0) * amplitude * weight * weight
	if remaining == 0:
		amplitude = 0
