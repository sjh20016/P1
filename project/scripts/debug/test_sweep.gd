extends SceneTree

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
func run() -> void:
	var box := AABB(Vector3(-1,-1,-1), Vector3(2,2,2))
	check(SweepGeometry.swept_line_box(Vector3(-10,-5,0),Vector3(10,-5,0),Vector3(-10,5,0),Vector3(10,5,0),box,0.2), "thin target between frames detected")
	check(not SweepGeometry.swept_line_box(Vector3(-10,-5,8),Vector3(10,-5,8),Vector3(-10,5,8),Vector3(10,5,8),box,0.2), "out of plane target rejected")
	var world = load("res://scenes/maps/destruction_lab.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var p: RavagePlayer = world.get_node("Player")
	var h: GrappleController = p.get_node("LeftHook")
	var detector: TentacleSweep = p.get_node("TentacleSweep")
	var target: DestructibleSegment = world.get_node("TestBlock")
	p.controls_enabled = false
	target.global_position = Vector3.ZERO
	p.global_position = Vector3(-10, 4, 0)
	h.attach_to(Vector3(10,0,0), world.get_node("Tower0"))
	h.previous_start = Vector3(-10,-4,0)
	h.previous_end = Vector3(10,0,0)
	h.history_valid = true
	h.tension = 50
	await physics_frame
	await physics_frame
	p.velocity = Vector3(0,5,0)
	detector.check_hook(h, 0.1)
	check(not target.broken, "slow tentacle cannot cut")
	p.velocity = Vector3(0,40,0)
	h.tension = 0
	detector.check_hook(h, 0.1)
	check(not target.broken, "slack tentacle cannot cut")
	h.tension = 50
	h.history_valid = false
	detector.check_hook(h, 0.1)
	check(not target.broken, "new attachment cannot fabricate sweep")
	h.history_valid = true
	detector.check_hook(h, 0.1)
	check(target.broken and detector.sweep_event_count == 1, "fast taut tentacle sweep breaks independent segment")
	detector.check_hook(h, 0.1)
	check(detector.sweep_event_count == 1, "same segment breaks once")
	target.restore()
	detector.check_hook(h, 0.1)
	check(not target.broken, "target cooldown suppresses repeat")
	print("SWEEP RESULT failures=", failures)
	quit(failures)
