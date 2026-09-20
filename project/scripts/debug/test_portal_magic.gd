extends SceneTree

var game: Node3D
var failures: Array[String] = []
var checks: int = 0
var metrics: Dictionary = {}
var pictures: Array[String] = []

func _initialize() -> void:
	Input.use_accumulated_input = false
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	print("PASS " if condition else "FAIL ",text)
	if not condition: failures.append(text)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := "res://../docs/portal-magic/" + name + ".png"
	root.get_texture().get_image().save_png(path); pictures.append(name)

func key(code: int, pressed: bool) -> void:
	if DisplayServer.get_name() == "headless":
		# Headless DisplayServer cannot capture a mouse. Test the command/state
		# boundary here; the rendered tour independently tests real input routing.
		if code == KEY_SPACE:
			game.magic.queue_command("space_down" if pressed else "space_up")
			if pressed: Input.action_press("jump")
			else: Input.action_release("jump")
		if code == KEY_SHIFT and pressed: game.magic.queue_command("boost")
		if code == KEY_X and pressed: game.magic.queue_command("cancel")
		if code == KEY_R:
			if pressed: Input.action_press("reset")
			else: Input.action_release("reset")
		if code == KEY_F3 and pressed: game.hud.toggle_debug()
		if code == KEY_F4 and pressed: game.toggle_magic()
		if code == KEY_F5 and pressed: game.reload_playground()
		await frames(1); return
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)

func click(button: int, pressed: bool) -> void:
	if DisplayServer.get_name() == "headless":
		if button == MOUSE_BUTTON_LEFT: game.magic.queue_command("aim" if pressed else "fire")
		if button == MOUSE_BUTTON_RIGHT: game.magic.queue_command("charge" if pressed else "cut")
		await frames(1); return
	var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)

func tap(code: int) -> void:
	await key(code,true); await key(code,false)

func aim(point: Vector3) -> void:
	var facing: Vector3 = (point - game.player.global_position - Vector3.UP * 0.5).normalized()
	game.player.camera_rig.rotation = Vector3(asin(facing.y),atan2(-facing.x,-facing.z),0)

