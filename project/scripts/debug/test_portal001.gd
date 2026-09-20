extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var game: Node3D
var metrics: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); print("FAIL ", message)
	else: print("PASS ", message)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func run() -> void:
	for normal in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		for other in [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD]:
			var rotation := PortalPhysics.rotation_between(PortalPhysics.frame(normal), PortalPhysics.frame(other))
			var incoming: Vector3 = -normal * 63.0
			var output := PortalPhysics.velocity_out(incoming, rotation, 1, 100)
			check(output.is_equal_approx(other * 63), "frame maps inward to outward: %s -> %s" % [normal, other])
	check(PortalPhysics.velocity_out(Vector3(0,-200,0), Basis.IDENTITY, 1.2, 100).length() <= 100.001, "velocity cap")
	check(PortalPhysics.crossing(Transform3D.IDENTITY, Vector3(3,0,2), Vector3(0,0,-4), 0.72, 3.2) < 0, "edge traveller cannot clip rim")
	check(PortalPhysics.crossing(Transform3D.IDENTITY, Vector3(0,0,-2), Vector3(0,0,4), 0.72, 3.2) < 0, "backside cannot enter a portal")
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); game.profile.magic_enabled = false; game.forest_enabled = false; root.add_child(game); current_scene = game
	await frames(8)
	game.impact_vfx.stop_enabled = false
	check(game.player.hooks.is_empty(), "independent Portal loadout has no tentacles")
	check(not game.profile.emergency_portal_enabled, "automatic rescue defaults off")
	check(game.portals.gates[0] != null and game.portals.gates[1] != null, "A playground presets use validated ray placement")
	check(not game.portals.place(Vector3(0,4,0),Vector3.DOWN,1), "overlapping portals rejected")
	var small: StaticBody3D = game.box(Vector3(-35,4,0), Vector3(2,2,1))
	await frames(2)
	check(not game.portals.place(Vector3(-35,4,8),Vector3.FORWARD,0), "small surface cannot support portal aperture")
	small.queue_free()
	game.drop_trial()
	var peak: float = 0
	var horizontal: float = 0
	for i in 480:
		await physics_frame
		peak = maxf(peak,game.player.velocity.length())
		if game.portals.traversal_count > 0: horizontal = maxf(horizontal,Vector2(game.player.velocity.x,game.player.velocity.z).length())
	check(game.portals.traversal_count > 0, "gravity fall crosses A and exits B")
	check(horizontal > 40, "fall becomes horizontal launch above 40 m/s")
	check(game.manager.damage_events >= 2, "launch breaches entrance and rear building walls")
	check(game.manager.active_debris.size() <= 48, "debris respects existing budget")
	metrics["drop"] = {"peak_speed":peak,"horizontal_exit_speed":horizontal,"damage_events":game.manager.damage_events,"traversals":game.portals.traversal_count}
	game.select_station(2); await frames(4)
	game.player.global_position = Vector3(125,4,-9); game.player.velocity = Vector3(0,0,-35)
	var count: int = game.portals.traversal_count
	await frames(16)
	check(game.portals.traversal_count > count and game.player.velocity.x < -20, "physical wall entry turns 90 degrees")
	game.select_station(2); await frames(3)
	Engine.physics_ticks_per_second = 60; game.profile.max_portal_velocity = 140
	await frames(2)
	game.player.global_position = Vector3(125,4,-9); game.player.velocity = Vector3(0,0,-140)
	count = game.portals.traversal_count; await frames(6)
	metrics["fast_60hz"] = {"traversals":game.portals.traversal_count-count,"velocity":str(game.player.velocity)}
	check(game.portals.traversal_count == count + 1 and game.player.velocity.x < -100, "140 m/s traversal remains swept at 60 Hz")
	Engine.physics_ticks_per_second = 120; game.profile.max_portal_velocity = 100
	game.select_station(1); await frames(4)
	var exit_gate: PortalComponent = game.portals.gates[1]
	var blocker: StaticBody3D = game.box(exit_gate.global_position + exit_gate.global_basis.z * 1.2, Vector3(10,10,2))
	await frames(4)
	game.player.global_position = Vector3(65,4,-9); game.player.velocity = Vector3(0,0,-35)
	var blocked: int = game.portals.blocked_count
	await frames(16)
	check(game.portals.blocked_count > blocked, "fully blocked exit safely rejects traversal")
	check(game.player.global_position.z < 0 and game.player.velocity.z > 0, "blocked traveller pushed back at entry")
	blocker.queue_free(); await frames(3)
	game.select_station(4); await frames(3)
	var body: RigidBody3D = game.spawn_projectile(true)
	var initial_spin: float = body.angular_velocity.length()
	count = game.portals.object_traversals
	var object_peak: float = 0
	for i in 1200:
		await physics_frame
		if is_instance_valid(body): object_peak = maxf(object_peak,body.linear_velocity.length())
	check(game.portals.object_traversals >= count + 3, "rigidbody gravity loop repeats without same-frame recursion")
	check(is_instance_valid(body) and absf(body.angular_velocity.length()-initial_spin)<0.1, "angular speed retained through loop")
	check(object_peak <= game.profile.max_portal_velocity + 1, "loop remains below velocity limit (one gravity step tolerance)")
	metrics["loop"] = {"traversals":game.portals.object_traversals-count,"peak_speed":object_peak}
	# Release the loop as a horizontal projectile toward the still-intact D tower.
	var events_before: int = game.manager.damage_events
	game.portals.place(Vector3(0,10,90),Vector3.FORWARD,0)
	await frames(240)
	check(game.manager.damage_events > events_before, "loop projectile release damages a building")
	game.select_station(5); await frames(3)
	check(game.cut.trigger(), "spatial cut accepts connected anchors")
	check(not game.cut.trigger(), "spatial cut cooldown prevents duplicate casting")
	await frames(80)
	check(game.cut.cuts > 0, "slice reaches existing building damage state")
	check(game.zone.active.size() > 0 or game.zone.ruins.size() > 0, "seam cut activates existing collapse machinery")
	check(game.zone.active.size() <= 3, "macro budget remains bounded")
	game.select_station(1); await frames(3)
	var host = game.portals.gates[0].host.get_ref()
	host.position.x += 1; await frames(3)
	check(game.portals.gates[0] == null, "moved supporting surface invalidates portal")
	host.position.x -= 1
	game.select_station(1); await frames(3)
	host = game.portals.gates[0].host.get_ref(); host.collision_layer = 0; await frames(3)
	check(game.portals.gates[0] == null, "destroyed supporting surface invalidates portal")
	host.collision_layer = 1
	game.select_station(0); await frames(3)
	game.player.global_position = Vector3(0,-30,0); game.player.velocity = Vector3(0,-45,0)
	check(game.ability.emergency(), "manual falling rescue creates temporary entrance")
	await frames(20)
	check(game.player.global_position.y > 0, "temporary entrance redirects falling player to prepared exit")
	game.select_station(1); await frames(3)
	game.player.controls_enabled = false
	game.player.global_position = Vector3(100,50,100)
	var heavy: RigidBody3D = game.spawn_projectile(); heavy.mass = 100
	heavy.global_position = Vector3(65,4,-9); heavy.linear_velocity = Vector3(0,0,-35)
	count = game.portals.object_traversals; await frames(20)
	check(game.portals.object_traversals == count, "overweight object cannot traverse")
	metrics["final"] = {"checks":checks,"failures":failures,"damage_events":game.manager.damage_events,"peak_debris":game.manager.peak_rigidbodies,"detection_checks":game.portals.detection_checks}
	var file := FileAccess.open("res://../docs/portal001/test-results.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("RESULT portal001 checks=",checks," failures=",failures.size()," METRICS ",JSON.stringify(metrics))
	game.queue_free(); await frames(5)
	quit(0 if failures.is_empty() else 1)
