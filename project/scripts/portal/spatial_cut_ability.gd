class_name SpatialCutAbility
extends Node3D

signal slice_event(data: Dictionary)
var portals: PortalManager
var manager: DestructionManager
var cooldown: float = 0
var pending: float = -1
var endpoints: Array[Vector3] = []
var line: MeshInstance3D
var line_life: float = 0
var cuts: int = 0

func trigger() -> bool:
	if cooldown > 0 or portals.gates[0] == null or portals.gates[1] == null: return false
	endpoints.assign([portals.gates[0].global_position, portals.gates[1].global_position])
	cooldown = portals.profile.spatial_cut_cooldown; pending = 0.07
	show_line(endpoints[0], endpoints[1]); return true

func _physics_process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	line_life -= delta
	if is_instance_valid(line) and line_life <= 0: line.queue_free()
	if pending < 0: return
	pending -= delta
	if pending <= 0:
		pending = -1; execute(endpoints[0], endpoints[1])

func execute(a: Vector3, b: Vector3) -> int:
	var targets: Dictionary = {}
	# Use existing logical shell boxes, not merged-body centres. One damage event
	# per building keeps fracture work bounded; no dynamic mesh Boolean.
	for body in get_tree().get_nodes_in_group("destructible"):
		if body.is_queued_for_deletion() or body.collision_layer == 0: continue
		if body.get("tower_ref") is WeakRef: continue
		var inv: Transform3D = body.global_transform.affine_inverse()
		var boxes: Array = body.shape_boxes if body.get("shape_boxes") != null else [body.local_bounds]
		var nearest: Variant = null
		for bounds: AABB in boxes:
			var local_hit: Variant = bounds.grow(portals.profile.spatial_cut_width * 0.5).intersects_segment(inv * a, inv * b)
			if local_hit == null: continue
			var hit: Vector3 = body.global_transform * local_hit.clamp(bounds.position, bounds.end)
			if nearest == null or a.distance_squared_to(hit) < a.distance_squared_to(nearest): nearest = hit
		if nearest != null: targets[body] = nearest
	var changed: int = 0
	for body in targets:
		if changed >= 12: break
		var event := RavageDamageEvent.new()
		event.type = RavageDamageEvent.Type.SLASH
		event.position = targets[body]; event.direction = (b - a).normalized()
		event.energy = portals.profile.spatial_cut_damage; event.radius = portals.profile.spatial_cut_width
		event.source_id = get_instance_id(); event.context = {"spatial_cut": true}
		if manager.apply_damage(body, event).get("changed", false): changed += 1
	cuts += changed
	slice_event.emit({"start": a, "end": b, "width": portals.profile.spatial_cut_width, "targets": changed})
	portals.status = "空间切割：%d 个建筑响应" % changed
	return changed

func show_line(a: Vector3, b: Vector3) -> void:
	if is_instance_valid(line): line.queue_free()
	line = MeshInstance3D.new()
	var mesh := CylinderMesh.new(); mesh.top_radius = 0.045; mesh.bottom_radius = 0.045; mesh.height = a.distance_to(b)
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.008, 0.008, 0.012); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material; line.mesh = mesh; add_child(line)
	line.global_position = (a + b) * 0.5; line.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	line_life = 0.28

func cancel() -> void:
	pending = -1; cooldown = 0
	if is_instance_valid(line): line.queue_free()
