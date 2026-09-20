extends SceneTree

var game: Node3D
var checks := 0
var failures: Array[String] = []
var rendered := false
const OUT := "res://../docs/portal-skills/"

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func setup() -> void:
	game.player.spawn_position = Vector3(0,130,45); game.player.reset_player("skill_test")
	game.portals.clear(); game.player.velocity = Vector3.ZERO
	game.player.camera_rig.rotation = Vector3(-.12,0,0)
	game.magic.dash_left = 0
func release_right() -> void:
	if rendered:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = true
		Input.parse_input_event(event); await frames(1)
		event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = false
		Input.parse_input_event(event); await frames(1)
	else:
		game.magic.queue_command("aim"); await frames(1); game.magic.queue_command("fire"); await frames(1)

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(120); setup(); await frames(2)
	await release_right()
	check(game.magic.mode == PortalMagic.Mode.TRANSIT,"right mouse release starts staged transit (rendered input)")
	var origin: Vector3 = game.player.global_position
	check(game.portals.dash_gates.size() == 2 and not game.portals.dash_gates[0].traversal_enabled,"two forming gates exist before motion")
	await frames(20)
	check(game.player.global_position.distance_to(origin) < .01 and game.portals.magic_casts == 0,"formation leaves collider at source")
	await capture("01-entry-forms")
	await frames(27)
	check(game.character.avatar.position.y < -.15 and game.character.material.get_shader_parameter("portal_clip"),"actor visibly sinks and clips against entrance")
	check(game.player.global_position.distance_to(origin) < .01,"entrance animation does not pre-teleport player")
	await capture("02-character-enters")
	await frames(47)
	check(game.portals.pending_dash.get("stage","") == "exit","entry completes before exit reveal")
	check(game.player.global_position.distance_to(origin) > 3 and game.player.velocity.length() < .01,"exit shows actor before releasing momentum")
	await capture("03-exit-reveal")
	await frames(18)
	check(game.portals.pending_dash.is_empty() and game.player.velocity.length() > 38,"original movement speed releases after presentation")
	check(not game.character.material.get_shader_parameter("portal_clip"),"completed transit removes skin clipping")
	var pair: Array = game.portals.dash_gates.duplicate()
	await capture("04-release")
	game.player.set_physics_process(false); await frames(150)
	check(game.portals.dash_gates == pair and pair[0].traversal_enabled,"completed pair persists and can be crossed again")
	game.portals.last_portal_time.clear()
	var from: Vector3 = pair[0].global_position+Vector3.UP*2
	var trip: Dictionary = game.portals.travel(game.player,Transform3D(Basis.IDENTITY,from),Vector3.DOWN*40,.72,.1)
	check(not trip.is_empty() and not trip.get("blocked",true),"residual entrance performs real physical traversal")
	game.portals.last_portal_time.clear()
	var remote: PortalComponent = pair[1]
	from = remote.global_position + remote.global_basis.z*2
	trip = game.portals.travel(game.player,Transform3D(Basis.IDENTITY,from),-remote.global_basis.z*40,.72,.1)
	check(not trip.is_empty() and not trip.get("blocked",true),"residual route also works in reverse")
	game.player.global_position = remote.global_position+remote.global_basis.z*12
	var aim: Vector3 = (remote.global_position-game.player.global_position).normalized()
	game.player.camera_rig.rotation = Vector3(asin(aim.y),atan2(-aim.x,-aim.z),0); await frames(2)
	check(game.links.begin_drag(),"residual movement gate supports V drag")
	game.links.finish_drag()
	game.player.set_physics_process(true); setup(); await frames(2)
	game.magic.launch({"point":Vector3(0,130,-15),"direction":Vector3.FORWARD,"surface":false})
	await frames(35); game.magic.cancel(); await frames(2)
	check(game.portals.pending_dash.is_empty() and not game.character.material.get_shader_parameter("portal_clip"),"cancel during entry restores character and motion")
	setup(); await frames(2)
	game.magic.launch({"point":Vector3(0,130,-15),"direction":Vector3.FORWARD,"surface":false})
	await frames(30)
	var blocker: StaticBody3D = game.box(Vector3(0,130,-15),Vector3(20,20,20)); await frames(80)
	check(game.portals.pending_dash.is_empty() and game.player.global_position.z > 30,"exit becoming blocked during animation cancels safely")
	blocker.queue_free(); setup(); await frames(2)
	game.magic.launch({"point":Vector3(0,130,-15),"direction":Vector3.FORWARD,"surface":false})
	await frames(45); game.player.reset_player("mid_transit"); await frames(3)
	check(game.portals.pending_dash.is_empty() and game.character.avatar.position.is_zero_approx(),"R reset cannot complete stale teleport")
	setup(); await frames(2)
	game.magic.launch({"point":Vector3(0,130,-15),"direction":Vector3.FORWARD,"surface":false})
	await frames(90); game.player.reset_player("exit_reset"); await frames(30)
	check(game.portals.pending_dash.is_empty() and game.player.velocity.length() < 15,"reset during exit reveal prevents delayed launch velocity")
	setup(); await frames(2)
	game.magic.launch({"point":Vector3(0,130,-15),"direction":Vector3.FORWARD,"surface":false})
	await frames(12); game.portals.clear(); await frames(100)
	check(game.portals.pending_dash.is_empty() and game.portals.dash_gates.is_empty() and game.player.global_position.z > 30,"recall during formation cancels pending relocation")
	game.player.set_physics_process(false)
	for i in 8:
		game.magic.dash_left = 0
		game.magic.launch({"point":Vector3(0,130,-15-i*3),"direction":Vector3.FORWARD,"surface":false})
		await frames(3); game.magic.cancel()
	check(game.portals.dash_gates.size() == 2,"repeated casts keep a bounded single residual pair")
	game.portals.clear(); await frames(3)
	check(game.portals.dash_gates.is_empty() and game.portals.pending_dash.is_empty(),"recall removes residual portals and pending transitions")
	game.cut.cooldown = 0; game.magic.volume.request(Vector3(0,130,20),4,Vector3.UP)
	await frames(12); await capture("05-cut-ribbon")
	check(game.skill_vfx.effects.size() > 0,"cut release produces ribbon and geometric fragments")
	await frames(240)
	check(game.portals.gates[0] != null and game.portals.gates[0].traversal_enabled,"cut still leaves a usable separated pair")
	var saved: int = game.portals.gates[0].get_instance_id()
	game.magic.dash_left = 0
	game.magic.launch({"point":Vector3(0,130,-55),"direction":Vector3.FORWARD,"surface":false})
	await frames(120)
	check(game.portals.gates[0].get_instance_id() == saved and game.portals.dash_gates.size() == 2,"movement route coexists with persistent cut pair")
	game.cut.cooldown = 0; game.magic.volume.request(Vector3(0,130,10),4,Vector3.UP); await frames(2)
	check(game.portals.dash_gates.size() == 2,"recasting cut preserves the movement route")
	check(game.skill_vfx.peak <= 96,"skill particles respect hard 96-instance budget")
	game.skill_vfx.clear(); await frames(2)
	check(game.skill_vfx.effects.is_empty(),"effect cleanup releases transient geometry")
	var result := {"checks":checks,"failures":failures,"rendered":rendered,"duration_s":.9,"vfx_peak":game.skill_vfx.peak,"active_portal_view_budget":2}
	var file := FileAccess.open(OUT+("rendered-results.json" if rendered else "test-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close(); print("RESULT portal_skill_flow ",JSON.stringify(result))
	game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
