class_name PortalComponent
extends Node3D

var host: WeakRef
var host_transform := Transform3D.IDENTITY
var slot: int = 0
var radius: float = 3.2
var temporary: bool = false
var lifetime: float = 2.0

func valid_surface() -> bool:
	if temporary: return lifetime > 0
	var body = host.get_ref() if host else null
	return is_instance_valid(body) and not body.is_queued_for_deletion() and body.collision_layer != 0 and body.global_transform.is_equal_approx(host_transform)

func build_visual() -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.006, 0.007, 0.009)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius; cylinder.bottom_radius = radius; cylinder.height = 0.018
	cylinder.radial_segments = 48; cylinder.material = black
	disk.mesh = cylinder; disk.rotation.x = PI / 2; add_child(disk)
	for i in slot + 1:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.10 - i * 0.22
		torus.outer_radius = radius - i * 0.22
		torus.rings = 48; torus.ring_segments = 6; torus.material = white
		ring.mesh = torus; ring.rotation.x = PI / 2; ring.position.z = 0.028; add_child(ring)
	var label := Label3D.new()
	label.text = "A" if slot == 0 else "B"
	label.position = Vector3(0, radius + 0.5, 0.08)
	label.font_size = 64; label.pixel_size = 0.015
	add_child(label)
