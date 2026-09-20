class_name PortalWindowRenderer
extends Node

# A single non-recursive window per physical aperture. The off-axis frustum is
# aligned with the exit plane, so its near plane clips the supporting wall.
# This is separate from travel/collision and never creates another physics world.
const WINDOW_SHADER = preload("res://scripts/portal/portal_window.gdshader")
var portals: PortalManager
var viewer: Camera3D
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var windows: Array = [null,null]
var hosts: Array = [null,null]
var active_views: int = 0
var clock: float = 0
var rendered_updates: int = 0

static func projection(entry: Transform3D, exit: Transform3D, eye: Vector3, radius: float) -> Dictionary:
	var local := entry.affine_inverse() * eye
	if local.z <= 0.08: return {}
	var rotation := PortalPhysics.rotation_between(entry.basis,exit.basis)
	var camera_pose := Transform3D(exit.basis * Basis(Vector3.UP,PI),exit.origin + rotation * (eye - entry.origin))
	var near_plane := local.z + 0.045
	var scale := near_plane / local.z
	return {"pose":camera_pose,"near":near_plane,"size":2 * radius * scale,
		"offset":Vector2(-local.x,-local.y) * scale}

func _ready() -> void:
	process_priority = 20
	if DisplayServer.get_name() == "headless": set_process(false); return
	for i in 2:
		var viewport := SubViewport.new(); viewport.size = Vector2i.ONE * portals.profile.portal_view_resolution
		viewport.world_3d = viewer.get_world_3d(); viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.handle_input_locally = false; viewport.audio_listener_enable_3d = false
		add_child(viewport); views.append(viewport)
		var camera := Camera3D.new(); viewport.add_child(camera); camera.current = true
		camera.cull_mask = viewer.cull_mask & ~PortalComponent.VIEW_LAYER
		cameras.append(camera)

func release_window(slot: int) -> void:
	if is_instance_valid(windows[slot]): windows[slot].queue_free()
	windows[slot] = null; hosts[slot] = null

func bind_window(slot: int, gate: PortalComponent) -> void:
	release_window(slot)
	var window := MeshInstance3D.new(); var quad := QuadMesh.new()
	quad.size = Vector2.ONE * gate.radius * 2; window.mesh = quad
	window.layers = PortalComponent.VIEW_LAYER; window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new(); material.shader = WINDOW_SHADER
	material.set_shader_parameter("remote_view",views[slot].get_texture())
	window.material_override = material; gate.add_child(window); window.position.z = 0.019
	windows[slot] = window; hosts[slot] = weakref(gate)

func _process(delta: float) -> void:
	clock -= delta
	if clock > 0: return
	clock = 1.0 / portals.profile.portal_view_fps
	active_views = 0
	for i in 2:
		views[i].render_target_update_mode = SubViewport.UPDATE_DISABLED
		var gate: PortalComponent = portals.gates[i]
		var remote: PortalComponent = portals.gates[1-i]
		if gate == null or remote == null or not gate.valid_surface() or not remote.valid_surface():
			release_window(i); continue
		if hosts[i] == null or hosts[i].get_ref() != gate: bind_window(i,gate)
		windows[i].visible = false
		if not portals.profile.portal_view_enabled: continue
		if viewer.global_position.distance_to(gate.global_position) > portals.profile.portal_view_distance: continue
		var in_frame: bool = false
		for point in [Vector3.ZERO,Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN]:
			if viewer.is_position_in_frustum(gate.to_global(point * gate.radius)): in_frame = true; break
		if not in_frame: continue
		var view := projection(gate.global_transform,remote.global_transform,viewer.global_position,gate.radius)
		if view.is_empty(): continue
		views[i].size = Vector2i.ONE * portals.profile.portal_view_resolution
		cameras[i].global_transform = view.pose
		cameras[i].set_frustum(view.size,view.offset,view.near,view.near + 700)
		windows[i].visible = true; active_views += 1; rendered_updates += 1
		views[i].render_target_update_mode = SubViewport.UPDATE_ONCE

func _exit_tree() -> void:
	for i in 2: release_window(i)
