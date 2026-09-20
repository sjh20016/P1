class_name PortalCharacter
extends Node3D

const MODEL = preload("res://assets/characters/portal_anomaly/portal_anomaly.glb")
const ATLAS = preload("res://assets/characters/portal_anomaly/pixel_atlas_128.png")
var player: RavagePlayer
var magic: PortalMagic
var presentation: PortalPresentation
var avatar: Node3D
var echo: Node3D
var animation: AnimationPlayer
var echo_animation: AnimationPlayer
var skeleton: Skeleton3D
var material: ShaderMaterial
var clips: Dictionary = {}
var sockets: Dictionary = {}
var current_clip := ""
var transient := ""
var transient_left := 0.0
var in_loop := false
var facing: float = 0
var visual_clock := 0.0
var was_transiting := false

func _ready() -> void:
	material = ShaderMaterial.new(); material.shader = preload("res://shaders/portal_character.gdshader")
	material.set_shader_parameter("pixel_atlas",ATLAS)
	avatar = MODEL.instantiate(); avatar.name = "Avatar"; add_child(avatar)
	animation = avatar.find_children("*","AnimationPlayer",true,false)[0]
	skeleton = avatar.find_children("*","Skeleton3D",true,false)[0]
	configure_meshes(avatar)
	for full_name in animation.get_animation_list():
		for short_name in ["Idle","Run","Jump","Fall","Land","Cast","Cut","Dash"]:
			if str(full_name).to_lower().ends_with(short_name.to_lower()):
				clips[short_name] = full_name
				animation.get_animation(full_name).loop_mode = Animation.LOOP_LINEAR if short_name in ["Idle","Run","Fall","Dash"] else Animation.LOOP_NONE
	for node in avatar.find_children("FX_*","Node3D",true,false): sockets[str(node.name)] = node
	echo = MODEL.instantiate(); echo.name = "LoopEcho"; add_child(echo)
	echo_animation = echo.find_children("*","AnimationPlayer",true,false)[0]
	configure_meshes(echo); echo.hide()
	if is_instance_valid(presentation): presentation.animation_cue.connect(receive)
	if is_instance_valid(player): player.reset_performed.connect(reset_visual)
	play_clip("Idle")

func configure_meshes(root: Node3D) -> void:
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func play_clip(clip: String, blend: float = 0.10) -> void:
	if not clips.has(clip): return
	if current_clip == clip and animation.is_playing(): return
	current_clip = clip; animation.speed_scale = 1; animation.play(clips[clip],blend)

func receive(action: String, _data: Dictionary) -> void:
	match action:
		"cut_release": transient = "Cut"; transient_left = 0.8
		"dash", "passage", "dive": transient = "Dash"; transient_left = 0.3
		"transit_release": transient = "Dash"; transient_left = 0.35
		"transit_cancel": reset_visual()
		"link_place": transient = "Cast"; transient_left = 0.65
		"land", "impact": transient = "Land"; transient_left = 0.3
		"reset", "cancel": reset_visual()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	transient_left = maxf(0,transient_left - delta)
	visual_clock += delta
	if is_instance_valid(magic) and not magic.portals.pending_dash.is_empty():
		animate_transit(magic.portals.pending_dash)
		was_transiting = true; return
	if was_transiting:
		was_transiting = false; finish_loop(); material.set_shader_parameter("portal_clip",false)
	var grounded := player.is_on_floor()
	var horizontal := Vector3(player.velocity.x,0,player.velocity.z)
	var casting := is_instance_valid(magic) and magic.mode in [PortalMagic.Mode.AIMING,PortalMagic.Mode.BOOST_AIM,PortalMagic.Mode.EDITING,PortalMagic.Mode.MARKED,PortalMagic.Mode.CUT_CHARGE]
	if casting or horizontal.length() < 0.5:
		facing = lerp_angle(facing,player.camera_rig.rotation.y + PI,1 - exp(-delta * 12))
	else: facing = lerp_angle(facing,atan2(horizontal.x,horizontal.z),1 - exp(-delta * 14))
	avatar.rotation.y = facing; echo.rotation.y = facing
	if in_loop:
		play_clip("Fall")
		echo_animation.play(clips.Fall); echo_animation.seek(animation.current_animation_position,true)
	elif casting:
		if current_clip != "Cast": play_clip("Cast",0)
		animation.seek(0.36 + sin(visual_clock * 3.5) * 0.018,true); animation.pause()
	elif transient_left > 0:
		play_clip(transient)
	elif not grounded:
		if player.velocity.y > 1:
			play_clip("Jump")
		else: play_clip("Fall")
	elif horizontal.length() > 0.7:
		play_clip("Run"); animation.speed_scale = clampf(horizontal.length() / 7.5,0.75,1.8)
	else: play_clip("Idle")
	# A restrained bank follows steering; cloth remains driven by the action rig.
	var turn := wrapf(atan2(horizontal.x,horizontal.z) - facing,-PI,PI) if horizontal.length() > 1 else 0.0
	avatar.rotation.z = lerpf(avatar.rotation.z,clampf(-turn * 0.08,-0.12,0.12),1-exp(-delta*10))

func animate_transit(data: Dictionary) -> void:
	in_loop = false; echo.hide(); material.set_shader_parameter("loop_clip",false)
	material.set_shader_parameter("portal_clip",true)
	if data.get("stage","entry") == "entry":
		var t := clampf((float(data.age) - PortalManager.DASH_FORM_TIME) / PortalManager.DASH_ENTER_TIME,0,1)
		var entry: Transform3D = data.entry
		material.set_shader_parameter("portal_origin",entry.origin)
		material.set_shader_parameter("portal_normal",entry.basis.z)
		play_clip("Cast" if t < 0.12 else "Fall",0.08)
		avatar.position = Vector3.DOWN * smoothstep(0,1,t) * 2.25
		avatar.scale = Vector3(1 - t * 0.08,1 + t * 0.12,1 - t * 0.08)
	else:
		var t := smoothstep(0,1,clampf(float(data.age) / PortalManager.DASH_EXIT_TIME,0,1))
		var exit: Transform3D = data.exit
		material.set_shader_parameter("portal_origin",exit.origin)
		material.set_shader_parameter("portal_normal",exit.basis.z)
		play_clip("Dash",0.06)
		avatar.position = -exit.basis.z * (1-t) * 1.7
		avatar.scale = Vector3.ONE
		avatar.rotation.y = atan2(exit.basis.z.x,exit.basis.z.z); facing = avatar.rotation.y

func set_loop(phase: float, speed_fraction: float) -> void:
	in_loop = true; echo.show()
	material.set_shader_parameter("loop_clip",true)
	material.set_shader_parameter("clip_bottom",player.global_position.y - 0.78)
	material.set_shader_parameter("clip_top",player.global_position.y + 1.9)
	# Model soles start above the top aperture, descend, then wrap through it.
	avatar.position.y = 2.62 - phase * 2.68
	avatar.scale = Vector3(1,lerpf(1.0,1.05,speed_fraction),1)
	echo.position.y = avatar.position.y - 2.68
	echo.scale = avatar.scale

func finish_loop() -> void:
	in_loop = false
	material.set_shader_parameter("loop_clip",false)
	avatar.position = Vector3.ZERO; avatar.scale = Vector3.ONE
	echo.hide()

func reset_visual() -> void:
	transient_left = 0; transient = ""; was_transiting = false
	material.set_shader_parameter("portal_clip",false)
	finish_loop(); avatar.rotation.z = 0; play_clip("Idle",0)

func socket_position(socket_name: String) -> Vector3:
	return sockets[socket_name].global_position if sockets.has(socket_name) else global_position
