extends MeshInstance3D

@export var tendril_count: int = 8
@export var tendril_length: float = 1.55
var geometry := ImmediateMesh.new()
var black := StandardMaterial3D.new()
var pressure: float = 0.0
@onready var player: RavagePlayer = get_parent()
@onready var core: MeshInstance3D = player.get_node("Core")

func _ready() -> void:
	mesh = geometry
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.003,0.003,0.004)
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.material_override = preload("res://assets/placeholders/living_ink.tres").duplicate()
	call_deferred("connect_impacts")

func connect_impacts() -> void:
	var manager: DestructionManager = get_tree().get_first_node_in_group("destruction_manager")
	if manager:
		manager.destruction_event.connect(func(_p: Vector3,_d: Vector3,s: float): pressure = minf(s/60.0,1.0))

func _process(delta: float) -> void:
	pressure = move_toward(pressure,0.0,delta*4.0)
	var time := Time.get_ticks_msec()*0.001
	var speed := player.velocity.length()
	core.scale = Vector3(1.0+pressure*0.28,1.0-pressure*0.24,1.0+pressure*0.13)
	core.rotation.z = sin(time*1.8)*0.05 + player.velocity.x*0.0015
	core.material_override.set_shader_parameter("motion",minf(speed/60.0,1.0))
	geometry.clear_surfaces()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES,black)
	var view_right := player.camera_rig.basis.x
	var view_up := player.camera_rig.basis.y
	var wake := -player.velocity.limit_length(50)*0.012
	for arm in tendril_count:
		var angle := TAU*arm/tendril_count + sin(float(arm)*9.1)*0.17 + sin(time*0.4+arm)*0.08
		var radial := view_right*cos(angle)+view_up*sin(angle)
		var side := (view_right*-sin(angle)+view_up*cos(angle)).normalized()
		var length := tendril_length*(0.7+float(arm%3)*0.23)
		for step in 12:
			var t0 := float(step)/12.0
			var t1 := float(step+1)/12.0
			var a := radial*(0.42+t0*length)+side*sin(t0*5.0+time*2.4+arm)*t0*0.26+wake*t0*t0
			var b := radial*(0.42+t1*length)+side*sin(t1*5.0+time*2.4+arm)*t1*0.26+wake*t1*t1
			var w0 := 0.115*pow(1.0-t0,1.6)+0.006
			var w1 := 0.115*pow(1.0-t1,1.6)+0.003
			if arm%3==0:
				w0 *= 1.4
				w1 *= 1.4
			for vertex: Vector3 in [a-side*w0,a+side*w0,b+side*w1,a-side*w0,b+side*w1,b-side*w1]:
				geometry.surface_add_vertex(vertex)
	geometry.surface_end()
