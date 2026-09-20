class_name PortalVolumeCut
extends Node3D

signal cut_committed(center: Vector3, radius: float, changed: int)
var portals: PortalManager
var legacy: SpatialCutAbility
var active: bool = false
var center := Vector3.ZERO
var radius: float = 0
var age: float = 0
var dealt: bool = false
var effects: Array[Node3D] = []
var casts: int = 0
var total_hits: int = 0
var last_hits: int = 0

func request(point: Vector3, size: float) -> bool:
	if active or legacy.cooldown > 0 or not point.is_finite(): return false
	center = point; radius = clampf(size, portals.profile.cut_min_radius, portals.profile.cut_max_radius)
	age = 0; dealt = false; active = true; casts += 1
	legacy.cooldown = portals.profile.spatial_cut_cooldown
	portals.cue("cut_release",{"point":center,"radius":radius,"impact_delay":0.08})
	for i in 2:
		var gate := PortalComponent.new(); gate.slot = i; gate.radius = radius
		add_child(gate); gate.global_transform = Transform3D(PortalPhysics.frame(Vector3.UP),center)
		gate.build_visual(); effects.append(gate)
	portals.status = "空间断层展开 · 直径 %.1f m" % (radius * 2)
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	age += delta
	if age >= 0.08 and not dealt:
		dealt = true; last_hits = apply_volume(); total_hits += last_hits
		cut_committed.emit(center,radius,last_hits)
		portals.status = "空间断层 · 直径 %.1f m · %d 处裂开" % [radius * 2,last_hits]
	var phase := clampf((age - 0.08) / 0.65,0,1)
	for i in effects.size():
		effects[i].global_position = center + Vector3.UP * (1 if i == 0 else -1) * phase * portals.profile.cut_separation
		effects[i].scale = Vector3.ONE * (1.0 - pow(phase,4) * 0.98)
	if age >= 0.8: cancel()

func apply_volume() -> int:
	var jobs: Array[Dictionary] = []
	# Broad-phase on existing shells, then exact bounded horizontal disk/box tests.
	# Do not spawn rigid bodies for the spell, or add another destruction system.
	for body in get_tree().get_nodes_in_group("destructible"):
		if body.is_queued_for_deletion() or body.collision_layer == 0 or body.get("tower_ref") is WeakRef: continue
		if body.global_position.distance_to(center) > radius + 40: continue
		var local: Vector3 = body.to_local(center)
		var boxes: Array = body.shape_boxes if body.get("shape_boxes") != null else [body.local_bounds]
		var faces: Dictionary = {}
		for bounds: AABB in boxes:
			var point: Vector3 = body.to_global(local.clamp(bounds.position,bounds.end))
			var offset := point - center
			if absf(offset.y) > portals.profile.spatial_cut_width * 0.5: continue
			if Vector2(offset.x,offset.z).length() > radius: continue
			var face: int = body.state.face_at(body.to_local(point)) if body.get("state") is OpenDamageState else 0
			if not faces.has(face) or point.distance_squared_to(center) < faces[face].distance_squared_to(center): faces[face] = point
		for face in faces:
			jobs.append({"body":body,"point":faces[face],"span":sqrt(maxf(0.01,radius * radius - center.distance_squared_to(faces[face])))})
	var changed: int = 0
	for job in jobs.slice(0,16):
		if not is_instance_valid(job.body) or job.body.is_queued_for_deletion(): continue
		var event := RavageDamageEvent.new(); event.type = RavageDamageEvent.Type.SLASH
		event.position = job.point; event.direction = Vector3.UP; event.normal = Vector3.UP
		event.energy = portals.profile.spatial_cut_damage; event.radius = portals.profile.spatial_cut_width
		event.source_id = get_instance_id(); event.context = {"spatial_volume":true,"slice_span":job.span}
		if legacy.manager.apply_damage(job.body,event).get("changed",false): changed += 1
	legacy.cuts += changed
	return changed

func cancel() -> void:
	active = false
	for effect in effects:
		if is_instance_valid(effect): effect.queue_free()
	effects.clear()
