extends SceneTree

const PART_SCRIPT = preload("res://scripts/destruction/destructible_segment.gd")
const RUBBLE = preload("res://scenes/destruction/broken_block.tscn")

func _initialize() -> void:
	call_deferred("bake")

func own(node: Node, owner_root: Node) -> void:
	node.scene_file_path = ""
	for child in node.get_children():
		child.owner = owner_root
		own(child,owner_root)

func save(node: Node, path: String) -> void:
	own(node,node)
	var pack := PackedScene.new()
	assert(pack.pack(node)==OK)
	assert(ResourceSaver.save(pack,path,ResourceSaver.FLAG_COMPRESS)==OK)
	node.free()

func mesh_child(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := mesh_child(child)
		if found:
			return found
	return null

func add_geometry(parent: Node3D, mesh: Mesh, visual_name: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = visual_name
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = mesh.create_trimesh_shape()
	parent.add_child(collision)

func bake() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/maps/buildings")
	var imported: Node3D = load("res://assets/blender_maps/destructible_world.glb").instantiate()
	root.add_child(imported)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/blender_maps/destructible_manifest.json"))
	var world := Node3D.new()
	world.name = "DestructibleTowerForest"
	root.add_child(world)
	var total := 0
	for info: Dictionary in data.buildings:
		var source: Node3D = imported.find_child(info.id,true,false)
		assert(source != null,info.id)
		var intact := mesh_child(source.find_child(info.id+"_Intact",true,false))
		var detail := Node3D.new()
		detail.name = "Sections"
		var boxes: Array[AABB] = []
		for i in int(info.sections):
			var part := mesh_child(source.find_child("%s_S%03d" % [info.id,i],true,false))
			assert(part != null)
			var section := DestructibleSegment.new()
			section.name = "S%03d" % i
			section.label = "%s / %03d" % [info.source_name,i]
			section.broken_scene = RUBBLE
			section.debris_at_hit = true
			section.managed_by_building = true
			section.local_bounds = part.mesh.get_aabb()
			section.collision_layer = 2
			detail.add_child(section)
			add_geometry(section,part.mesh,"IntactVisual")
			boxes.append(section.local_bounds)
			total += 1
		var detail_path := "res://scenes/maps/buildings/%s.scn" % info.id
		save(detail,detail_path)
		var building := DestructibleBuilding.new()
		building.name = info.id
		building.source_name = info.source_name
		building.label = info.source_name
		building.local_bounds = intact.mesh.get_aabb()
		building.sections_scene = load(detail_path)
		building.section_bounds = boxes
		building.position = Vector3(info.position[0],info.position[1],info.position[2])
		building.collision_layer = 2
		world.add_child(building)
		add_geometry(building,intact.mesh,"IntactVisual")
		if total%100<50:
			print("BAKE ",info.id," parts=",total)
	imported.free()
	save(world,"res://scenes/maps/destructible_tower_forest.scn")
	print("FULL WORLD BAKED buildings=",data.buildings.size()," sections=",total)
	quit()
