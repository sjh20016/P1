class_name PortalFractureField
extends Node3D

const ACTIVE_LIMIT := 48
const FROZEN_LIMIT := 192
const QUEUE_LIMIT := 128
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
var landing_jobs: Array[Dictionary] = []
var landings: Array[StaticBody3D] = []
var landing_material: StandardMaterial3D
var fracture_audio: PortalFractureAudio

func _ready() -> void:
	add_to_group("portal_fracture_field")
	manager = get_tree().get_first_node_in_group("destruction_manager")
	core_material = StandardMaterial3D.new(); core_material.albedo_color = Color(.24,.28,.31)
	core_material.roughness = 1; core_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	landing_material = StandardMaterial3D.new(); landing_material.vertex_color_use_as_albedo = true; landing_material.roughness = 1
	landing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fracture_audio = PortalFractureAudio.new(); add_child(fracture_audio)
	manager.feedback_beat.connect(fracture_audio.feedback)

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
	for i in range(landing_jobs.size()-1,-1,-1):
		if age >= landing_jobs[i].at:
			spawn_landings(landing_jobs[i]); landing_jobs.remove_at(i)
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
	body.prepare_collision(mesh_data.mesh,-center,mesh_data.patches)
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
	if not job.slice:
		# RAM excavates small chunks into a forward cone. Cutting keeps large slabs.
		body.linear_velocity = job.direction.normalized()*clampf(job.energy*.24,9,24)+fan*5+Vector3.UP*3
		body.angular_velocity *= 2.1
	pieces.append(body); emitted += 1
	build_peak_us = maxi(build_peak_us,Time.get_ticks_usec()-started)
	while pieces.size() > ACTIVE_LIMIT+FROZEN_LIMIT:
		var oldest: PortalFracturePiece = pieces.pop_front(); oldest.collision_layer = 0; oldest.queue_free()

func on_lock(piece: PortalFracturePiece) -> void:
	frozen_total += 1
	fracture_audio.settle(piece.global_position)
	if lock_pulses.size() >= 8: return
	var ring := MeshInstance3D.new(); var mesh := TorusMesh.new()
	mesh.inner_radius = .94; mesh.outer_radius = 1; mesh.rings = 24; mesh.ring_segments = 4
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(.76,.85,.91)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mesh.material = mat; ring.mesh = mesh
	add_child(ring); ring.global_position = piece.global_position
	lock_pulses.append({"node":ring,"age":0.0})

func schedule_landings(event) -> void:
	if event.energy < 45 or landing_jobs.size() >= 12: return
	for job in landing_jobs:
		if job.point.distance_to(event.position) < 10: return
	landing_jobs.append({"at":age+4.5,"point":event.position,"normal":event.normal,"seed":emitted+landing_jobs.size()*7})

func spawn_landings(job: Dictionary) -> void:
	for index in 3:
		var points := PackedVector3Array()
		var count: int = 5+(index+int(job.seed))%3
		var radius := 1.6+index*.45
		for corner in count:
			var angle: float = TAU*corner/count+.12*sin(corner*2.1+job.seed)
			var x := cos(angle)*radius*(1.3-index*.2); var z := sin(angle)*radius
			points.append(Vector3(x,0,z))
			points.append(Vector3(x*.55+.25*index,-.65-index*.28,z*.55))
		var shape := ConvexPolygonShape3D.new(); shape.points = points; shape.margin = .015
		var direction: Vector3 = job.normal*Vector3(1,0,1)
		if direction.length_squared() < .1: direction = Vector3.BACK
		direction = direction.normalized().rotated(Vector3.UP,(index-1)*.8)
		var where: Vector3 = job.point+direction*(5+index*2)+Vector3.DOWN*(1.5+index*2)
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.transform.origin = where; query.collision_mask = 3|16|4
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		var portals := get_parent().get("portals") as PortalManager
		var blocked := false
		if is_instance_valid(portals):
			for gate in portals.all_gates():
				if is_instance_valid(gate) and where.distance_to(gate.global_position) < gate.radius+radius+1: blocked = true
		if blocked: continue
		var body := StaticBody3D.new(); body.name = "LandingShard"; body.collision_layer = 16; body.collision_mask = 0
		var visual := MeshInstance3D.new(); visual.mesh = landing_mesh(points); visual.material_override = landing_material
		body.add_child(visual)
		var collider := CollisionShape3D.new(); collider.shape = shape; body.add_child(collider)
		add_child(body); body.global_position = where; landings.append(body)
		while landings.size() > 48:
			var oldest: StaticBody3D = landings.pop_front(); oldest.collision_layer = 0; oldest.queue_free()

func landing_mesh(points: PackedVector3Array) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var colors := PackedColorArray()
	var count := points.size()/2
	var faces: Array = []
	for i in range(1,count-1):
		faces.append([0,(i+1)*2,i*2]); faces.append([1,i*2+1,(i+1)*2+1])
	for i in count:
		var j := (i+1)%count
		faces.append([i*2,j*2,i*2+1]); faces.append([j*2,j*2+1,i*2+1])
	for face in faces:
		var a: Vector3 = points[face[0]]; var b: Vector3 = points[face[1]]; var c: Vector3 = points[face[2]]
		var n := (b-a).cross(c-a).normalized()
		for v in [a,b,c]:
			vertices.append(v); normals.append(n); colors.append(Color(.85,.88,.90) if n.y>.5 else Color(.36,.40,.44))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh
