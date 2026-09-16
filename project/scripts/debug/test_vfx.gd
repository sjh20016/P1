extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/maps/feel_lab.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var p: RavagePlayer = scene.get_node("Player")
	p.controls_enabled = false
	var segment: DestructibleSegment = scene.get_node("TestBlock")
	p.global_position=segment.global_position+Vector3.BACK*8
	segment.break_segment(segment.global_position, Vector3.FORWARD, 60)
	var engaged := Engine.time_scale < 1.0
	var wall_deadline := Time.get_ticks_msec() + 130
	while Time.get_ticks_msec() < wall_deadline:
		await process_frame
	var recovered := is_equal_approx(Engine.time_scale, 1.0)
	print("PASS " if engaged and recovered else "FAIL ", "heavy hit stop engages and recovers in real time")
	var manager: DestructionManager = scene.get_node("DestructionManager")
	var result := 0 if engaged and recovered and manager.event_count == 1 else 1
	print("VFX RESULT failures=", result)
	scene.queue_free()
	await process_frame
	quit(result)
