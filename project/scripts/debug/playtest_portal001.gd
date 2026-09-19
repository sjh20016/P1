extends SceneTree

# Deterministic input-driven rendered tour. This checks playability and visual
# feedback, not a human's enjoyment or willingness to experiment.
var game: Node3D
var observations: Array[Dictionary] = []
var screenshots: Array[String] = []
var errors: Array[String] = []

func _initialize() -> void:
	Input.use_accumulated_input = false
	call_deferred("run")

func key(code: int) -> void:
	var down := InputEventKey.new(); down.physical_keycode = code; down.pressed = true; Input.parse_input_event(down)
	await process_frame
	var up := InputEventKey.new(); up.physical_keycode = code; up.pressed = false; Input.parse_input_event(up)
	await process_frame

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://../docs/portal001/" + name + ".png"
	root.get_texture().get_image().save_png(path)
	screenshots.append(name)

func note(name: String) -> void:
	observations.append({"area":name,"speed":game.player.velocity.length(),"traversals":game.portals.traversal_count,
		"objects":game.portals.object_traversals,"damage":game.manager.damage_events,"cuts":game.cut.cuts,
		"debris":game.manager.active_debris.size(),"macros":game.zone.active.size(),
		"actual_station":game.station,"controls_enabled":game.player.controls_enabled,"mouse_mode":Input.mouse_mode})
	print("TOUR ",JSON.stringify(observations.back()))

func run() -> void:
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(180); await capture("01-start")
	await key(KEY_F6)
	for i in 500:
		await physics_frame
		if game.portals.traversal_count > 0: break
	await capture("02-momentum-exit")
	for i in 360:
		await physics_frame
		if game.manager.damage_events >= 2: break
	note("A gravity -> portal -> building"); await capture("03-breach")
	if game.manager.damage_events < 2: errors.append("Drop failed to breach both walls")
	await key(KEY_2); await frames(30)
	# Shoot A with the real mouse input path from the gameplay camera.
	game.player.camera_rig.rotation = Vector3(0.12,0,0)
	await frames(3)
	var old_gate: int = game.portals.gates[0].get_instance_id()
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true
	Input.parse_input_event(mouse); await frames(3)
	mouse = InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = false; Input.parse_input_event(mouse)
	if game.portals.gates[0] == null or game.portals.gates[0].get_instance_id() == old_gate: errors.append("Mouse placement failed")
	var previous_traversals: int = game.portals.traversal_count
	Input.action_press("forward"); await frames(130); await key(KEY_SPACE); await frames(100); Input.action_release("forward")
	if game.portals.traversal_count <= previous_traversals: errors.append("W/jump horizontal traversal failed")
	note("B movement/jump/mouse placement"); await capture("04-horizontal")
	await key(KEY_3); await frames(30); note("C right-angle layout")
	await key(KEY_4); await frames(30); note("D lower launch layout")
	await key(KEY_L); await frames(1200); note("E gravity loop"); await capture("05-loop")
	await key(KEY_6); await frames(30); await key(KEY_Q); await frames(90)
	note("F spatial cut/collapse"); await capture("06-cut")
	if game.cut.cuts == 0: errors.append("Q cut input failed")
	await key(KEY_7); await frames(60); await key(KEY_T); await frames(30); note("G throw/combination layout")
	await key(KEY_8); await frames(60); note("H destructible tower")
	await key(KEY_F3); await frames(15); await capture("07-debug")
	if not game.hud.debug_panel.visible or game.player.controls_enabled: errors.append("F3 debug focus failed")
	await key(KEY_F3); await key(KEY_ESCAPE); await frames(3)
	if game.player.controls_enabled: errors.append("Escape failed to release player controls")
	await key(KEY_ESCAPE); await frames(3)
	var tour_frames: Array[float] = game.frame_ms.duplicate()
	await key(KEY_F5); await frames(90)
	game = current_scene
	if game.manager.damage_events != 0 or game.portals.traversal_count != 0: errors.append("F5 failed to reset world")
	await key(KEY_F6); await frames(520); note("reset and repeat launch")
	if game.manager.damage_events < 2: errors.append("Repeated drop failed after reset")
	tour_frames.append_array(game.frame_ms)
	var raw := FileAccess.open("res://../docs/portal001/rendered-frames-ms.json",FileAccess.WRITE)
	raw.store_string(JSON.stringify(tour_frames)); raw.close()
	var samples: Array[float] = tour_frames.duplicate(); samples.sort()
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"audio_driver":AudioServer.get_driver_name(),"display":DisplayServer.get_name(),
		"tour":observations,"errors":errors,"screenshots":screenshots,"human_fun_validated":false,
		"frames":samples.size(),"p95_ms":samples[int(samples.size()*0.95)],"max_ms":samples.back()}
	var file := FileAccess.open("res://../docs/portal001/rendered-playtest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RESULT rendered_portal001 ",JSON.stringify(report))
	game.queue_free(); await frames(8); quit(0 if errors.is_empty() else 1)
