extends SceneTree

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:
		failures += 1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func run() -> void:
	var game = load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.begin()
	game.player.controls_enabled = false
	await frames(3)
	var buildings := get_nodes_in_group("buildings")
	check(buildings.size()==358,"all 358 Blender architectural objects are destructible")
	var total := 0
	var invalid := 0
	for b: DestructibleBuilding in buildings:
		total += b.section_bounds.size()
		if b.sections_scene == null or b.section_bounds.is_empty() or b.collision_layer != 2 or is_instance_valid(b.detailed):
			invalid += 1
	check(total==4944 and invalid==0,"4944 pre-authored bands; initial whole-mesh representation")
	var tower: DestructibleBuilding
	for b: DestructibleBuilding in buildings:
		if b.source_name=="Tower_00_STRAIGHT_SHAFT":
			tower=b
	check(tower!=null,"original tower identity preserved")
	var a := tower.global_transform * tower.section_bounds[10].get_center()
	var b := tower.global_transform * tower.section_bounds[14].get_center()
	game.player.global_position = a + Vector3(14,0,0)
	var left: GrappleController = game.player.get_node("LeftHook")
	var right: GrappleController = game.player.get_node("RightHook")
	left.attach_to(a,tower)
	right.attach_to(b,tower)
	check(tower.break_segment(a,Vector3.RIGHT,50),"impact activates tower and breaks only selected band")
	check(tower.sections[10].broken and not tower.sections[14].broken,"adjacent bands remain intact")
	left.update_input(0.01)
	right.update_input(0.01)
	check(not left.active and right.active and right.target==tower.sections[14],"destroyed grapple releases; surviving band preserves other grapple")
	var broken_count := 0
	for section in tower.sections:
		if section.broken:
			broken_count += 1
	check(broken_count==1,"single hit cannot destroy whole tower")
	# Audit EVERY object's interface, including distant towers, bridges, stairs and details.
	for building: DestructibleBuilding in buildings:
		var index := building.section_bounds.size()/2 as int
		var hit := building.global_transform * building.section_bounds[index].get_center()
		building.break_segment(hit,Vector3.RIGHT,50)
		if not building.sections[index].broken:
			invalid += 1
		if game.manager.active_debris.size()>48:
			invalid += 1
		building.restore()
		await frames(1)
	check(invalid==0,"every architectural object accepts local destruction; debris budget respected")
	game.restart_run()
	await frames(3)
	check(tower.collision_layer==2 and not is_instance_valid(tower.detailed),"new run restores original representation")
	check(game.get_node("LaunchDeck") is DestructibleSegment,"launch deck also destructible")
	print("FULL WORLD RESULT failures=",failures," buildings=",buildings.size()," sections=",total)
	game.queue_free()
	await process_frame
	quit(failures)
