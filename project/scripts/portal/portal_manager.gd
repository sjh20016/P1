class_name PortalManager
extends Node3D

signal traversed(body: Node3D, rotation: Basis, speed: float)
signal placement_changed
signal action_cue(action: String, data: Dictionary)
var profile: PortalProfile
var gates: Array = [null, null]
var impact: KineticImpact
var clock: float = 0
var last_portal_time: Dictionary = {}
var traversal_count: int = 0
var object_traversals: int = 0
var blocked_count: int = 0
var detection_checks: int = 0
var status: String = "左键 A / 右键 B：瞄准平整的大型表面"
var validation_clock: float = 0
var magic_casts: int = 0
var dash_gates: Array[PortalComponent] = []
var pending_dash: Dictionary = {}
const DASH_FORM_TIME := 0.22
const DASH_ENTER_TIME := 0.48
const DASH_EXIT_TIME := 0.20

func _ready() -> void:
	add_to_group("portal_manager")
	add_to_group("rigidbody_motion_extension")
	process_physics_priority = -10

func _physics_process(delta: float) -> void:
	clock += delta
	advance_dash(delta)
	for i in 2:
		if gates[i] == null: continue
		if gates[i].temporary: gates[i].lifetime -= delta
		if not gates[i].valid_surface(): close(i)
	validation_clock -= delta
	if validation_clock <= 0:
		validation_clock = 0.15
		for i in 2:
			var gate = gates[i]
			if gate != null and not gate.temporary and not gate.free_floating and not support_valid(gate.global_position, gate.global_basis, gate.host.get_ref(), gate.radius):
				close(i)
		for id in last_portal_time.keys():
			if clock - float(last_portal_time[id]) > 2: last_portal_time.erase(id)

func close(slot: int) -> void:
	if is_instance_valid(gates[slot]): gates[slot].queue_free()
	gates[slot] = null
	placement_changed.emit()

func clear() -> void:
	close(0); close(1); last_portal_time.clear()
	clear_dash_visuals()

func cue(action: String, data: Dictionary = {}) -> void:
	var payload := data.duplicate(); payload["time"] = clock
	action_cue.emit(action,payload)

func clear_dash_visuals() -> void:
	cancel_dash()
	for gate in dash_gates:
		if is_instance_valid(gate): gate.queue_free()
	dash_gates.clear()

func show_dash(entry: Transform3D, exit: Transform3D) -> void:
	clear_dash_visuals()
	for pose in [entry,exit]:
		var gate := PortalComponent.new(); gate.slot = dash_gates.size()
		gate.radius = profile.portal_size; gate.free_floating = true; gate.traversal_enabled = false
		gate.label_text = "入口" if gate.slot == 0 else "出口"
		add_child(gate); gate.global_transform = pose; gate.build_visual(); dash_gates.append(gate)

func ray_hit(origin: Vector3, end: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, end, 3, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)

func support_valid(point: Vector3, basis: Basis, body, radius: float) -> bool:
	if not is_instance_valid(body) or not body is StaticBody3D: return false
	if body.collision_layer == 0 or body.is_queued_for_deletion(): return false
	if body is AnimatableBody3D: return false
	for i in 9:
		var offset := Vector3.ZERO if i == 0 else (basis.x * cos((i - 1) * TAU / 8) + basis.y * sin((i - 1) * TAU / 8)) * radius
		var p := point + offset
		var hit := ray_hit(p + basis.z * 0.18, p - basis.z * 0.20)
		if hit.is_empty() or hit.collider != body or hit.normal.dot(basis.z) < 0.98: return false
	return true

func placement(origin: Vector3, direction: Vector3, slot: int) -> Dictionary:
	var hit := ray_hit(origin, origin + direction.normalized() * profile.placement_range)
	if hit.is_empty(): return {"ok": false, "reason": "未找到表面 / 超出放置距离"}
	var normal: Vector3 = hit.normal
	if absf(normal.y) > 0.1 and absf(normal.y) < 0.98:
		return {"ok": false, "reason": "0.01 仅支持平面墙 / 地面 / 天花板", "point": hit.position}
	var basis := PortalPhysics.frame(normal)
	var point: Vector3 = hit.position + normal * 0.035
	if not support_valid(point, basis, hit.collider, profile.portal_size):
		return {"ok": false, "reason": "表面过小、破损或不是静态平面", "point": hit.position}
	var other = gates[1 - slot]
	if other != null and point.distance_to(other.global_position) < profile.portal_size + other.radius + 0.6:
		return {"ok": false, "reason": "两门太近，请拉开距离", "point": hit.position}
	return {"ok": true, "point": point, "basis": basis, "host": hit.collider}

