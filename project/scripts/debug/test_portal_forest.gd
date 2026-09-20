extends SceneTree

var game: Node3D
var failures: Array[String] = []
var checks := 0
var metrics: Dictionary = {}
var rendered := false
var output := "res://../docs/portal-forest/"

func _initialize() -> void:
	Input.use_accumulated_input = false
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")

func aim(point: Vector3) -> void:
	var direction: Vector3 = (point - game.player.global_position - Vector3.UP * 0.5).normalized()
	game.player.camera_rig.rotation = Vector3(asin(direction.y),atan2(-direction.x,-direction.z),0)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	if rendered: Input.parse_input_event(event)
	elif code == KEY_SPACE: game.magic.queue_command("space_down" if pressed else "space_up")
	elif code == KEY_V: game.links.handle_input(event)
	await frames(1)

func mouse_move(relative: Vector2) -> void:
	if rendered:
		var event := InputEventMouseMotion.new(); event.relative = relative; Input.parse_input_event(event)
	else: game.magic.pending_rotation += relative
	await frames(2)

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); game.canyon_enabled = false; root.add_child(game); current_scene = game
	await frames(150)
	if not rendered: game.impact_vfx.stop_enabled = false
	check(game.forest_enabled and game.zone.towers.size() == 81,"default scene contains 81 destructible towers")
	check(game.zone.towers.filter(func(t): return t.state.kind == 3).size() == 9,"nine structural towers add collapse to the destructible shells")
	check(game.zone.towers.filter(func(t): return t.near).size() < 81,"remote collision proxies sleep while tower visuals persist")
	await capture("01-tower-forest")
	game.player.global_position = Vector3(0,15,32); game.player.velocity = Vector3.ZERO
	aim(Vector3(0,16,8.4))
	await key(KEY_SPACE,true); await frames(35); await key(KEY_SPACE,false)
	check(game.magic.mode == PortalMagic.Mode.MARKED,"long Space locks a real tower cut target")
	var locked: Vector3 = game.magic.cut_point
	var view: Basis = game.player.camera_rig.global_basis
	await mouse_move(Vector2(90,40))
	check(game.magic.cut_normal.distance_to(Vector3.UP) > 0.3,"mouse rotates locked cut plane")
	check(game.magic.cut_point.is_equal_approx(locked),"rotation preserves cut center")
	check(game.player.camera_rig.global_basis.is_equal_approx(view),"cut editing consumes mouse without spinning camera")
	game.magic.queue_command("charge"); await frames(190)
	await mouse_move(Vector2(40,-25))
	var cut_axis: Vector3 = game.magic.cut_normal
	check(game.magic.cut_radius >= 13,"charge still grows the rotated cut")
	await capture("02-rotated-cut-preview")
	game.magic.queue_command("cut"); await frames(35)
	check(game.magic.volume.last_hits > 0,"rotated cut damages real tower collision geometry")
	check(game.portals.gates[0].global_basis.z.is_equal_approx(cut_axis),"portal orientation matches committed damage plane")
	check(not game.portals.gates[0].traversal_enabled,"separating gates cannot sweep-teleport a player")
	await capture("03-cut-separating")
	await frames(220)
	var gate_a: PortalComponent = game.portals.gates[0]
	var gate_b: PortalComponent = game.portals.gates[1]
	var settled: Transform3D = gate_a.global_transform
	check(gate_a.traversal_enabled and gate_b.traversal_enabled,"both gates become traversable after separation")
	check(is_equal_approx(gate_a.global_position.distance_to(locked),game.profile.cut_separation),"separation stops at the configured distance")
	await frames(600)
	check(is_instance_valid(gate_a) and game.portals.gates[0] == gate_a and gate_a.global_transform.is_equal_approx(settled),"cut gates persist motionless beyond the former effect lifetime")
	await capture("04-persistent-pair")
	# Keep the actual cut-created pair; move it to a clear lane for traversal tests.
	game.player.set_physics_process(false)
	gate_a.global_transform = Transform3D(PortalPhysics.frame(Vector3.BACK),Vector3(180,14,0))
	gate_b.global_transform = Transform3D(PortalPhysics.frame(Vector3.RIGHT),Vector3(180,14,-38))
	game.player.global_position = Vector3(180,14,18); game.player.velocity = Vector3.ZERO
	aim(gate_a.global_position); await frames(15)
	await key(KEY_V,true)
	check(game.links.dragged == gate_a and not gate_a.traversal_enabled,"V picks the cut gate and pauses pair traversal")
	var before_move: Vector3 = gate_a.global_position
	if rendered:
		var motion := InputEventMouseMotion.new(); motion.relative = Vector2(65,0); Input.parse_input_event(motion)
	else: game.player.camera_rig.rotation.y += 0.12
	await frames(4)
	check(gate_a.global_position.distance_to(before_move) > 1,"mouse camera motion repositions held gate")
	var distance: float = game.links.drag_distance
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
	if rendered: Input.parse_input_event(wheel)
	else: game.links.handle_input(wheel)
	await frames(2)
	check(game.links.drag_distance > distance,"scroll changes held gate distance")
	await key(KEY_V,false)
	check(game.links.dragged == null and gate_a.traversal_enabled,"V release fixes gate and restores traversal")
	gate_a.global_transform = Transform3D(PortalPhysics.frame(Vector3.BACK),Vector3(180,14,0))
	game.zone.refresh_interest(); await frames(3)
	var entry := Transform3D(Basis.IDENTITY,gate_a.global_position + Vector3.BACK * 2)
	var trip: Dictionary = game.portals.travel(game.player,entry,Vector3.FORWARD * 40,0.72,0.1)
	check(not trip.is_empty() and trip.get("velocity",Vector3.ZERO).x > 35,"actual cut pair transports player momentum through its rotated exit")
	var projectile: RigidBody3D = game.spawn_projectile()
	projectile.global_position = gate_a.global_position + Vector3.BACK * 4
	projectile.linear_velocity = Vector3.FORWARD * 30; projectile.gravity_scale = 0
	var object_count: int = game.portals.object_traversals
	await frames(40)
	check(game.portals.object_traversals > object_count,"real rigid projectile crosses the cut-generated pair")
	projectile.queue_free()
	var blocker: StaticBody3D = game.box(gate_b.global_position + Vector3.RIGHT * 2,Vector3(6,36,36))
	await frames(3); game.portals.last_portal_time.clear()
	var blocked: Dictionary = game.portals.travel(game.player,entry,Vector3.FORWARD * 40,0.72,0.1)
	check(blocked.get("blocked",false),"blocked exit prevents embedding after gate repositioning")
	blocker.queue_free(); await frames(3)
	# Boost appearance changes while actual player and camera anchors stay stable.
	game.portals.clear(); game.player.global_position = Vector3(19,8,22); aim(Vector3(19,8,-40))
	game.player.set_physics_process(true); game.magic.queue_command("boost"); await frames(2)
	var body_origin: Vector3 = game.player.global_position
	var core: MeshInstance3D = game.player.get_node("Core")
	var first: Vector3 = core.position
	await frames(11)
	check(core.position.distance_to(first) > 0.1,"boost actor visibly falls between loop gates")
	await capture("05-loop-fall-a")
	await frames(10); await capture("06-loop-fall-b")
	await frames(140)
	check(game.magic.loop_actor.cycles >= 3,"cosmetic falling loops repeatedly as charge accelerates")
	check(game.player.global_position.distance_to(body_origin) < 0.05,"cosmetic loop leaves actual character motion stable")
	game.magic.cancel(); await frames(2)
	check(core.transform.is_equal_approx(game.magic.loop_actor.original_pose) and not game.magic.loop_actor.echo.visible,"cancel restores actor mesh and removes wrap copy")
	game.player.set_physics_process(false)
	# Grid axes affect actual retained collision boxes, including vertical cuts.
	var state := OpenDamageState.new()
	var event := RavageDamageEvent.new(); event.type = RavageDamageEvent.Type.SLASH; event.energy = 55
	event.context = {"portal_cells":[{"index":9,"axis":1,"offset":0.0,"remove":false}]}
	state.apply(state.center(9),event)
	check(state.boxes().filter(func(b): return b.has_point(state.center(9))).is_empty(),"vertical slash leaves a real collision gap")
	var part := state.take_upper()
	check(part.cut_axes[9] == 1 and part.cells[9] == 2,"detached chunks preserve vertical slit state")
	var bounds := AABB(Vector3(-1,-1,-1),Vector3(2,2,2))
	check(PortalCutGeometry.contact(bounds,Transform3D.IDENTITY,Vector3.ZERO,Vector3(1,1,1).normalized(),0.2,0.2) != null,"tilted disk intersects box interior")
	check(PortalCutGeometry.contact(bounds,Transform3D.IDENTITY,Vector3(0,4,0),Vector3.UP,20,0.2) == null,"large disk cannot damage a box outside its slab")
	# Every forest building gets a real manager damage call in its own sector.
	var damaged := 0
	for tower in game.zone.towers:
		game.player.global_position = tower.global_position + Vector3.BACK * 25
		game.zone.refresh_interest()
		var hit := RavageDamageEvent.new(); hit.type = RavageDamageEvent.Type.RAM
		var intact: int = tower.state.cells.find(0)
		hit.energy = 60; hit.radius = 2; hit.position = tower.to_global(tower.state.center(intact)); hit.direction = -tower.state.normal(intact / 24)
		if game.manager.apply_damage(tower,hit).get("changed",false): damaged += 1
	check(damaged == 81,"all 81 towers accept actual destructive hits, not only hero towers")
	var remembered: String = game.zone.towers[0].state.signature()
	game.player.global_position = Vector3(152,8,-310); game.zone.refresh_interest()
	check(not game.zone.towers[0].near,"distant damaged tower sleeps")
	game.player.global_position = Vector3(-152,8,30); game.zone.refresh_interest()
	check(game.zone.towers[0].near and game.zone.towers[0].state.signature() == remembered,"revisiting rebuilds collision without healing damage")
	await frames(200)
	# Render a repeatable continuous route through the populated, damaged forest.
	game.frame_ms.clear()
	for tick in 900:
		var t := tick / 899.0
		game.player.global_position = Vector3(19 + sin(t * TAU) * 80,38,-t * 285 + 30)
		aim(game.player.global_position + Vector3(0,-15,-80))
		await physics_frame
	await process_frame
	await capture("07-damaged-forest-route")
	check(game.manager.active_debris.size() <= 48 and game.zone.active.size() <= 3,"forest route respects debris and macro-body budgets")
	metrics = {"checks":checks,"failures":failures,"damaged_towers":damaged,"engine":Engine.get_version_info().string,"rendered":rendered,"audio":AudioServer.get_driver_name()}
	if rendered and game.frame_ms.size() > 5:
		var times: Array = game.frame_ms.duplicate(); times.sort()
		metrics["route_frames"] = times.size(); metrics["route_p95_ms"] = times[int(times.size() * 0.95)]; metrics["route_max_ms"] = times.back()
	var file := FileAccess.open(output + ("rendered-results.json" if rendered else "test-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("RESULT portal_forest ",JSON.stringify(metrics))
	game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
