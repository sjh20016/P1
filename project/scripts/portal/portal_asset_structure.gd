class_name PortalAssetStructure
extends DestructibleSegment

# Original authored appearance is cheap to draw. Decode the spatial damage cells
# only on first impact, and merge surviving triangles back into one mesh/body.
var visual: MeshInstance3D
var collision: CollisionShape3D
var arrays: Array
var original_arrays: Array
var cells: Array[Dictionary] = []
var source_triangles := PackedInt32Array()
var removed := PackedByteArray()
var encoded := PackedByteArray()
var decoded_size: int
var near := false
var damage_revision := 0
var cell_count_removed := 0
var material: StandardMaterial3D
var rebuild_us := 0
var neighbors: Array = []
var grounded := PackedByteArray()
var anchors: Array[int] = []
var fracture_field: PortalFractureField

static func vector_array(bytes: PackedByteArray) -> PackedVector3Array:
	var data := bytes.to_float32_array()
	var result := PackedVector3Array(); result.resize(data.size() / 3)
	for i in result.size(): result[i] = Vector3(data[i * 3],data[i * 3 + 1],data[i * 3 + 2])
	return result

static func read_arrays(source, count: int) -> Array:
	var result: Array = []; result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vector_array(source.get_buffer(count * 12) if source is FileAccess else source.get_data(count * 12)[1])
	result[Mesh.ARRAY_NORMAL] = vector_array(source.get_buffer(count * 12) if source is FileAccess else source.get_data(count * 12)[1])
	var bytes: PackedByteArray = source.get_buffer(count * 16) if source is FileAccess else source.get_data(count * 16)[1]
	var data := bytes.to_float32_array()
	var colors := PackedColorArray(); colors.resize(count)
	for i in count: colors[i] = Color(data[i * 4],data[i * 4 + 1],data[i * 4 + 2],data[i * 4 + 3])
	result[Mesh.ARRAY_COLOR] = colors
	return result

func _ready() -> void:
	super._ready(); managed_by_building = true; destruction_threshold = 26
	visual = MeshInstance3D.new(); visual.name = "IntactVisual"; add_child(visual)
	collision = CollisionShape3D.new(); add_child(collision)
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original_arrays)
	mesh.surface_set_material(0,material); visual.mesh = mesh; local_bounds = mesh.get_aabb()
	collision_layer = 0; collision_mask = 0
	fracture_field = get_tree().get_first_node_in_group("portal_fracture_field")

func bounds_distance(point: Vector3) -> float:
	var p := to_local(point)
	return p.distance_to(p.clamp(local_bounds.position,local_bounds.end))

func set_near(value: bool) -> void:
	if value == near: return
	near = value
	if value: rebuild_collision()
	else: collision_layer = 0; collision.shape = null

func decode_cells() -> void:
	if not cells.is_empty(): return
	var stream := StreamPeerBuffer.new()
	stream.data_array = encoded.decompress(decoded_size,FileAccess.COMPRESSION_GZIP)
	arrays = read_arrays(stream,stream.get_u32())
	var mapping: PackedByteArray = stream.get_data(arrays[Mesh.ARRAY_VERTEX].size() / 3 * 4)[1]
	source_triangles = mapping.to_int32_array()
	var count := stream.get_u32()
	for i in count:
		var lo := Vector3(stream.get_float(),stream.get_float(),stream.get_float())
		var hi := Vector3(stream.get_float(),stream.get_float(),stream.get_float())
		cells.append({"bounds":AABB(lo,hi - lo),"start":stream.get_u32(),"count":stream.get_u32()})
	removed.resize(count); removed.fill(0); encoded.clear()
	build_support()