func place(origin: Vector3, direction: Vector3, slot: int) -> bool:
	var result := placement(origin, direction, slot)
	status = ("已放置 " + ("A" if slot == 0 else "B")) if result.ok else result.reason
	if not result.ok: return false
	install_gate(slot, result.point, result.basis, result.host)
	return true

func install_gate(slot: int, point: Vector3, basis: Basis, body = null) -> void:
	close(slot)
	var gate := PortalComponent.new()
	gate.slot = slot; gate.radius = profile.portal_size
	gate.temporary = body == null
	if body != null:
		gate.host = weakref(body); gate.host_transform = body.global_transform
	add_child(gate); gate.global_transform = Transform3D(basis, point)
	gate.build_visual(); gates[slot] = gate
	placement_changed.emit()

func install_cut_pair(point: Vector3, normal: Vector3, radius: float) -> void:
	close(0); close(1)
	for i in 2:
		var gate := PortalComponent.new()
		gate.slot = i; gate.radius = radius; gate.free_floating = true; gate.traversal_enabled = false
		add_child(gate)
		gate.global_transform = Transform3D(PortalPhysics.frame(normal if i == 0 else -normal),point)
		gate.build_visual(); gates[i] = gate
	placement_changed.emit()

func sphere_query(body: PhysicsBody3D, center: Vector3, radius: float) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new(); sphere.radius = radius
	query.shape = sphere; query.transform.origin = center; query.collision_mask = 3 | 16 | 8 | 4
	query.exclude = [body.get_rid()]
	return query

func safe_exit(body: PhysicsBody3D, exit_gate: PortalComponent, tangent: Vector3, radius: float) -> Variant:
	var normal := exit_gate.global_basis.z
	var start := exit_gate.global_position + tangent + normal * (radius + 0.055)
	var space := get_world_3d().direct_space_state
	# Test the full sphere AND the path; never search through a blocking wall.
	for sideways in [Vector3.ZERO, exit_gate.global_basis.x * radius, -exit_gate.global_basis.x * radius, exit_gate.global_basis.y * radius]:
		for distance in [profile.exit_offset, profile.exit_offset + 0.5, profile.exit_offset + 1.0]:
			var point: Vector3 = start + normal * float(distance) + sideways
			var local := exit_gate.global_basis.transposed() * (point - exit_gate.global_position)
			if Vector2(local.x, local.y).length() > exit_gate.radius - radius: continue
			var occupancy := sphere_query(body, point, radius)
			if not space.intersect_shape(occupancy, 1).is_empty(): continue
			var sweep := sphere_query(body, start, radius)
			if not space.intersect_shape(sweep, 1).is_empty(): continue
			sweep.motion = point - start
			if space.cast_motion(sweep)[0] >= 0.999: return point
	return null

func magic_destination(body: PhysicsBody3D, target: Dictionary) -> Variant:
	if target.is_empty(): return null
	var direction: Vector3 = target.direction.normalized()
	if not direction.is_finite() or direction.length_squared() < 0.9: return null
	var desired: Vector3 = target.point - direction * (profile.impact_runup if target.surface else 0.0)
	var space := get_world_3d().direct_space_state
	# Surface casts stop on the approach side, with a runway for an actual impact.
	# Each fallback is checked from the same free point; never hop through a wall.
	for back in [0.0,1.5,3.0,5.0]:
		var candidate: Vector3 = desired - direction * float(back)
		if body.global_position.distance_to(candidate) < 2.0: continue
		if not space.intersect_shape(sphere_query(body,candidate,0.76),1).is_empty(): continue
		var path := PhysicsRayQueryParameters3D.create(candidate,target.point - direction * 0.1,3 | 16,[body.get_rid()])
		var obstruction := space.intersect_ray(path)
		if not obstruction.is_empty(): continue
		return candidate
	return null

func magic_dash(player: RavagePlayer, target: Dictionary, requested_speed: float) -> bool:
	if not pending_dash.is_empty(): return false
	var destination: Variant = magic_destination(player,target)
	if destination == null:
		blocked_count += 1; status = "出口空间不足 · 换个方向再释放"; return false
	var direction: Vector3 = target.direction.normalized()
	var speed := clampf(requested_speed,profile.dash_min_speed,profile.max_portal_velocity)
	var origin := player.global_position
	# Keep a bounded second route. Formation and entry happen before relocation.
	var entry := Transform3D(PortalPhysics.frame(Vector3.UP),origin + Vector3.DOWN * 0.73)
	var exit := Transform3D(PortalPhysics.frame(direction),destination - direction * 1.0)
	show_dash(entry,exit)
	pending_dash = {"player":weakref(player),"target":target.duplicate(),"speed":speed,"age":0.0,
		"origin":origin,"destination":destination,"entry":entry,"exit":exit,"velocity":player.velocity}
	player.velocity = Vector3.ZERO
	cue("transit_start",{"body_id":player.get_instance_id(),"entry":entry,"exit":exit,"duration":DASH_FORM_TIME + DASH_ENTER_TIME})
	status = "空间入口形成 · 正在穿门 · 出口与入口将保留"
	return true

func cancel_dash(restore_velocity: bool = true) -> void:
	if pending_dash.is_empty(): return
	var player = pending_dash.player.get_ref()
	if is_instance_valid(player) and restore_velocity: player.velocity = pending_dash.velocity
	pending_dash.clear()
	for gate in dash_gates:
		if is_instance_valid(gate): gate.traversal_enabled = true
	cue("transit_cancel")

func advance_dash(delta: float) -> void:
	if pending_dash.is_empty(): return
	var player: RavagePlayer = pending_dash.player.get_ref()
	if not is_instance_valid(player) or not player.controls_enabled:
		cancel_dash(); return
	pending_dash.age += delta
	if pending_dash.get("stage", "entry") == "exit":
		if pending_dash.age >= DASH_EXIT_TIME:
			player.velocity = pending_dash.output_velocity
			pending_dash.clear()
			for gate in dash_gates: gate.traversal_enabled = true
			cue("transit_release",{"body_id":player.get_instance_id(),"point":player.global_position,"velocity":player.velocity})
		return
	if pending_dash.age < DASH_FORM_TIME + DASH_ENTER_TIME: return
	var destination: Vector3 = pending_dash.destination
	var target: Dictionary = pending_dash.target
	# Recheck at the commit tick: a falling chunk may have blocked the shown exit.
	var validated: Variant = magic_destination(player,target)
	if validated == null or Vector3(validated).distance_to(destination) > 0.1:
		blocked_count += 1; cancel_dash(); status = "出口被遮挡 · 已取消穿门并保留入口"; return
	var speed: float = pending_dash.speed
	var direction: Vector3 = target.direction.normalized()
	var origin: Vector3 = pending_dash.origin
	var entry: Transform3D = pending_dash.entry
	var exit: Transform3D = pending_dash.exit
	pending_dash.stage = "exit"; pending_dash.age = 0.0
	pending_dash.output_velocity = direction * speed
	last_portal_time[player.get_instance_id()] = clock
	player.global_position = destination; player.previous_position = destination
	player.velocity = Vector3.ZERO
	cue("passage",{"kind":"dash","body_id":player.get_instance_id(),"entry":entry,"exit":exit,
		"from":origin,"to":destination,"velocity_out":direction * speed,"speed":speed,
		"input_pose":Transform3D(player.global_basis,origin),"mapped_pose":player.global_transform})
	var facing: Vector3 = -player.camera_rig.global_basis.z
	traversed.emit(player,Basis(Quaternion(facing.normalized(),direction)),speed)
	traversal_count += 1; magic_casts += 1
	status = "空间突进 · %.0f m/s" % speed

func all_gates() -> Array:
	return gates + dash_gates

func contains_gate(gate: PortalComponent) -> bool:
	return all_gates().has(gate)

func gate_is_paired(gate: PortalComponent) -> bool:
	for pair in [gates,dash_gates]:
		if pair.size() != 2 or not pair.has(gate): continue
		return is_instance_valid(pair[0]) and is_instance_valid(pair[1]) and pair[0].valid_surface() and pair[1].valid_surface() and pair[0].traversal_enabled and pair[1].traversal_enabled
	return false

func travel(body: PhysicsBody3D, transform: Transform3D, velocity: Vector3, radius: float, delta: float) -> Dictionary:
	for pair in [gates,dash_gates]:
		var result := travel_pair(pair,body,transform,velocity,radius,delta)
		if not result.is_empty(): return result
	return {}

