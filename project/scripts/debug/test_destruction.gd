extends SceneTree

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func run() -> void:
	var world = load("res://scenes/maps/destruction_lab.tscn").instantiate()
	root.add_child(world)
	await frames(3)
	var player: RavagePlayer = world.get_node("Player")
	var segment: DestructibleSegment = world.get_node("TestBlock")
	var manager: DestructionManager = world.get_node("DestructionManager")
	player.controls_enabled = false
	check(not segment.break_segment(segment.global_position, Vector3.FORWARD, 10), "low speed cannot break")
	check(segment.break_segment(segment.global_position, Vector3.FORWARD, 30), "medium speed swaps intact for prefab")
	check(manager.active_debris.size() == 4, "exactly four rigid fragments")
	check(not segment.break_segment(segment.global_position, Vector3.FORWARD, 65), "duplicate break suppressed")
	check(segment.collision_layer == 0 and not segment.get_node("IntactVisual").visible, "intact visual and collision disabled")
	segment.restore()
	await frames(3)
	player.global_position = Vector3(0, 30, -4)
	player.velocity = Vector3(0, 0, -50)
	player.controls_enabled = true
	await frames(25)
	check(segment.broken, "swept high speed player impact breaks target")
	check(player.global_position.z < -12 and player.velocity.z < -40, "player continues moving through broken target")
	for i in 20:
		segment.restore()
		segment.break_segment(segment.global_position, Vector3.UP, 25)
	check(manager.active_debris.size() <= manager.rigidbody_budget, "oldest fragments recycled within budget")
	await frames(650)
	manager.prune()
	check(manager.active_debris.is_empty(), "fragments expire within six seconds")
	print("DESTRUCTION RESULT failures=", failures)
	quit(failures)
