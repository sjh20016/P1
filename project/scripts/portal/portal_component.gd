class_name PortalComponent
extends Node3D

var host: WeakRef
var host_transform := Transform3D.IDENTITY
var slot: int = 0
var radius: float = 3.2
var temporary: bool = false
var free_floating: bool = false
var traversal_enabled: bool = true
var lifetime: float = 2.0
var disk: MeshInstance3D
var show_label: bool = true
var label_text := ""
var visual_root: Node3D
var visual_age := 0.0
var ornaments: Array[Node3D] = []
# Only the portal camera excludes this render layer. Physics masks are separate.
const VIEW_LAYER: int = 1 << 19

func valid_surface() -> bool:
	if free_floating: return not is_queued_for_deletion()
	if temporary: return lifetime > 0
	var body = host.get_ref() if host else null
	return is_instance_valid(body) and not body.is_queued_for_deletion() and body.collision_layer != 0 and body.global_transform.is_equal_approx(host_transform)

func build_visual() -> void:
	visual_root = Node3D.new(); add_child(visual_root)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.006, 0.007, 0.009)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disk = MeshInstance3D.new(); disk.layers = VIEW_LAYER
	var aperture := QuadMesh.new(); aperture.size = Vector2.ONE * radius * 2
	var rift := ShaderMaterial.new(); rift.shader = preload("res://shaders/portal_rift.gdshader")
	disk.mesh = aperture; disk.material_override = rift; visual_root.add_child(disk)
	for i in slot + 1:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.10 - i * 0.22
		torus.outer_radius = radius - i * 0.22
		torus.rings = 48; torus.ring_segments = 6; torus.material = white
		ring.mesh = torus; ring.rotation.x = PI / 2; ring.position.z = 0.028; visual_root.add_child(ring)
	for i in 8:
		var shard := MeshInstance3D.new(); var prism := PrismMesh.new()
		prism.size = Vector3(0.10,0.24,0.045) * clampf(radius / 2,0.5,2)
		prism.material = white if i % 2 == 0 else black; shard.mesh = prism
		var angle := i * TAU / 8
		shard.position = Vector3(cos(angle),sin(angle),0.025) * (radius + 0.14)
		shard.rotation.z = angle - PI / 2; visual_root.add_child(shard); ornaments.append(shard)
	if not show_label: return
	var label := Label3D.new()
	label.text = label_text if not label_text.is_empty() else ("A" if slot == 0 else "B")
	label.font = preload("res://assets/placeholders/ui_zh.tres")
	label.position = Vector3(0, radius + 0.5, 0.08)
	label.font_size = 32; label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visual_root.add_child(label)

func _process(delta: float) -> void:
	if not is_instance_valid(visual_root): return
	visual_age += delta
	var opening := smoothstep(0.0,0.22,visual_age)
	visual_root.scale = Vector3(maxf(0.015,opening),maxf(0.04,sqrt(opening)),1)
	for i in ornaments.size():
		var angle := i * TAU / 8 + sin(visual_age * 0.8) * 0.015
		var distance := radius + 0.14 + sin(visual_age * 2 + i) * 0.045
		ornaments[i].position = Vector3(cos(angle) * distance,sin(angle) * distance,0.03)
