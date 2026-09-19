extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := find_mesh(child)
		if found:
			return found
	return null

func own(node: Node, owner_root: Node) -> void:
	node.scene_file_path = ""
	for child in node.get_children():
		child.owner = owner_root
		own(child,owner_root)

func bake() -> void:
	var cluster := Node3D.new()
	cluster.name = "InkRubble"
	for i in 4:
		var source: Node3D = load("res://assets/blender_maps/R%02d_Rubble.glb" % (i+1)).instantiate()
		var original := find_mesh(source)
		assert(original != null)
		var shape_mesh: Mesh = original.mesh.duplicate()
		for surface in shape_mesh.get_surface_count():
			shape_mesh.surface_set_material(surface,LivingInkArt.CUT)
		var bounds := shape_mesh.get_aabb()
		var factor := (1.6+0.3*i)/bounds.size[bounds.size.max_axis_index()]
		var piece := DebrisPiece.new()
		piece.name = "Piece%d" % i
		piece.position = Vector3(-1.25 if i%2==0 else 1.25,-1.0 if i<2 else 1.0,0)
		piece.mass = 4.0
		cluster.add_child(piece)
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		visual.mesh = shape_mesh
		visual.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),-bounds.get_center()*factor)
		piece.add_child(visual)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var convex := ConvexPolygonShape3D.new()
		var vertices := shape_mesh.get_faces()
		for n in vertices.size():
			vertices[n] = (vertices[n]-bounds.get_center())*factor
		convex.points = vertices
		collision.shape = convex
		piece.add_child(collision)
		source.free()
	own(cluster,cluster)
	var pack := PackedScene.new()
	assert(pack.pack(cluster)==OK)
	assert(ResourceSaver.save(pack,"res://scenes/destruction/ink_rubble.scn",ResourceSaver.FLAG_COMPRESS)==OK)
	cluster.free()
	print("INK RUBBLE BAKED: four supplied jagged pieces, convex collision")
	quit()
