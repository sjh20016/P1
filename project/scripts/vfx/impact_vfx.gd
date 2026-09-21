extends Node3D

@export var enabled: bool = true
@export var max_effects: int = 8
var flash: float = 0.0
var effect_roots: Array[Node3D] = []
var stop_until: int = 0
var sound: AudioStreamWAV
var audio: AudioStreamPlayer3D
var manager: DestructionManager
var crack_audio: AudioStreamPlayer3D
var beat_context:Dictionary={}
var next_stop_ms:int=0
var stop_enabled:bool=true

func _ready() -> void:
	add_to_group("impact_vfx")
	manager = get_tree().get_first_node_in_group("destruction_manager")
	manager.feedback_beat.connect(play_feedback)
	audio = AudioStreamPlayer3D.new()
	audio.max_polyphony = 2
	audio.unit_size=24.0
	audio.max_distance=150.0
	add_child(audio)
	sound = preload("res://assets/placeholders/impact.wav")
	audio.stream = sound
	crack_audio=AudioStreamPlayer3D.new()
	crack_audio.max_polyphony=2
	crack_audio.unit_size=20.0
	crack_audio.max_distance=130.0
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

func play_feedback(context:Dictionary) -> void:
	beat_context=context
	play_impact(context.position,context.direction,context.strength)

func play_impact(hit: Vector3, direction: Vector3, strength: float) -> void:
	if not enabled:
		return
	var profile:ImpactProfile=manager.impact_profile(strength).duplicate()
	var slash:bool=beat_context.get("kind","")=="SLASH"
	var collapse:bool=beat_context.get("kind","")=="COLLAPSE"
	var pull:bool=beat_context.get("kind","")=="PULL"
	var clash:bool=beat_context.get("dual_clash",false)
	profile.camera_shake=minf(profile.camera_shake,0.22)
	profile.shake_duration=0.16
	profile.flash_opacity=minf(profile.flash_opacity,0.10)
	if strength<42: profile.hit_stop_duration=0
	if slash:
		profile.hit_stop_duration=0
		profile.camera_shake*=0.32
		profile.flash_opacity*=0.3
		profile.dust_count=8
		profile.chip_count=18
		profile.sound_volume_db-=4
	if beat_context.get("asset_fracture",false):
		profile.dust_count = 20 if beat_context.get("bond_broken",false) else 12
		profile.chip_count = 26
		profile.hit_stop_duration = 0
		profile.camera_shake = .12 if beat_context.get("bond_broken",false) else .06
		profile.flash_opacity = .025
	if collapse:
		# The world keeps falling while the player flies; secondary contacts never retrigger global hit stop.
		profile.hit_stop_duration=0
		profile.camera_shake*=0.3
		profile.flash_opacity=0
		profile.dust_count=10
	if pull:
		profile.hit_stop_duration=0;profile.camera_shake*=0.45
		profile.flash_opacity=0;profile.chip_count=12;profile.dust_count=8
	if clash:
		profile.camera_shake=0.2;profile.chip_count=48;profile.dust_count=18
		profile.flash_opacity=0.06
	var player := get_tree().get_first_node_in_group("player")
	var proximity:=clampf(1.0-player.global_position.distance_to(hit)/85.0,0.0,1.0)
	flash = maxf(flash, profile.flash_opacity*proximity)
	profile.camera_shake*=proximity
	if player.has_node("CameraShake"):
		player.get_node("CameraShake").kick(profile)
		player.get_node("CameraShake").directional_kick(direction,proximity*(0.04 if pull else (0.06 if collapse else (0.05 if slash else clampf(strength*0.003,0.08,0.20)))))
	player.camera_rig.impact_pulse=maxf(player.camera_rig.impact_pulse,proximity*(1.3 if slash else clampf(strength*0.07,1.6,4.5)))
	if stop_enabled and proximity>0.65 and profile.hit_stop_duration > 0 and stop_until == 0 and Time.get_ticks_msec()>=next_stop_ms:
		Engine.time_scale = 0.28
		stop_until = Time.get_ticks_msec() + 36
		next_stop_ms=Time.get_ticks_msec()+650
	audio.global_position=hit
	crack_audio.global_position=hit
	audio.volume_db = profile.sound_volume_db
	audio.stream=preload("res://assets/placeholders/impact.wav")
	audio.pitch_scale = 0.48 if clash else (0.56 if collapse else (0.68 if pull else (1.25 if slash else clampf(1.08-strength*0.004,0.72,1.0))))
	if DisplayServer.get_name() == "headless":
		return
	if not beat_context.get("asset_fracture",false): audio.play()
	crack_audio.stream=preload("res://assets/placeholders/tentacle_slash.wav") if slash else preload("res://assets/placeholders/impact_crack.wav")
	crack_audio.volume_db=-7 if slash else -9
	crack_audio.pitch_scale=0.62 if beat_context.get("asset_fracture",false) else (0.55 if pull else (0.65 if collapse else (1.12 if slash else 0.85)))
	if not beat_context.get("asset_fracture",false): crack_audio.play()
	effect_roots = effect_roots.filter(func(v): return is_instance_valid(v) and not v.is_queued_for_deletion())
	while effect_roots.size() >= max_effects:
		var oldest: Node3D = effect_roots.pop_front()
		oldest.queue_free()
	var effect := Node3D.new()
	add_child(effect)
	effect.global_position = hit
	effect_roots.append(effect)
	if not slash and not pull: spawn_ring(effect,beat_context.get("normal",-direction),strength)
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
	process.spread = 42.0 if beat_context.get("kind","")=="BODY" else 75.0
	if beat_context.get("kind","")=="PULL":
		process.direction=Vector3.UP;process.spread=20
	process.initial_velocity_min = 2.0 if dust else 7.0
	process.initial_velocity_max = profile.particle_speed * (0.4 if dust else 1.0)
	process.gravity = Vector3(0, 1.0 if dust else -25.0, 0)
	process.scale_min = 0.5 if dust else 0.08
	process.scale_max = 1.5 if dust else 0.24
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02,0.02,0.02,0.32) if dust else Color(0.58,0.57,0.54,1), Color(0.04,0.04,0.04,0)])
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

func spawn_ring(parent:Node3D,normal:Vector3,strength:float) -> void:
	var ring:=MeshInstance3D.new()
	var mesh:=TorusMesh.new();mesh.inner_radius=0.92;mesh.outer_radius=1.0;mesh.rings=24;mesh.ring_segments=6
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(0.02,0.02,0.02,0.55)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material=material;ring.mesh=mesh;parent.add_child(ring)
	var n:=normal.normalized()
	if n.length_squared()<0.1: n=Vector3.BACK
	ring.quaternion=Quaternion(Vector3.UP,n)
	ring.position=n*0.12
	var size:=clampf(strength/10.0,4.0,9.0) if beat_context.get("dual_clash",false) else clampf(strength/13.0,2.0,5.5)
	var tween:=create_tween().set_parallel()
	tween.tween_property(ring,"scale",Vector3.ONE*size,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,0.20)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(audio):
		audio.stop()
