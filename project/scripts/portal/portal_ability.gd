class_name PortalAbility
extends Node

var player: RavagePlayer
var portals: PortalManager
var cut: SpatialCutAbility
var emergency_left: float = 0
var preview_clock: float = 0
var preview: MeshInstance3D
var preview_text: String = ""
var magic: PortalMagic

func _ready() -> void:
	player.motion_requested.connect(before_motion)
	player.reset_performed.connect(reset)
	preview = MeshInstance3D.new(); portals.add_child(preview)
	var mesh := TorusMesh.new(); mesh.inner_radius = 3.1; mesh.outer_radius = 3.2; mesh.rings = 32; mesh.ring_segments = 4
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.2, 0.2, 0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material; preview.mesh = mesh

func _physics_process(delta: float) -> void:
	emergency_left = maxf(0, emergency_left - delta)
	player.profile.max_speed = portals.profile.max_portal_velocity
	portals.impact.threshold = portals.profile.high_speed_impact_threshold
	if not player.controls_enabled: preview.hide(); return
	if portals.profile.emergency_portal_enabled and player.global_position.y < -28 and player.velocity.y < -20: emergency()
	if portals.profile.magic_enabled:
		preview.hide(); preview_text = magic.hint() if is_instance_valid(magic) else ""
		if is_instance_valid(magic) and is_instance_valid(magic.links) and magic.links.editing: preview_text = magic.links.preview_text
		return
	preview_clock -= delta
	if preview_clock <= 0:
		preview_clock = 0.08
		var camera: Camera3D = player.camera_rig.camera
		var hit := portals.placement(camera.global_position, -camera.global_basis.z, 0)
		preview_text = "可放置 A" if hit.ok else hit.reason
		preview.visible = hit.ok
		if hit.ok:
			preview.global_transform = Transform3D(hit.basis * Basis(Vector3.RIGHT, PI / 2), hit.point + hit.basis.z * 0.03)
			preview.scale = Vector3.ONE * portals.profile.portal_size / 3.2

func _unhandled_input(event: InputEvent) -> void:
	if not player.controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if portals.profile.magic_enabled:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E: emergency()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var camera: Camera3D = player.camera_rig.camera
		portals.place(camera.global_position, -camera.global_basis.z, 0 if event.button_index == MOUSE_BUTTON_LEFT else 1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q: cut.trigger()
		if event.physical_keycode == KEY_E: emergency()
		if event.physical_keycode == KEY_X: portals.clear()

func before_motion(motion: Vector3, incoming: Vector3) -> void:
	var delta := motion.length() / maxf(incoming.length(), 0.001)
	if is_instance_valid(magic): magic.filter_motion(delta)
	var result := portals.travel(player, player.global_transform, player.velocity, 0.72, delta)
	if not result.is_empty():
		player.global_position = result.transform.origin; player.velocity = result.velocity
		player.previous_position = player.global_position
	portals.impact.check_player(player, delta)

func emergency() -> bool:
	if emergency_left > 0 or player.velocity.y >= -10: return false
	if portals.gates[1] == null:
		portals.status = "紧急入口需要预先放置 B 出口"; return false
	var point := player.global_position + Vector3.DOWN * 2.8
	if point.distance_to(portals.gates[1].global_position) < portals.profile.portal_size * 2 + 1: return false
	portals.install_gate(0, point, PortalPhysics.frame(Vector3.UP))
	emergency_left = 3; portals.status = "紧急 A 已展开（2 秒）"; return true

func reset() -> void:
	portals.last_portal_time.erase(player.get_instance_id())
	if portals.gates[0] != null and portals.gates[0].temporary: portals.close(0)
	emergency_left = 0; cut.cancel()