func build_support() -> void:
	var bins: Dictionary = {}; neighbors.resize(cells.size())
	var bottom := INF
	for i in cells.size():
		var bounds: AABB = cells[i].bounds; bottom = minf(bottom,bounds.position.y)
		var key := Vector3i((bounds.get_center()/8).floor())
		if not bins.has(key): bins[key] = []
		bins[key].append(i); neighbors[i] = []
	for i in cells.size():
		var bounds: AABB = cells[i].bounds
		if bounds.position.y <= bottom+.25: anchors.append(i)
		var key := Vector3i((bounds.get_center()/8).floor())
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					for j in bins.get(key+Vector3i(x,y,z),[]):
						if j != i and bounds.grow(.10).intersects(cells[j].bounds.grow(.10)): neighbors[i].append(j)
	grounded = supported_cells()

func supported_cells() -> PackedByteArray:
	var seen := PackedByteArray(); seen.resize(cells.size()); seen.fill(0)
	var queue: Array[int] = []
	for index in anchors:
		if removed[index] == 0: queue.append(index); seen[index] = 1
	var at := 0
	while at < queue.size():
		var index: int = queue[at]; at += 1
		for j in neighbors[index]:
			if removed[j] == 0 and seen[j] == 0: seen[j] = 1; queue.append(j)
	return seen

func detach(indices: Array[int], event, structural: bool) -> int:
	var accepted := 0; var groups: Dictionary = {}
	for index in indices:
		var span := Vector3(64,32,64) if structural else Vector3(16,16,16)
		var key := Vector3i(((cells[index].bounds.get_center()+Vector3(span.x*.5,0,span.z*.5))/span).floor())
		if not groups.has(key): groups[key] = []
		groups[key].append(index)
	for group: Array in groups.values():
		for start in range(0,group.size(),8):
			var batch: Array[int] = []; batch.assign(group.slice(start,mini(group.size(),start+8)))
			if is_instance_valid(fracture_field) and not fracture_field.enqueue(self,batch,event,structural):
				# Simulation saturation must never make a newly hit wall invulnerable.
				# Secondary structure stays static until the next damage evaluation.
				if structural: continue
				fracture_field.visual_fallbacks += batch.size()
			for index in batch: removed[index] = 2 if structural else 1; accepted += 1
	return accepted

func receive_damage(event) -> Dictionary:
	if event.energy < destruction_threshold: return {"changed":false}
	var started := Time.get_ticks_usec()
	decode_cells()
	var point := to_local(event.position)
	var selected: Array[int] = []
	for i in cells.size():
		if removed[i] != 0: continue
		var b: AABB = cells[i].bounds
		var hit: bool
		if event.context.has("asset_disk"):
			hit = PortalCutGeometry.contact(b,global_transform,event.context.asset_center,event.normal,event.context.asset_radius,event.radius) != null
		else:
			hit = point.distance_to(point.clamp(b.position,b.end)) <= maxf(1.8,event.radius)
		if hit: selected.append(i)
	var count := detach(selected,event,false)
	if count == 0: return {"changed":false}
	var supported := supported_cells(); var loose: Array[int] = []
	for i in cells.size():
		if removed[i] == 0 and grounded[i] != 0 and supported[i] == 0: loose.append(i)
	var severed := detach(loose,event,true)
	cell_count_removed += count+severed; damage_revision += 1
	rebuild_visual(); rebuild_collision()
	rebuild_us = Time.get_ticks_usec() - started
	var manager: DestructionManager = get_tree().get_first_node_in_group("destruction_manager")
	manager.emit_broken(broken_scene,Transform3D(Basis.IDENTITY,event.position),event.position,event.direction,event.energy)
	return {"changed":true,"removed":count,"severed":severed,"bond_broken":severed>0,"boost":false,"asset_fracture":true}

