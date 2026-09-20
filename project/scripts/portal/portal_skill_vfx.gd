class_name PortalSkillVFX
extends Node3D

# Bounded, non-physical geometry. World effects never contribute damage/hitstop.
const LIMIT := 96
var player: RavagePlayer
var character: PortalCharacter
var magic: PortalMagic
var presentation: PortalPresentation
var effects: Array[Dictionary] = []
var materials: Array[StandardMaterial3D] = []
var shard_mesh: PrismMesh
var ring_mesh: TorusMesh
var orbit: Array[MeshInstance3D] = []
var clock := 0.0
var emission_left := 0.0
var spawned := 0
var peak := 0
var sounds: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for color in [Color(0.015,0.02,0.032),Color(0.91,0.95,0.99),Color(0.35,0.42,0.51)]:
		var mat := StandardMaterial3D.new(); mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(mat)
	shard_mesh = PrismMesh.new(); shard_mesh.size = Vector3(0.12,0.26,0.065)
	ring_mesh = TorusMesh.new(); ring_mesh.inner_radius = 0.94; ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32; ring_mesh.ring_segments = 4
	for i in 4:
		var shard := MeshInstance3D.new(); shard.mesh = shard_mesh; shard.material_override = materials[i % 2]
		add_child(shard); shard.hide(); orbit.append(shard)
	for kind in 3:
		var audio := AudioStreamPlayer.new(); add_child(audio); audio.stream = make_sound(kind)
		audio.volume_db = -23 if kind == 0 else -19; sounds.append(audio)
	presentation.animation_cue.connect(receive)
	player.reset_performed.connect(clear)

func make_sound(kind: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 22050
	var count := 6600; var data := PackedByteArray(); data.resize(count * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 178 + kind
	var filtered := 0.0
	for i in count:
		var t := i / 22050.0; var envelope := sin(minf(1,t/0.012)*PI/2) * exp(-t*(13 if kind == 0 else 20))
		filtered = lerpf(filtered,rng.randf_range(-1,1),0.22)
		var pitch := 150.0 if kind == 0 else (65.0 if kind == 1 else 420.0)
		var sample := (sin(TAU*(pitch*t - 55*t*t))*0.4 + filtered*0.6)*envelope
		data.encode_s16(i*2,int(sample*20000))
	wav.data = data; return wav

func sound(kind: int) -> void:
	if DisplayServer.get_name() != "headless" and player.controls_enabled: sounds[kind].play()

func add_effect(mesh: Mesh, point: Vector3, normal: Vector3, size: float, duration: float, velocity: Vector3, color: int, kind: String) -> void:
	if effects.size() >= LIMIT: return
	var visual := MeshInstance3D.new(); visual.mesh = mesh; visual.material_override = materials[color]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual); visual.global_position = point
	if kind == "ring": visual.global_basis = PortalPhysics.frame(normal) * Basis(Vector3.RIGHT,PI/2)
	visual.scale = Vector3.ONE * size
	effects.append({"node":visual,"age":0.0,"life":duration,"size":size,"velocity":velocity,"kind":kind})
	spawned += 1; peak = maxi(peak,effects.size())

func burst(point: Vector3, normal: Vector3, count: int = 12, size: float = 1.0) -> void:
	var frame := PortalPhysics.frame(normal)
	for i in count:
		var angle := i * TAU / count
		var radial := frame.x*cos(angle) + frame.y*sin(angle)
		add_effect(shard_mesh,point + radial * 0.15,normal,size,0.32 + (i%3)*0.08,radial*(2 + i%4) + normal*.4,i%3,"shard")

func wave(point: Vector3, normal: Vector3, size: float) -> void:
	add_effect(ring_mesh,point,normal,size,0.38,Vector3.ZERO,1,"ring")

func slash(point: Vector3, normal: Vector3, size: float) -> void:
	var frame := PortalPhysics.frame(normal)
	for layer in 2:
		var mesh := ImmediateMesh.new(); mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 24:
			var a := -1.15+i*2.30/24; var b := -1.15+(i+1)*2.30/24
			var outer := size*(1 + layer*.04); var inner := outer - size*.10*sin((i+.5)*PI/24)
			var p := [Vector3(cos(a)*inner,sin(a)*inner,0),Vector3(cos(a)*outer,sin(a)*outer,0),Vector3(cos(b)*outer,sin(b)*outer,0),Vector3(cos(b)*inner,sin(b)*inner,0)]
			for index in [0,1,2,0,2,3]: mesh.surface_add_vertex(frame*p[index])
		mesh.surface_end()
		add_effect(mesh,point + normal*layer*.025,normal,1,0.26,normal*.5,layer,"arc")

func receive(action: String, data: Dictionary) -> void:
	var hand := character.socket_position("FX_CastHand")
	match action:
		"transit_start":
			burst(hand,Vector3.UP,8,.7); wave(data.entry.origin,data.entry.basis.z,1.0)
			burst(data.exit.origin,data.exit.basis.z,12); sound(0)
		"passage":
			burst(data.entry.origin,data.entry.basis.z,10); burst(data.exit.origin,data.exit.basis.z,14)
			wave(data.exit.origin,data.exit.basis.z,1.2); sound(1)
		"transit_release", "dive": burst(player.global_position,-player.camera_rig.global_basis.z,8,.8)
		"link_place": burst(data.pose.origin,data.pose.basis.z,12); wave(data.pose.origin,data.pose.basis.z,1.3); sound(0)
		"cut_release":
			slash(hand,-player.camera_rig.global_basis.z,1.4)
			slash(data.get("point",hand),data.get("normal",Vector3.UP),data.get("radius",1.4)); sound(2)
		"cut_hit":
			burst(data.point,data.normal,20,1.4); wave(data.point,data.normal,minf(data.radius,5))
		"land", "impact":
			wave(player.global_position-Vector3.UP*.68,Vector3.UP,.55)
			burst(player.global_position-Vector3.UP*.6,Vector3.UP,6,.55)
		"exit_blocked": burst(data.entry.origin,data.entry.basis.z,6); sound(2)
		"cancel", "reset", "transit_cancel": clear()

func _process(delta: float) -> void:
	clock += delta; emission_left -= delta
	var channeling := magic.mode in [PortalMagic.Mode.AIMING,PortalMagic.Mode.BOOST_AIM,PortalMagic.Mode.EDITING,PortalMagic.Mode.MARKED,PortalMagic.Mode.CUT_CHARGE]
	var hand := character.socket_position("FX_CastHand")
	for i in orbit.size():
		orbit[i].visible = channeling
		if channeling:
			var angle := clock * 2 + i * TAU / 4
			orbit[i].global_position = hand + Vector3(cos(angle)*.18,sin(angle)*.18,0)
			orbit[i].rotation = Vector3(0,angle*.5,PI/4); orbit[i].scale = Vector3.ONE*.55
	if emission_left <= 0 and player.controls_enabled:
		emission_left = .09
		if magic.mode == PortalMagic.Mode.CUT_CHARGE:
			var frame := PortalPhysics.frame(magic.cut_normal)
			var radial := frame.x*cos(clock*5) + frame.y*sin(clock*5)
			add_effect(shard_mesh,magic.cut_point+radial*magic.cut_radius,magic.cut_normal,.7,.3,-radial*2,1,"shard")
		elif player.velocity.length() > 30:
			add_effect(shard_mesh,player.global_position,Vector3.UP,.7,.26,-player.velocity.normalized()*3,1,"shard")
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary = effects[i]; effect.age += delta
		var t: float = effect.age / effect.life
		if t >= 1:
			effect.node.queue_free(); effects.remove_at(i); continue
		effect.node.position += effect.velocity * delta
		if effect.kind == "shard": effect.node.rotate_z(delta*3)
		var scale_value: float = effect.size * (lerpf(.4,2.2,t) if effect.kind == "ring" else 1.0) * (1-smoothstep(.65,1,t))
		effect.node.scale = Vector3.ONE*maxf(.001,scale_value)

func clear() -> void:
	for effect in effects: effect.node.queue_free()
	effects.clear()
	for shard in orbit: shard.hide()
	for audio in sounds: audio.stop()
