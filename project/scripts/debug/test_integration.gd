extends SceneTree

var failures: int = 0
var peak: float = 0.0
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
	var game = load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	check(paused and game.menu_open, "start menu safely pauses simulation")
	game.begin()
	await frames(120)
	var p: RavagePlayer = game.player
	var manager: DestructionManager = game.manager
	check(p.is_on_floor() and p.global_position.y > 47, "spawn rests on launch deck")
	check(get_nodes_in_group("destructible").size() == 382, "358 buildings plus 24 independent targets")
	var left: GrappleController = p.get_node("LeftHook")
	var right: GrappleController = p.get_node("RightHook")
	p.camera_rig.look_at(game.get_node("Anchor1").global_position,Vector3.UP)
	await frames(3)
	check(right.shoot(), "camera ray can grab actual map surface")
	right.release()
	game.sweep_practice()
	await frames(60)
	check(p.get_node("TentacleSweep").sweep_event_count >= 1, "practice route performs physical tentacle sweep")
	check(game.get_node("D13").broken, "sweep beam actually fractures in map")
	check(p.velocity.length() > 15, "motion continues after sweep")
	game.restart_run()
	await frames(3)
	check(manager.event_count == 0 and not game.get_node("D13").broken and not left.active and not right.active, "restart restores segments, score and hooks")
	var max_bodies := 0
	var bad_frames := 0
	var max_ink := 0
	var ink: InkMarks = game.get_node("InkMarks")
	var buildings := get_nodes_in_group("buildings")
	# Three simulated minutes of alternating hooks, releases, resets and impacts.
	for step in 21600:
		if step % 480 == 0:
			p.reset_player()
			p.global_position = Vector3(0, 48, -30)
			p.velocity = Vector3(14, -15, -26)
			left.attach_to(game.get_node("Anchor0").global_position,game.get_node("Anchor0"))
		if step % 480 == 150:
			right.attach_to(game.get_node("Anchor1").global_position,game.get_node("Anchor1"))
		if step % 480 == 240:
			left.release()
		if step % 480 == 330:
			right.release()
		if step % 120 == 0:
			var target: DestructibleSegment = game.get_node("D%02d" % (1+(step/120 as int)%14))
			target.restore()
			target.break_segment(target.global_position,Vector3.FORWARD,55)
		if step % 360 == 0:
			var tower: DestructibleBuilding = buildings[(step/360 as int)%buildings.size()]
			var band := tower.section_bounds.size()/2 as int
			tower.break_segment(tower.global_transform*tower.section_bounds[band].get_center(),Vector3.RIGHT,55)
		await physics_frame
		max_bodies = maxi(max_bodies,manager.active_debris.size())
		max_ink = maxi(max_ink,ink.marks.size())
		peak = maxf(peak,p.velocity.length())
		if not p.velocity.is_finite() or not p.global_position.is_finite() or p.velocity.length() > p.profile.max_speed + 0.1:
			bad_frames += 1
	check(bad_frames == 0, "three minute stress run: no NaN or excessive speed")
	check(max_bodies <= 48, "three minute stress run: fragment budget bounded")
	check(max_ink <= ink.mark_budget, "three minute stress run: ink budget bounded")
	await frames(720)
	manager.prune()
	check(manager.active_debris.is_empty(), "all fragments expire after stress run")
	print("INTEGRATION METRICS peak_speed=", peak, " max_rigidbodies=",max_bodies," max_ink=",max_ink," events=",manager.event_count," bad_frames=",bad_frames)
	print("INTEGRATION RESULT failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)