func fragment_mesh(indices: Array[int]) -> Dictionary:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var colors := PackedColorArray()
	var inner := PackedVector3Array(); var inner_normals := PackedVector3Array()
	var edges: Dictionary = {}; var bounds: AABB = cells[indices[0]].bounds
	for index in indices:
		bounds = bounds.merge(cells[index].bounds)
		for start in range(cells[index].start,cells[index].start+cells[index].count,3):
			var tri: Array[Vector3] = []; var ns: Array[Vector3] = []
			for k in 3:
				var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][start+k]; var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][start+k]
				tri.append(v); ns.append(n); vertices.append(v); normals.append(n); colors.append(arrays[Mesh.ARRAY_COLOR][start+k])
			for k in [2,1,0]: inner.append(tri[k]-ns[k]*.22); inner_normals.append(-ns[k])
			for k in 3:
				var a := tri[k]; var b := tri[(k+1)%3]
				var ka := str(Vector3i((a*1000).round())); var kb := str(Vector3i((b*1000).round()))
				var key := ka+":"+kb if ka<kb else kb+":"+ka
				if edges.has(key): edges.erase(key)
				else: edges[key] = [a,b,ns[k],ns[(k+1)%3]]
	for edge: Array in edges.values():
		var a: Vector3 = edge[0]; var b: Vector3 = edge[1]; var c: Vector3 = b-edge[3]*.22; var d: Vector3 = a-edge[2]*.22
		var n := (b-a).cross(d-a).normalized()
		for v in [a,b,c,a,c,d]: inner.append(v); inner_normals.append(n)
	var outer: Array = []; outer.resize(Mesh.ARRAY_MAX)
	outer[Mesh.ARRAY_VERTEX] = vertices; outer[Mesh.ARRAY_NORMAL] = normals; outer[Mesh.ARRAY_COLOR] = colors
	var core: Array = []; core.resize(Mesh.ARRAY_MAX); core[Mesh.ARRAY_VERTEX] = inner; core[Mesh.ARRAY_NORMAL] = inner_normals
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,outer); mesh.surface_set_material(0,material)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,core); mesh.surface_set_material(1,fracture_field.core_material)
	return {"mesh":mesh,"bounds":bounds}

func surviving_arrays() -> Array:
	var result: Array = []; result.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var colors := PackedColorArray()
	var dirty := PackedByteArray(); dirty.resize(original_arrays[Mesh.ARRAY_VERTEX].size() / 3); dirty.fill(0)
	for i in cells.size():
		if removed[i] == 0: continue
		for triangle in range(cells[i].start / 3,(cells[i].start + cells[i].count) / 3): dirty[source_triangles[triangle]] = 1
	# Keep untouched source polygons coarse. Refine only the few polygons touched
	# by holes, so one hit does not multiply the entire tower's BVH and draw cost.
	var begin := -1
	for triangle in dirty.size() + 1:
		if triangle < dirty.size() and dirty[triangle] == 0:
			if begin < 0: begin = triangle * 3
		elif begin >= 0:
			vertices.append_array(original_arrays[Mesh.ARRAY_VERTEX].slice(begin,triangle * 3))
			normals.append_array(original_arrays[Mesh.ARRAY_NORMAL].slice(begin,triangle * 3))
			colors.append_array(original_arrays[Mesh.ARRAY_COLOR].slice(begin,triangle * 3)); begin = -1
	for i in cells.size():
		if removed[i] != 0: continue
		var start: int = cells[i].start / 3; var end: int = start + int(cells[i].count) / 3
		for triangle in range(start,end):
			if dirty[source_triangles[triangle]] == 0: continue
			vertices.append_array(arrays[Mesh.ARRAY_VERTEX].slice(triangle * 3,triangle * 3 + 3))
			normals.append_array(arrays[Mesh.ARRAY_NORMAL].slice(triangle * 3,triangle * 3 + 3))
			colors.append_array(arrays[Mesh.ARRAY_COLOR].slice(triangle * 3,triangle * 3 + 3))
	result[Mesh.ARRAY_VERTEX] = vertices; result[Mesh.ARRAY_NORMAL] = normals; result[Mesh.ARRAY_COLOR] = colors
	return result

func rebuild_visual() -> void:
	var remaining := surviving_arrays()
	var mesh := ArrayMesh.new()
	if not remaining[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,remaining); mesh.surface_set_material(0,material)
	visual.mesh = mesh

func rebuild_collision() -> void:
	collision_layer = 0; collision.shape = null
	if not near or visual.mesh.get_surface_count() == 0: return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	collision.shape = shape; collision_layer = 2
