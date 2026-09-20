extends SceneTree

var game: Node3D
var failures: Array[String] = []
var checks := 0
var metrics: Dictionary = {}
var rendered := false
const OUTPUT := "res://../docs/portal-canyon/"

func _initialize() -> void:
	Input.use_accumulated_input = false; call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func aim(point: Vector3) -> void:
	var direction: Vector3 = (point - game.player.global_position - Vector3.UP * 0.5).normalized()
	game.player.camera_rig.rotation = Vector3(asin(direction.y),atan2(-direction.x,-direction.z),0)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	if rendered: Input.parse_input_event(event)
	elif code == KEY_SPACE: game.magic.queue_command("space_down" if pressed else "space_up")
	elif code == KEY_V: game.links.handle_input(event)
	await frames(1)

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(150)
	if not rendered: game.impact_vfx.stop_enabled = false
	check(is_instance_valid(game.canyon) and game.zone.towers.is_empty(),"default uses authored VerticalCanyon instead of generated tower grid")
	check(game.canyon.structures.size() == 370 and game.canyon.towers.size() == 132,"all 370 authored meshes and 132 tower silhouettes are preserved")
	check(game.player.is_on_floor() and game.player.global_position.y > 30,"authored spawn lands on original porch collision")
	check(game.canyon.structures.all(func(s): return s.cells.is_empty()),"damage geometry remains compressed until first hit")
	check(game.canyon.structures.filter(func(s): return s.near).size() < 370,"distant authored colliders sleep")
	await capture("01-authored-canyon-start")
	# Aim at a real wall polygon, not the author's marker in the hollow center.
	# Let one motion tick discard the porch's old grounded flag after relocation.
	var authored: PortalAssetStructure = game.canyon.get_node("D01_INTACT")
	var authored_vertices: PackedVector3Array = authored.original_arrays[Mesh.ARRAY_VERTEX]
	var authored_normals: PackedVector3Array = authored.original_arrays[Mesh.ARRAY_NORMAL]
	var wall_center := Vector3.ZERO; var wall_normal := Vector3.BACK; var area := 0.0
	for i in range(0,authored_vertices.size(),3):
		if absf(authored_normals[i].y) > 0.5: continue
		var size := (authored_vertices[i + 1] - authored_vertices[i]).cross(authored_vertices[i + 2] - authored_vertices[i]).length_squared()
		if size > area:
			area = size; wall_center = authored.to_global((authored_vertices[i] + authored_vertices[i + 1] + authored_vertices[i + 2]) / 3)
			wall_normal = authored_normals[i]
	game.player.global_position = wall_center + wall_normal * 20 - Vector3.UP * 0.5; game.player.velocity = Vector3.ZERO
	game.canyon.refresh_interest(game.player.global_position); await frames(3); aim(wall_center)
	await key(KEY_SPACE,true); await frames(75); await key(KEY_SPACE,false)
	check(game.magic.mode == PortalMagic.Mode.MARKED and game.magic.guide.hit_surface,"Space guide locks onto authored scene geometry")
	var point: Vector3 = game.magic.cut_point
	if rendered:
		var motion := InputEventMouseMotion.new(); motion.relative = Vector2(65,35); Input.parse_input_event(motion)
	else: game.magic.pending_rotation = Vector2(65,35)
	await frames(2); game.magic.queue_command("charge"); await frames(190)
	check(game.magic.cut_normal.distance_to(Vector3.UP) > 0.3,"mouse rotates cut plane in the authored canyon")
	await capture("02-canyon-rotated-cut")
	game.magic.queue_command("cut"); await frames(35)
	check(game.magic.volume.last_hits > 0,"rotated disk removes authored mesh cells")
	check(game.canyon.structures.any(func(s): return s.damage_revision > 0),"authored geometry records persistent local damage")
	await capture("03-canyon-cut-separation")
	await frames(240)
	var first_pair: PortalComponent = game.portals.gates[0]
	check(first_pair.traversal_enabled and first_pair.global_position.distance_to(point) > 2,"cut pair settles and becomes usable in canyon")
	await frames(300)
	check(game.portals.gates[0] == first_pair,"cut pair persists in authored scene")
	game.player.set_physics_process(false)
	game.portals.gates[0].global_transform = Transform3D(PortalPhysics.frame(Vector3.BACK),Vector3(0,65,-50))
	game.portals.gates[1].global_transform = Transform3D(PortalPhysics.frame(Vector3.BACK),Vector3(0,65,-110))
	game.player.global_position = Vector3(0,65,-30); game.player.velocity = Vector3.ZERO; aim(game.portals.gates[0].global_position)
	game.canyon.refresh_interest(game.player.global_position); await frames(10)
	await key(KEY_V,true)
	check(game.links.dragged == first_pair,"V selects actual persistent cut gate in canyon")
	game.player.camera_rig.rotation.y += 0.12; await frames(5); await key(KEY_V,false)
	check(game.links.dragged == null and first_pair.traversal_enabled,"moving and releasing gate restores passage")
	first_pair.global_transform = Transform3D(PortalPhysics.frame(Vector3.BACK),Vector3(0,65,-50))
	var trip: Dictionary = game.portals.travel(game.player,Transform3D(Basis.IDENTITY,Vector3(0,65,-48)),Vector3.FORWARD * 40,0.72,0.1)
	check(not trip.is_empty() and not trip.get("blocked",true),"persistent pair transports player through clear authored corridor")
	# Replacement midway through separation must not leave the surviving gate disabled.
	game.cut.cooldown = 0
	check(game.magic.volume.request(Vector3(0,80,-60),4,Vector3.RIGHT),"recasting replaces old cut pair")
	await frames(20)
	var survivor: PortalComponent = game.portals.gates[1]
	game.portals.install_gate(0,Vector3(0,80,-35),PortalPhysics.frame(Vector3.BACK))
	await frames(2)
	check(not game.magic.volume.active and survivor.traversal_enabled,"mid-separation gate replacement unfreezes surviving gate")
	game.portals.clear(); await frames(3)
	check(game.portals.gates == [null,null] and not game.magic.volume.active,"recall removes cut pair without resurrecting effects")
	game.player.global_position = Vector3(0,42,-35); aim(Vector3(0,35,-100)); game.player.set_physics_process(true)
	game.magic.queue_command("boost"); await frames(20)
	var actor_y: float = game.player.get_node("Core").position.y
	await capture("04-canyon-falling-loop")
	await frames(11)
	check(absf(game.player.get_node("Core").position.y - actor_y) > 0.05 and game.player.velocity.length() < 0.01,"canyon boost animates actor without moving collider")
	game.player.reset_player("test_loop_reset"); await frames(2)
	check(not game.magic.loop_actor.running and not game.magic.loop_actor.echo.visible,"reset restores normal actor after cosmetic acceleration")
	game.player.set_physics_process(false)
	# Exercise one fresh localized hit on every source tower, including former backdrops.
	var damaged := 0
	var worst_rebuild_us := 0
	for tower: PortalAssetStructure in game.canyon.towers:
		tower.set_near(true); tower.decode_cells()
		var closest := -1; var distance := INF
		for i in tower.cells.size():
			if tower.removed[i] != 0: continue
			var cell: AABB = tower.cells[i].bounds
			var d := absf(tower.to_global(cell.get_center()).y - 20)
			if d < distance: closest = i; distance = d
		var cell: Dictionary = tower.cells[closest]
		var vertices: PackedVector3Array = tower.arrays[Mesh.ARRAY_VERTEX]
		var hit := RavageDamageEvent.new(); hit.type = RavageDamageEvent.Type.RAM; hit.energy = 60; hit.radius = 2
		hit.position = tower.to_global(vertices[cell.start]); hit.direction = Vector3.FORWARD
		if game.manager.apply_damage(tower,hit).get("changed",false): damaged += 1
		worst_rebuild_us = maxi(worst_rebuild_us,tower.rebuild_us)
		await frames(1)
	check(damaged == 132,"all 132 source towers and backdrops support actual local destruction")
	var target: PortalAssetStructure = game.canyon.towers[0]
	var state := target.removed.duplicate(); var revision := target.damage_revision
	target.set_near(false); target.set_near(true)
	check(target.removed == state and target.damage_revision == revision,"collision sleep and wake preserve authored damage holes")
	check(game.manager.active_debris.size() <= 48,"authored destruction uses existing 48-body debris limit")
	await frames(600)
	game.frame_ms.clear()
	for tick in 1200:
		var t := tick / 1199.0
		game.player.global_position = Vector3(sin(t * TAU) * 8,44 + sin(t * PI) * 18,-t * 210)
		aim(game.player.global_position + Vector3(0,-15,-75))
		await physics_frame
	await process_frame; await capture("05-damaged-canyon-route")
	metrics = {"checks":checks,"failures":failures,"damaged_towers":damaged,"source_meshes":370,"load_ms":game.canyon.load_ms,"worst_rebuild_ms":worst_rebuild_us / 1000.0,"rendered":rendered,"engine":Engine.get_version_info().string,"audio":AudioServer.get_driver_name()}
	if rendered:
		var times: Array = game.frame_ms.duplicate(); times.sort()
		metrics["route_frames"] = times.size(); metrics["route_p95_ms"] = times[int(times.size() * 0.95)]; metrics["route_max_ms"] = times.back()
	var file := FileAccess.open(OUTPUT + ("rendered-results.json" if rendered else "test-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("RESULT portal_canyon ",JSON.stringify(metrics))
	game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
