extends Node

var player: RavagePlayer
var portals: PortalManager
var pulse: float = 0
var stabilization: float = 0
var target_angles := Vector2.ZERO
var wind: AudioStreamPlayer

func _ready() -> void:
	portals.traversed.connect(on_traverse)
	player.reset_performed.connect(func(): pulse = 0; stabilization = 0)
	player.camera_rig.set_process(false)
	wind = AudioStreamPlayer.new(); add_child(wind)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 22050
	var data := PackedByteArray(); data.resize(22050 * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 725
	var value: float = 0
	for i in 22050:
		value = lerpf(value, rng.randf_range(-1, 1), 0.2)
		data.encode_s16(i * 2, int(value * 9000))
	wav.data = data; wav.loop_mode = AudioStreamWAV.LOOP_FORWARD; wav.loop_end = 22050
	wind.stream = wav; wind.volume_db = -60
	if DisplayServer.get_name() != "headless": wind.play()

func on_traverse(body: Node3D, rotation: Basis, _speed: float) -> void:
	if body != player: return
	var facing: Vector3 = rotation * -player.camera_rig.global_basis.z
	target_angles = Vector2(clampf(asin(clampf(facing.y, -1, 1)), -1.2, 1.2), atan2(-facing.x, -facing.z))
	player.camera_rig.rotation.y = target_angles.y
	player.camera_rig.rotation.x = target_angles.x
	# The old third-person boom would briefly put the camera inside the exit wall.
	player.camera_rig.get_node("SpringArm3D").spring_length = 0.0
	player.camera_rig.camera.position = Vector3.ZERO
	pulse = 1; stabilization = portals.profile.exit_camera_stabilization

func _process(delta: float) -> void:
	pulse = move_toward(pulse, 0, delta * 4)
	if stabilization > 0:
		stabilization -= delta
		player.camera_rig.rotation.x = lerp_angle(player.camera_rig.rotation.x, target_angles.x, 1 - exp(-delta / maxf(0.001, portals.profile.camera_blend)))
	var arm: SpringArm3D = player.camera_rig.get_node("SpringArm3D")
	arm.spring_length = lerpf(arm.spring_length, 7.2, 1 - exp(-delta / maxf(0.001, portals.profile.camera_blend)))
	var camera: Camera3D = player.camera_rig.camera
	var base := lerpf(76, portals.profile.high_speed_fov, clampf(player.velocity.length() / 90, 0, 1))
	camera.fov = lerpf(camera.fov, base + pulse * portals.profile.fov_boost, 1 - exp(-14 * delta))
	wind.volume_db = lerpf(-60, -17, clampf((player.velocity.length() - 15) / 70, 0, 1))
	wind.stream_paused = not player.controls_enabled

func _exit_tree() -> void:
	if is_instance_valid(wind):
		wind.stop(); wind.stream = null