func relocate(position: Vector3, target: Vector3) -> void:
	game.player.spawn_position = position; game.player.reset_player("test_setup"); game.portals.clear(); aim(target)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/portal-magic").simplify_path())
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(150)
	if DisplayServer.get_name() == "headless": game.impact_vfx.stop_enabled = false
	await capture("01-action-start")
	check(game.profile.magic_enabled and game.magic.mode == PortalMagic.Mode.FREE,"magic controls are the default")
	check(game.portals.gates[0] == null and game.portals.gates[1] == null,"no manual anchors required at start")
	check(game.player.hooks.is_empty(),"no hidden grapple nodes or rope constraints")
	aim(Vector3(0,12,36.4))
	await click(MOUSE_BUTTON_LEFT,true); await frames(35)
	check(game.magic.guide.stopped and game.magic.guide.hit_surface,"guided preview sweeps into and stops on building")
	await capture("02-guided-exit")
	var source: Vector3 = game.player.global_position
	await click(MOUSE_BUTTON_LEFT,false)
	check(game.portals.magic_casts == 1,"mouse release casts automatic foot-to-exit dash")
	check(game.portals.dash_gates.size() == 2 and game.portals.dash_gates[0].global_position.distance_to(source + Vector3.DOWN * 0.73) < 0.2,"automatic entry is created at feet")
	check(game.player.velocity.length() > 38,"ordinary quick movement already has destructive launch speed")
	metrics["quick_launch_speed"] = game.player.velocity.length()
	await frames(110)
	check(game.manager.damage_events > 0,"quick magic dash drives an actual collision into existing destruction")
	relocate(Vector3(30,35,50),Vector3(30,35,-60))
	game.player.velocity = Vector3(70,-20,0)
	await click(MOUSE_BUTTON_LEFT,true); await frames(16)
	await click(MOUSE_BUTTON_LEFT,false)
	check(game.player.velocity.z < -60 and absf(game.player.velocity.x) < 2,"airborne fast motion redirects towards chosen exit")
	check(game.player.global_position.y > 25,"airborne exit needs no supporting surface")
	var count: int = game.portals.magic_casts
	await click(MOUSE_BUTTON_LEFT,true); await click(MOUSE_BUTTON_LEFT,false)
	check(game.portals.magic_casts == count and game.magic.mode == PortalMagic.Mode.FREE,"early repeat release respects cooldown without leaving aim stuck")
	relocate(Vector3(0,6,148),Vector3(0,12,136.4))
	await tap(KEY_SHIFT); var boost_origin: Vector3 = game.player.global_position
	await frames(170)
	check(game.magic.loop_visuals.size() == 2,"head and feet loop portals exist during acceleration")
	check(game.magic.boost_speed == game.profile.max_portal_velocity,"spatial acceleration reaches but cannot exceed speed cap")
	check(game.player.global_position.distance_to(boost_origin) < 0.05,"charging loop does not jitter/teleport the camera repeatedly")
	await capture("03-acceleration-loop")
	metrics["stored_speed"] = game.magic.boost_speed
	await tap(KEY_SHIFT)
	check(game.magic.mode == PortalMagic.Mode.FREE and game.magic.loop_visuals.is_empty(),"second Shift launches and cleans up acceleration loop")
	check(game.magic.last_launch_speed >= 99,"stored momentum is released at high speed")
	var before: int = game.manager.damage_events; await frames(100)
	check(game.manager.damage_events > before,"charged launch physically damages building")
	relocate(Vector3(30,30,30),Vector3(30,30,-20))
	await tap(KEY_SHIFT); await frames(15)
	var blocker: StaticBody3D = game.box(Vector3(30,30,-30),Vector3(30,30,30))
	await frames(3)
	var retained: float = game.magic.boost_speed; var position: Vector3 = game.player.global_position
	game.magic.launch({"point":Vector3(30,30,-30),"direction":Vector3.FORWARD,"surface":false})
	check(game.magic.mode == PortalMagic.Mode.BOOSTING and game.magic.boost_speed >= retained,"blocked exit preserves stored charge")
	check(game.player.global_position.is_equal_approx(position),"blocked magic destination does not move player into solid")
	blocker.queue_free(); await tap(KEY_X)
	check(game.magic.mode == PortalMagic.Mode.FREE and game.magic.loop_visuals.is_empty(),"cancel clears acceleration and preview state")
	relocate(Vector3(30,18,30),Vector3(30,18,-50))
	game.player.velocity = Vector3.DOWN * 20
	await key(KEY_SPACE,true); await frames(7); await key(KEY_SPACE,false)
	check(game.magic.mode == PortalMagic.Mode.FREE and not game.magic.guide.active,"short Space does not enter cut editor")
	await key(KEY_SPACE,true); await frames(28)
	check(game.magic.mode == PortalMagic.Mode.EDITING and absf(game.player.velocity.y) < 0.01,"long Space gives brief mid-air hover")
	var first_direction: Vector3 = game.magic.guide.direction
	if DisplayServer.get_name() == "headless": game.player.camera_rig.rotation.y -= 0.4
	else:
		var move := InputEventMouseMotion.new(); move.relative = Vector2(180,0); Input.parse_input_event(move)
	await frames(10)
	check(game.magic.guide.direction.distance_to(first_direction) > 0.1,"mouse motion steers travelling cut marker")
	await key(KEY_SPACE,false); var locked: Vector3 = game.magic.cut_point
	check(game.magic.mode == PortalMagic.Mode.MARKED,"release Space locks even an empty-air cut point")
	await frames(30)
	check(game.magic.cut_point.is_equal_approx(locked) and game.magic.guide.point.is_equal_approx(locked),"locked marker remains fixed as player descends")
	check(game.player.velocity.y >= -game.profile.slow_fall_speed - 0.1,"after locking marker player descends slowly")
	await click(MOUSE_BUTTON_RIGHT,true); await frames(180)
	check(is_equal_approx(game.magic.cut_radius,game.profile.cut_max_radius),"right hold expands cut diameter to bounded maximum")
	await click(MOUSE_BUTTON_RIGHT,false); await frames(15)
	check(game.magic.volume.active and game.magic.volume.effects.size() == 2,"release creates two overlapping portals for slice")
	check(game.magic.volume.effects.size() == 2 and game.magic.volume.effects[0].global_position.y > game.magic.volume.effects[1].global_position.y,"slice portals move apart after cast")
	await frames(110)
	check(not game.magic.volume.active and game.magic.volume.effects.is_empty(),"slice portal effects expire with no accumulated nodes")
	# Real building interception and charged area comparison use the same input path.
	relocate(Vector3(65,16,206),Vector3(65,12,188.4)); await frames(3)
	await key(KEY_SPACE,true); await frames(60); await key(KEY_SPACE,false)
	check(game.magic.mode == PortalMagic.Mode.MARKED and game.magic.guide.hit_surface,"building hit automatically locks editor marker")
	await capture("04-cut-locked")
	await click(MOUSE_BUTTON_RIGHT,true); await frames(170); await capture("05-cut-charge")
	await click(MOUSE_BUTTON_RIGHT,false); await frames(20); await capture("06-cut-separation")
	check(game.magic.volume.last_hits > 0,"charged volume cut damages real tower shells")
	check(game.zone.active.size() > 0 or game.zone.pending.size() > 0,"charged seam slice reuses tower-collapse system")
	metrics["charged_slice_hits"] = game.magic.volume.last_hits
	var casts: int = game.magic.volume.casts
	check(not game.magic.volume.request(locked,10) and game.magic.volume.casts == casts,"cut cooldown cannot be bypassed while prior effect plays")
	# Deterministic disk-size footprint comparison on two freshly made small shell targets.
	await frames(110); game.cut.cooldown = 0
	var fixture: Array = []
	for x in [250.0,260.0]:
		var target := DestructibleSegment.new(); target.position = Vector3(x,12,0)
		target.local_bounds = AABB(Vector3(-1,-1,-0.4),Vector3(2,2,0.8))
		var visual := Node3D.new(); visual.name = "IntactVisual"; target.add_child(visual)
		game.add_child(target); fixture.append(target)
	game.magic.volume.center = Vector3(250,12,0); game.magic.volume.radius = 2.4
	var small_hits: int = game.magic.volume.apply_volume()
	check(small_hits == 1 and not fixture[1].broken,"small cut affects only targets inside small radius")
	fixture[0].restore(); game.magic.volume.radius = 14
	var large_hits: int = game.magic.volume.apply_volume()
	check(large_hits == 2,"charged radius has larger actual damage footprint, not only larger VFX")
	metrics["cut_footprint"] = {"small":small_hits,"charged":large_hits}
	for target in fixture: target.queue_free()
	relocate(Vector3(30,18,30),Vector3(30,18,-50)); await tap(KEY_SHIFT); await frames(10)
	await tap(KEY_R)
	check(game.magic.mode == PortalMagic.Mode.FREE and game.magic.boost_speed == 0 and game.magic.loop_visuals.is_empty(),"R cancels boost, hover and effects without restoring stale velocity")
	await tap(KEY_SHIFT); await tap(KEY_F3); await frames(2)
	check(not game.player.controls_enabled and game.magic.mode == PortalMagic.Mode.FREE,"debug focus cancels held magic state")
	await tap(KEY_F3); await tap(KEY_F4)
	check(not game.profile.magic_enabled,"F4 restores classic manual A/B controls")
	await tap(KEY_F4)
	check(game.profile.magic_enabled and game.magic.mode == PortalMagic.Mode.FREE,"F4 returns cleanly to action controls")
	check(game.manager.active_debris.size() <= 48 and game.zone.active.size() <= 3,"destruction budgets remain bounded")
	metrics["magic_casts"] = game.portals.magic_casts
	metrics["mode"] = "command_physics" if DisplayServer.get_name() == "headless" else "rendered_input"
	metrics["engine"] = Engine.get_version_info().string
	metrics["audio"] = AudioServer.get_driver_name()
	metrics["screenshots"] = pictures
	var filename := "test-results.json" if DisplayServer.get_name() == "headless" else "rendered-input-results.json"
	if DisplayServer.get_name() != "headless":
		var sorted: Array = game.frame_ms.duplicate(); sorted.sort()
		metrics["frames"] = sorted.size(); metrics["p95_ms"] = sorted[int(sorted.size()*0.95)]; metrics["max_ms"] = sorted.back()
		var raw := FileAccess.open("res://../docs/portal-magic/rendered-frames-ms.json",FileAccess.WRITE)
		raw.store_string(JSON.stringify(game.frame_ms)); raw.close()
	await tap(KEY_F4); await tap(KEY_F5); game = current_scene; await frames(5)
	check(not game.profile.magic_enabled and game.portals.gates[0] != null,"F5 rebuild preserves classic controls and recreates anchors")
	await tap(KEY_F4); await tap(KEY_F5); game = current_scene; await frames(5)
	check(game.profile.magic_enabled and game.magic.mode == PortalMagic.Mode.FREE and game.portals.gates[0] == null,"F5 rebuild preserves magic controls and clears spells")
	metrics["checks"] = checks; metrics["failures"] = failures
	var file := FileAccess.open("res://../docs/portal-magic/" + filename,FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("RESULT portal_magic ",JSON.stringify(metrics))
	game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
