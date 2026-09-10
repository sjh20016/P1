extends Node3D

@export var enabled: bool = true
@export var max_effects: int = 8
var flash: float = 0.0
var effect_roots: Array[Node3D] = []
var stop_until: int = 0
var sound: AudioStreamWAV
var audio: AudioStreamPlayer
var manager: DestructionManager
var crack_audio: AudioStreamPlayer

func _ready() -> void:
	add_to_group("impact_vfx")
	manager = get_tree().get_first_node_in_group("destruction_manager")
	manager.destruction_event.connect(play_impact)
	audio = AudioStreamPlayer.new()
	audio.max_polyphony = 4
	add_child(audio)
	sound = preload("res://assets/placeholders/impact.wav")
	audio.stream = sound
	crack_audio=AudioStreamPlayer.new()
	crack_audio.max_polyphony=3
	add_child(crack_audio)
	if DisplayServer.get_name() != "headless":
		call_deferred("warm_particle_shaders")

func warm_particle_shaders() -> void:
	# Compile the two lightweight particle variants behind the start menu.
	# Alpha zero keeps warm-up invisible; no break, score, shake or hit stop occurs.
	var warm := Node3D.new()
	warm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(warm)
	var player := get_tree().get_first_node_in_group("player")
	warm.global_position = player.global_position
	for dust: bool in [false, true]:
		var particles := spawn_particles(warm, Vector3.UP, manager.medium_impact, dust)
		particles.amount = 1
		particles.process_material.color = Color(1,1,1,0)
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 2.0
	warm.add_child(cleanup)
	cleanup.timeout.connect(warm.queue_free)
	cleanup.start()

func _process(delta: float) -> void:
	flash = move_toward(flash, 0.0, delta * 3.5)
	if stop_until > 0 and Time.get_ticks_msec() >= stop_until:
		Engine.time_scale = 1.0
		stop_until = 0

func play_impact(hit: Vector3, direction: Vector3, strength: float) -> void:
	if not enabled:
		return
	var profile:ImpactProfile=manager.impact_profile(strength).duplicate()
	var slash:bool=manager.last_context.get("kind","")=="SLASH"
	if slash:
		profile.hit_stop_duration*=0.38
		profile.camera_shake*=0.32
		profile.flash_opacity*=0.3
		profile.dust_count=6
		profile.sound_volume_db-=4
	flash = maxf(flash, profile.flash_opacity)
	var player := get_tree().get_first_node_in_group("player")
	if player.has_node("CameraShake"):
		player.get_node("CameraShake").kick(profile)
		player.get_node("CameraShake").directional_kick(direction,0.12 if slash else clampf(strength*0.006,0.12,0.4))
	player.camera_rig.impact_pulse=maxf(player.camera_rig.impact_pulse,1.3 if slash else clampf(strength*0.07,1.6,4.5))
	if profile.hit_stop_duration > 0 and stop_until == 0:
		Engine.time_scale = profile.hit_stop_scale
		stop_until = Time.get_ticks_msec() + roundi(profile.hit_stop_duration * 1000)
	audio.volume_db = profile.sound_volume_db
	audio.pitch_scale = clampf(1.2 - strength * 0.005, 0.8, 1.2)
	if DisplayServer.get_name() == "headless":
		return
	audio.play()
	crack_audio.stream=preload("res://assets/placeholders/tentacle_slash.wav") if slash else preload("res://assets/placeholders/impact_crack.wav")
	crack_audio.volume_db=-11 if slash else -13
	crack_audio.play()
	effect_roots = effect_roots.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion())
	while effect_roots.size() >= max_effects:
		var oldest: Node3D = effect_roots.pop_front()
		oldest.queue_free()
	var effect := Node3D.new()
	add_child(effect)
	effect.global_position = hit
	effect_roots.append(effect)
	spawn_particles(effect, direction, profile, false)
	spawn_particles(effect, direction, profile, true)
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 1.8
	effect.add_child(cleanup)
	cleanup.timeout.connect(effect.queue_free)
	cleanup.start()

func spawn_particles(parent: Node3D, direction: Vector3, profile: ImpactProfile, dust: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = profile.dust_count if dust else profile.chip_count
	particles.lifetime = 1.3 if dust else 0.75
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.visibility_aabb = AABB(Vector3(-30,-30,-30), Vector3(60,60,60))
	var process := ParticleProcessMaterial.new()
	process.direction = (direction + Vector3.UP * 0.6).normalized()
	process.spread = 52.0 if manager.last_context.get("kind","")=="BODY" else 95.0
	process.initial_velocity_min = 2.0 if dust else 7.0
	process.initial_velocity_max = profile.particle_speed * (0.4 if dust else 1.0)
	process.gravity = Vector3(0, 1.0 if dust else -25.0, 0)
	process.scale_min = 0.5 if dust else 0.08
	process.scale_max = 1.5 if dust else 0.24
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.04,0.04,0.04,0.20) if dust else Color(0.003,0.003,0.004,1), Color(0.04,0.04,0.04,0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	var mesh: PrimitiveMesh
	if dust:
		var sphere := SphereMesh.new()
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	else:
		mesh = BoxMesh.new()
	mesh.material = material
	particles.draw_pass_1 = mesh
	parent.add_child(particles)
	particles.emitting = true
	return particles

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(audio):
		audio.stop()
