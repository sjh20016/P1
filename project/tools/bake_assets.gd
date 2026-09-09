extends SceneTree

## Run offline after importing GLBs. All collision/fragment scenes are saved assets.
var count: int = 0
func _initialize() -> void:
	call_deferred("bake")

func own_children(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		# Flatten imported instances so saved prefabs own exactly one visual per mesh.
		child.scene_file_path = ""
		child.owner = owner_root
		own_children(child, owner_root)

func meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(meshes(child))
	return found

func save_scene(node: Node, path: String) -> void:
	node.scene_file_path = ""
	own_children(node, node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	node.free()
	print("BAKED ", path)

func bake_pair(id: String, intact_file: String, broken_file: String) -> void:
	var imported: Node3D = load(broken_file).instantiate()
	root.add_child(imported)
	var fractured := Node3D.new()
	fractured.name = id + "Broken"
	root.add_child(fractured)
	var chunks := meshes(imported)
	assert(chunks.size() >= 3 and chunks.size() <= 6)
	for index in chunks.size():
		var source := chunks[index]
		var transform := source.global_transform
		var center := transform * source.mesh.get_aabb().get_center()
		var body := DebrisPiece.new()
		body.name = "Piece%d" % index
		body.position = center
		body.mass = 4.0
		body.collision_layer = 8
		body.collision_mask = 1
		fractured.add_child(body)
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		visual.mesh = source.mesh
		body.add_child(visual)
		visual.global_transform = transform
		var collision := CollisionShape3D.new()
		collision.shape = source.mesh.create_convex_shape(true, false)
		body.add_child(collision)
		collision.transform = visual.transform
	imported.free()
	var broken_path := "res://scenes/destruction/%s_broken.tscn" % id
	save_scene(fractured, broken_path)
	var segment := DestructibleSegment.new()
	segment.name = id
	segment.broken_scene = load(broken_path)
	segment.label = id
	root.add_child(segment)
	var intact: Node3D = load(intact_file).instantiate()
	intact.name = "IntactVisual"
	segment.add_child(intact)
	var first := true
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.95, 0.49, 0.27)
	accent.emission_enabled = true
	accent.emission = Color(0.28, 0.065, 0.01)
	accent.roughness = 0.85
	for source in meshes(intact):
		source.material_override = accent
		var bounds: AABB = source.global_transform * source.mesh.get_aabb()
		segment.local_bounds = bounds if first else segment.local_bounds.merge(bounds)
		first = false
		var collider := CollisionShape3D.new()
		# Static mesh collision keeps authored openings in hollow segments.
		collider.shape = source.mesh.create_trimesh_shape()
		segment.add_child(collider)
		collider.global_transform = source.global_transform
	save_scene(segment, "res://scenes/destruction/%s.tscn" % id)

func bake() -> void:
	var environment: Node3D = load("res://assets/blender_maps/tower_forest.glb").instantiate()
	environment.name = "StaticTowerForest"
	root.add_child(environment)
	var all_meshes := meshes(environment)
	for visual in all_meshes:
		var body := StaticBody3D.new()
		body.name = "StaticCollision"
		visual.add_child(body)
		var shape := CollisionShape3D.new()
		shape.shape = visual.mesh.create_trimesh_shape()
		body.add_child(shape)
		count += 1
	save_scene(environment, "res://scenes/maps/static_tower_forest.tscn")
	for index in range(1,13):
		var id := "D%02d" % index
		bake_pair(id, "res://assets/destructibles/%s_intact.glb" % id, "res://assets/destructibles/%s_broken.glb" % id)
	bake_pair("D13", "res://assets/destructibles/D13_Beam_Intact.glb", "res://assets/destructibles/D13_Beam_Fractured.glb")
	bake_pair("D14", "res://assets/destructibles/D14_HollowDrum_Intact.glb", "res://assets/destructibles/D14_HollowDrum_Fractured.glb")
	print("BAKE COMPLETE static_colliders=", count)
	quit()
