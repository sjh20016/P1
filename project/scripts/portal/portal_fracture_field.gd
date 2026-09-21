class_name PortalFractureField
extends Node3D

const ACTIVE_LIMIT := 24
const FROZEN_LIMIT := 160
const QUEUE_LIMIT := 64
var pieces: Array[PortalFracturePiece] = []
var pending: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var manager: DestructionManager
var age := 0.0
var peak_active := 0
var emitted := 0
var frozen_total := 0
var impact_total := 0
var build_peak_us := 0
var visual_fallbacks := 0
var lock_pulses: Array[Dictionary] = []
var core_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("portal_fracture_field")
	manager = get_tree().get_first_node_in_group("destruction_manager")
	core_material = StandardMaterial3D.new(); core_material.albedo_color = Color(.24,.28,.31)
	core_material.roughness = 1; core_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func active_count() -> int:
	var count := 0
	for piece in pieces:
		if is_instance_valid(piece) and not piece.settled: count += 1
	return count

func can_wake() -> bool: return active_count() < ACTIVE_LIMIT

func enqueue(source: PortalAssetStructure, indices: Array[int], event, structural: bool) -> bool:
	if indices.is_empty() or pending.size() >= QUEUE_LIMIT: return false
	pending.append({"source":weakref(source),"indices":indices.duplicate(),"direction":event.direction,
		"hit":event.position,"energy":event.energy,"depth":event.depth,"structural":structural,
		"slice":event.context.has("asset_disk")})
	return true

func _physics_process(delta: float) -> void:
	age += delta
	pieces = pieces.filter(func(p): return is_instance_valid(p) and not p.is_queued_for_deletion())
	# Conversion is spread over ticks; a blast never creates dozens of convex bodies at once.
	var started := Time.get_ticks_usec()
	for i in 2:
		if pending.is_empty(): break
		if active_count() >= ACTIVE_LIMIT: break
		build_piece(pending.pop_front())
		if Time.get_ticks_usec()-started > 3500: break
	peak_active = maxi(peak_active,active_count())
	var ready := contacts.duplicate(); contacts.clear()
	for hit in ready:
		var source = hit.source.get_ref(); var target = hit.target.get_ref()
		if not is_instance_valid(source) or not is_instance_valid(target): continue
		var event := RavageDamageEvent.new(); event.type = RavageDamageEvent.Type.COLLAPSE
		event.position = hit.point; event.direction = hit.velocity.normalized(); event.normal = -event.direction
		event.energy = clampf(hit.velocity.length()*3,26,70); event.radius = 2.0
		event.depth = source.depth+1; event.source_id = source.get_instance_id()
		if manager.apply_damage(target,event).get("changed",false): impact_total += 1
	for i in range(lock_pulses.size()-1,-1,-1):
		var pulse: Dictionary = lock_pulses[i]; pulse.age += delta
		pulse.node.scale = Vector3.ONE*(1+pulse.age*2)
		if pulse.age > .35: pulse.node.queue_free(); lock_pulses.remove_at(i)
	# Settled colliders sleep outside the local play space but their silhouettes remain.
	if int(age*5) != int((age-delta)*5):
		var player := get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): return
		for p in pieces:
			if p.settled: p.collision_layer = 16 if p.global_position.distance_to(player.global_position) < 170 else 0

func queue_contact(piece: PortalFracturePiece, target: PortalAssetStructure) -> void:
	if contacts.size() >= 4: return
	# Authored structures currently have translation-only transforms.
	var point := target.to_global(target.to_local(piece.global_position).clamp(target.local_bounds.position,target.local_bounds.end))
	contacts.append({"source":weakref(piece),"target":weakref(target),"point":point,"velocity":piece.linear_velocity})

func build_piece(job: Dictionary) -> void:
	var source: PortalAssetStructure = job.source.get_ref()
	if not is_instance_valid(source): return
	var started := Time.get_ticks_usec()
	var mesh_data := source.fragment_mesh(job.indices)
	var body := PortalFracturePiece.new(); body.field = self; body.depth = job.depth
	var bounds: AABB = mesh_data.bounds
	var center := bounds.get_center()
	body.local_bounds = AABB(bounds.position-center,bounds.size)
	var visual := MeshInstance3D.new(); visual.mesh = mesh_data.mesh; visual.position = -center
	body.add_child(visual)
	# Compound thin boxes follow cells instead of a single hull filling the hollow tower.
	for index in job.indices:
		var cell: AABB = source.cells[index].bounds
		var collider := CollisionShape3D.new(); var box := BoxShape3D.new()
		box.size = cell.size.max(Vector3.ONE*.24); collider.shape = box
		collider.position = cell.get_center()-center; body.add_child(collider)
	body.mass = clampf(bounds.size.length()*4,12,160)
	body.life = 2.6+fmod(float(emitted)*.37,.8)
	add_child(body); body.global_transform = Transform3D(source.global_basis,source.to_global(center))
	var outward: Vector3 = (body.global_position-job.hit).normalized()
	# Eject the cut band first so the upper pieces lose their physical seat too.
	# Slightly different lateral impulses expose the breaks instead of leaving a
	# perfectly aligned stack of independent rigid bodies.
	var kick: float = (8.0 if job.structural else 16.0) if job.slice else clampf(job.energy*.12,3,11)
	var fan := Vector3(cos(emitted*2.4),0,sin(emitted*2.4))
	body.linear_velocity = job.direction.normalized()*kick+fan*(7.0 if job.structural else 5.0)+outward*.7+Vector3.UP*1.4
	body.angular_velocity = Vector3(.35+fmod(emitted*.17,.4),.13,-.32-fmod(emitted*.13,.3))
	pieces.append(body); emitted += 1
	build_peak_us = maxi(build_peak_us,Time.get_ticks_usec()-started)
	while pieces.size() > ACTIVE_LIMIT+FROZEN_LIMIT:
		var oldest: PortalFracturePiece = pieces.pop_front(); oldest.collision_layer = 0; oldest.queue_free()

func on_lock(piece: PortalFracturePiece) -> void:
	frozen_total += 1
	if lock_pulses.size() >= 8: return
	var ring := MeshInstance3D.new(); var mesh := TorusMesh.new()
	mesh.inner_radius = .94; mesh.outer_radius = 1; mesh.rings = 24; mesh.ring_segments = 4
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(.76,.85,.91)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mesh.material = mat; ring.mesh = mesh
	add_child(ring); ring.global_position = piece.global_position
	lock_pulses.append({"node":ring,"age":0.0})
