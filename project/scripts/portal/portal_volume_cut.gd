class_name PortalVolumeCut
extends Node3D

signal cut_committed(center: Vector3, radius: float, changed: int)
var portals: PortalManager
var legacy: SpatialCutAbility
var active: bool = false
var center := Vector3.ZERO
var normal := Vector3.UP
var radius: float = 0
var age: float = 0
var dealt: bool = false
var effects: Array[Node3D] = []
var casts: int = 0
var total_hits: int = 0
var last_hits: int = 0
const SEPARATION_TIME := 1.8

func request(point: Vector3, size: float, axis: Vector3 = Vector3.UP) -> bool:
	if active or legacy.cooldown > 0 or not point.is_finite() or not axis.is_finite() or axis.length_squared() < 0.5: return false
	center = point; normal = axis.normalized()
	radius = clampf(size,portals.profile.cut_min_radius,portals.profile.cut_max_radius)
	age = 0; dealt = false; active = true; casts += 1
	legacy.cooldown = portals.profile.spatial_cut_cooldown
	portals.cue("cut_release",{"point":center,"normal":normal,"radius":radius,"impact_delay":0.08})
	portals.install_cut_pair(center,normal,radius)
	effects.assign(portals.gates)
	portals.status = "空间断层展开 · 直径 %.1f m" % (radius * 2)
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	for i in 2:
		if not is_instance_valid(effects[i]) or effects[i] != portals.gates[i]:
			finish(false); return
	age += delta
	if age >= 0.08 and not dealt:
		dealt = true; last_hits = apply_volume(); total_hits += last_hits
		cut_committed.emit(center,radius,last_hits)
		portals.cue("cut_hit",{"point":center,"normal":normal,"radius":radius,"changed":last_hits})
	var phase := smoothstep(0.0,1.0,clampf((age - 0.08) / SEPARATION_TIME,0,1))
	for i in 2:
		effects[i].global_position = center + normal * (1 if i == 0 else -1) * phase * portals.profile.cut_separation
	if age >= SEPARATION_TIME + 0.08: finish()

func finish(announce: bool = true) -> void:
	for i in effects.size():
		if is_instance_valid(effects[i]) and effects[i] == portals.gates[i]:
			effects[i].global_position = center + normal * (1 if i == 0 else -1) * portals.profile.cut_separation
			effects[i].traversal_enabled = true
	active = false; effects.clear()
	if announce: portals.status = "切割双门已连接 · 可穿越 · 瞄准门按住 V 移动，滚轮调距离 · C 收回"

func apply_volume() -> int:
	var changed := 0
	for body in get_tree().get_nodes_in_group("destructible"):
		if body.is_queued_for_deletion() or body.collision_layer == 0 or body.get("tower_ref") is WeakRef: continue
		if body is PortalAssetStructure:
			if body.bounds_distance(center) > radius: continue
		elif body.global_position.distance_to(center) > radius + 45: continue
		var contact: Variant = null
		var hits_seam := false
		var selected: Array[Dictionary] = []
		if body.get("state") is OpenDamageState:
			var state: OpenDamageState = body.state
			var local_normal: Vector3 = body.global_basis.transposed() * normal
			var local_center: Vector3 = body.to_local(center)
			if state.kind in [3,4]:
				for face in 4:
					var seam := state.box(face,state.normal(face) * 8 + Vector3.DOWN * 6,Vector2(16,0.2))
					if PortalCutGeometry.contact(seam,body.global_transform,center,normal,radius,portals.profile.spatial_cut_width) != null: hits_seam = true
			for index in 96:
				if state.cells[index] in [1,3]: continue
				var face: int = index / 24
				var cell := state.center(index)
				var point: Variant = PortalCutGeometry.contact(state.box(face,cell,Vector2(4,6)),body.global_transform,center,normal,radius,portals.profile.spatial_cut_width)
				if point == null: continue
				contact = point
				var tangent := Vector3.RIGHT if face < 2 else Vector3.BACK
				var axis := 1 if absf(local_normal.dot(tangent)) > absf(local_normal.y) else 0
				var divisor := local_normal.dot(tangent) if axis == 1 else local_normal.y
				var offset := local_normal.dot(local_center - cell) / divisor if absf(divisor) > 0.01 else 0.0
				selected.append({"index":index,"axis":axis,"offset":offset,"remove":absf(local_normal.dot(state.normal(face))) > 0.85})
		else:
			contact = PortalCutGeometry.contact(body.local_bounds,body.global_transform,center,normal,radius,portals.profile.spatial_cut_width)
		if contact == null: continue
		var event := RavageDamageEvent.new(); event.type = RavageDamageEvent.Type.SLASH
		event.position = contact; event.direction = normal; event.normal = normal
		event.energy = portals.profile.spatial_cut_damage; event.radius = portals.profile.spatial_cut_width
		event.source_id = get_instance_id(); event.context = {"spatial_volume":true,"portal_seam":hits_seam}
		if body is PortalAssetStructure:
			event.context.merge({"asset_disk":true,"asset_center":center,"asset_radius":radius})
		if not selected.is_empty(): event.context["portal_cells"] = selected
		if legacy.manager.apply_damage(body,event).get("changed",false): changed += 1
	legacy.cuts += changed
	return changed

func cancel() -> void:
	if active:
		if dealt: finish()
		else:
			for i in effects.size():
				if is_instance_valid(effects[i]) and effects[i] == portals.gates[i]: portals.close(i)
	active = false; effects.clear()
