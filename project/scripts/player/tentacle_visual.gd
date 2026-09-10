extends MeshInstance3D

var rope_mesh := ImmediateMesh.new()
@onready var hook: GrappleController = get_parent()
var material := StandardMaterial3D.new()

func _ready() -> void:
	mesh = rope_mesh
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.003,0.003,0.004)
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY

func _process(_delta: float) -> void:
	rope_mesh.clear_surfaces()
	if not hook.active:
		return
	var start := hook.player.global_position + hook.player.camera_rig.global_basis.x * (-0.45 if hook.action == &"hook_left" else 0.45)
	var end := hook.grapple_point
	var direction := (end - start).normalized()
	var camera: Camera3D = hook.player.get_viewport().get_camera_3d()
	var side := direction.cross(camera.global_position-start).normalized()
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	var sag := minf(maxf(hook.rest_length - start.distance_to(end), 0.0) * 0.22, 3.0)
	rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for i in 18:
		var t0 := float(i) / 18.0
		var t1 := float(i + 1) / 18.0
		var a := start.lerp(end, t0) + Vector3.DOWN * sin(t0 * PI) * sag
		var b := start.lerp(end, t1) + Vector3.DOWN * sin(t1 * PI) * sag
		var time := Time.get_ticks_msec()*0.003
		a += side*sin(t0*17.0+time)*sin(t0*PI)*minf(sag*0.12,0.2)
		b += side*sin(t1*17.0+time)*sin(t1*PI)*minf(sag*0.12,0.2)
		var s0 := side*lerpf(0.18,0.025,pow(t0,0.45))
		var s1 := side*lerpf(0.18,0.025,pow(t1,0.45))
		for v: Vector3 in [a-s0,a+s0,b+s1,a-s0,b+s1,b-s1]:
			rope_mesh.surface_add_vertex(v)
	rope_mesh.surface_end()