func travel_pair(pair: Array, body: PhysicsBody3D, transform: Transform3D, velocity: Vector3, radius: float, delta: float) -> Dictionary:
	if pair.size() != 2 or pair[0] == null or pair[1] == null: return {}
	if not pair[0].valid_surface() or not pair[1].valid_surface(): return {}
	if not pair[0].traversal_enabled or not pair[1].traversal_enabled: return {}
	var id := body.get_instance_id()
	if clock - float(last_portal_time.get(id, -100.0)) < profile.portal_cooldown: return {}
	for i in 2:
		detection_checks += 1
		var entry: PortalComponent = pair[i]
		var exit_gate: PortalComponent = pair[1 - i]
		var motion := velocity * delta
		var fraction := PortalPhysics.crossing(entry.global_transform, transform.origin, motion, radius, entry.radius)
		if fraction < 0: continue
		var query := sphere_query(body, transform.origin, radius)
		query.motion = motion * fraction
		# A different solid object before the portal must still block traversal.
		if get_world_3d().direct_space_state.cast_motion(query)[0] < 0.97: continue
		var at := transform.origin + motion * fraction
		var rotation := PortalPhysics.rotation_between(entry.global_basis, exit_gate.global_basis)
		var local := entry.to_local(at)
		var tangent := exit_gate.global_basis * Vector3(-local.x, local.y, 0)
		var destination: Variant = safe_exit(body, exit_gate, tangent, radius)
		last_portal_time[id] = clock
		if destination == null:
			blocked_count += 1; status = "出口受阻：已在入口弹回，请调整 B / A"
			cue("exit_blocked",{"body_id":id,"entry":entry.global_transform,"exit":exit_gate.global_transform})
			return {"blocked": true, "transform": Transform3D(transform.basis, at + entry.global_basis.z * 0.16), "velocity": velocity.bounce(entry.global_basis.z) * 0.5}
		var out := PortalPhysics.velocity_out(velocity, rotation, profile.momentum_multiplier, profile.max_portal_velocity)
		cue("passage",{"kind":"physical","body_id":id,"entry":entry.global_transform,"exit":exit_gate.global_transform,
			"from":at,"to":destination,"velocity_in":velocity,"velocity_out":out,"rotation":rotation,"speed":out.length(),
			"input_pose":transform,"mapped_pose":Transform3D(rotation * transform.basis,destination)})
		traversal_count += 1
		if body is RigidBody3D:
			object_traversals += 1
			body.set_meta("portal_exit_time", clock)
		status = "穿越 %s → %s  /  %.1f m/s" % ["A" if i == 0 else "B", "B" if i == 0 else "A", out.length()]
		traversed.emit(body, rotation, out.length())
		return {"blocked": false, "transform": Transform3D(rotation * transform.basis, destination), "velocity": out, "rotation": rotation}
	return {}

func integrate_body(body: RigidBody3D, state: PhysicsDirectBodyState3D) -> void:
	if body.mass > profile.object_mass_limit or body.freeze: return
	var radius := body_radius(body)
	if radius <= 0 or radius > minf(profile.portal_size * 0.8, 2.5): return
	var result := travel(body, state.transform, state.linear_velocity, radius, state.step)
	if not result.is_empty():
		state.transform = result.transform; state.linear_velocity = result.velocity
		if not result.blocked: state.angular_velocity = result.rotation * state.angular_velocity
		state.sleeping = false
	state.linear_velocity = state.linear_velocity.limit_length(profile.max_portal_velocity)
	# Ordinary fracture debris keeps its existing behaviour. Only player-thrown
	# projectiles or recently portalled debris gain the new kinetic damage path.
	if not body.is_in_group("portal_projectile") and clock - float(body.get_meta("portal_exit_time", -100.0)) > 5: return
	if state.linear_velocity.length() < profile.high_speed_impact_threshold: return
	var query := sphere_query(body, state.transform.origin, radius)
	query.collision_mask = 3
	query.motion = state.linear_velocity * state.step
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(query)
	if fractions[0] >= 1: return
	query.transform.origin += query.motion * minf(1.0, fractions[1] + 0.02)
	query.motion = Vector3.ZERO
	var contact := space.get_rest_info(query)
	if contact.is_empty(): return
	var target = instance_from_id(contact.collider_id)
	if impact.apply(target, contact.point, contact.normal, state.linear_velocity, body.mass, body):
		state.linear_velocity *= 0.88

static func body_radius(body: RigidBody3D) -> float:
	var radius: float = 0
	for child in body.get_children():
		if not child is CollisionShape3D or child.disabled: continue
		var size: float = 0
		if child.shape is SphereShape3D: size = child.shape.radius
		elif child.shape is BoxShape3D: size = child.shape.size.length() * 0.5
		else: return -1 # Complex/connected/convex fragments are deliberately unsupported.
		var scale_factor: float = maxf(child.scale.x, maxf(child.scale.y, child.scale.z))
		radius = maxf(radius, child.position.length() + size * scale_factor)
	return radius
