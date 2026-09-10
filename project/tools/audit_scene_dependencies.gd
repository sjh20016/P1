extends SceneTree
func _initialize() -> void:
	for path in ["res://scenes/maps/destructible_tower_forest.scn","res://scenes/maps/buildings/B250.scn","res://scenes/destruction/ink_rubble.scn"]:
		print(path)
		for dependency in ResourceLoader.get_dependencies(path):
			print("  ",dependency)
	quit()
