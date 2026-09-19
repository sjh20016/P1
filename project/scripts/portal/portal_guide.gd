class_name PortalGuide
extends Node3D

# A lightweight steering projectile, using the same swept sight checks as the
# grapple rather than instantiating a hidden rope, hook or physical constraint.
var portals: PortalManager
var player: RavagePlayer
var point := Vector3.ZERO
var direction := Vector3.FORWARD
var normal := Vector3.UP
var distance: float = 0
var active: bool = false
var stopped: bool = false
var hit_surface: bool = false
var for_cut: bool = false
var ring: MeshInstance3D
var material: StandardMaterial3D
var travel_trace: ImmediateMesh

func _ready() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new(); mesh.inner_radius = 0.92; mesh.outer_radius = 1.0
	mesh.rings = 40; mesh.ring_segments = 6
	material = StandardMaterial3D.new(); material.albedo_color = Color(0.08,0.07,0.12,0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material; ring.mesh = mesh; add_child(ring)
	travel_trace = ImmediateMesh.new()
	var trace := MeshInstance3D.new(); trace.mesh = travel_trace; trace.material_override = material; add_child(trace)
	hide()

func begin(cut_mode: bool) -> void:
	for_cut = cut_mode; active = true; stopped = false; hit_surface = false; distance = 0
	point = player.global_position + Vector3.UP * 0.5
	direction = -player.camera_rig.global_basis.z
	normal = Vector3.UP; show(); update_visual(1.5)

func advance(delta: float) -> void:
	if not active or stopped: return
	var aim: Vector3 = -player.camera_rig.global_basis.z
	direction = direction.lerp(aim, 1 - exp(-portals.profile.guide_turn_rate * delta)).normalized()
	if direction.length_squared() < 0.1: direction = aim
	var step := minf(portals.profile.guide_speed * delta, portals.profile.guide_range - distance)
	var next := point + direction * maxf(0, step)
	var hit := trace(point, next)
	distance += step
	if not hit.is_empty():
		point = hit.position; normal = hit.normal; stopped = true; hit_surface = true
	else: point = next
	if distance >= portals.profile.guide_range: stopped = true
	update_visual(portals.profile.cut_min_radius if for_cut else 1.5)

func trace(a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b,3 | 16,[player.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func quick_target() -> Dictionary:
	var start := player.global_position + Vector3.UP * 0.5
	var aim: Vector3 = -player.camera_rig.global_basis.z
	var end := start + aim * portals.profile.quick_cast_distance
	var hit := trace(start,end)
	return {"point":hit.position if not hit.is_empty() else end,"direction":aim,
		"normal":hit.get("normal",Vector3.UP),"surface":not hit.is_empty()}

func snapshot() -> Dictionary:
	if distance < 3.0: return quick_target()
	return {"point":point,"direction":direction,"normal":normal,"surface":hit_surface}

func lock() -> void:
	stopped = true
	if distance < 3.0:
		var target := quick_target()
		point = target.point; direction = target.direction; normal = target.normal; hit_surface = target.surface
	update_visual(portals.profile.cut_min_radius if for_cut else 1.5)

func update_visual(radius: float) -> void:
	ring.global_position = point + normal * 0.06
	# Show the expected exit in front of a wall, where the player will emerge
	# with enough runway to strike it. The cut marker stays on its hit plane.
	if hit_surface and not for_cut:
		ring.global_position = point - direction * portals.profile.impact_runup
	var axis := Vector3.UP if for_cut else direction
	ring.global_basis = PortalPhysics.frame(axis) * Basis(Vector3.RIGHT, PI / 2)
	ring.scale = Vector3.ONE * radius
	travel_trace.clear_surfaces()
	if for_cut or stopped: return
	# Only a short faint wake. No visible tentacle and no connection constraint.
	travel_trace.surface_begin(Mesh.PRIMITIVE_LINES)
	travel_trace.surface_add_vertex(point - direction * 3)
	travel_trace.surface_add_vertex(point)
	travel_trace.surface_end()

func cancel() -> void:
	active = false; stopped = false; hide(); travel_trace.clear_surfaces()
