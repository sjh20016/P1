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

func receive_damage(event) -> Dictionary:
	if event.energy < destruction_threshold: return {"changed":false}
	var started := Time.get_ticks_usec()
	decode_cells()
	var point := to_local(event.position)
	var count := 0
	for i in cells.size():
		if removed[i] != 0: continue
		var b: AABB = cells[i].bounds
		var hit: bool
		if event.context.has("asset_disk"):
			hit = PortalCutGeometry.contact(b,global_transform,event.context.asset_center,event.normal,event.context.asset_radius,event.radius) != null
		else:
			hit = point.distance_to(point.clamp(b.position,b.end)) <= maxf(1.8,event.radius)
		if hit: removed[i] = 1; count += 1
	if count == 0: return {"changed":false}
	cell_count_removed += count; damage_revision += 1
	rebuild_visual(); rebuild_collision()
	rebuild_us = Time.get_ticks_usec() - started
	var manager: DestructionManager = get_tree().get_first_node_in_group("destruction_manager")
	manager.emit_broken(broken_scene,Transform3D(Basis.IDENTITY,event.position),event.position,event.direction,event.energy)
	return {"changed":true,"removed":count,"severed":0,"bond_broken":false,"boost":false}

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
