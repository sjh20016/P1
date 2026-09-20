extends SceneTree

var game: Node3D
var actor: PortalCharacter
var failures: Array[String] = []
var checks := 0
var rendered := false
const OUTPUT := "res://../docs/portal-character/"

func _initialize() -> void:
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
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate()
	root.add_child(game); current_scene = game; await frames(150)
	actor = game.character
	check(game.canyon.towers.size() == 132,"character loads inside authored destructible canyon")
	check(not game.player.get_node("Core").visible and actor.avatar.visible,"character replaces sphere presentation")
	check(actor.skeleton.get_bone_count() == 21,"21-bone rig imports")
	check(actor.clips.size() == 8 and actor.sockets.size() == 6,"eight actions and six effect anchors import")
	var mesh: MeshInstance3D = actor.avatar.find_children("*","MeshInstance3D",true,false)[0]
	var arrays := mesh.mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(indices.size() / 3 >= 1500 and indices.size() / 3 <= 4000,"triangle budget remains within 1500-4000")
	check(mesh.mesh.get_surface_count() == 1 and mesh.material_override == actor.material,"single nearest-filter pixel material")
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var valid := true
	for i in range(0,weights.size(),4):
		var total := 0.0; var active := 0
		for k in 4:
			total += weights[i+k]
			if weights[i+k] > 0.001: active += 1
		if absf(total - 1) > 0.002 or active > 2: valid = false
	check(valid,"skin weights normalized with at most two influences")
	check(game.player.is_on_floor(),"model soles use existing grounded player proxy")
	await frames(80); check(actor.current_clip == "Idle","grounded player selects idle")
	await capture("06-canyon-idle")
	# Sample exported actions without controller changes; anchors must follow skin.
	actor.set_process(false)
	actor.play_clip("Idle",0); actor.animation.seek(0,true); actor.animation.pause(); await frames(2)
	var rest_hand := actor.socket_position("FX_CastHand")
	var rest_foot := actor.socket_position("FX_Foot_L")
	check(rest_hand.distance_to(actor.global_position) < 2 and rest_foot.distance_to(actor.global_position) < 0.4,"effect anchors are inside correct body regions")
	actor.play_clip("Cast",0); actor.animation.seek(0.4,true); actor.animation.pause(); await frames(2)
	check(rest_hand.distance_to(actor.socket_position("FX_CastHand")) > 0.2,"casting glove and anchor move with arm")
	actor.play_clip("Run",0); actor.animation.seek(0.2,true); actor.animation.pause(); await frames(2)
	check(rest_foot.distance_to(actor.socket_position("FX_Foot_L")) > 0.08,"run deforms leg and attached foot anchor")
	actor.set_process(true)
	Input.action_press("forward"); await frames(25)
	check(actor.current_clip == "Run","movement input drives run animation")
	await capture("07-canyon-run"); Input.action_release("forward")
	game.player.reset_player("character_test"); await frames(100)
	Input.action_press("jump"); game.magic.queue_command("space_down"); await frames(1)
	Input.action_release("jump"); game.magic.queue_command("space_up"); await frames(10)
	check(actor.current_clip == "Jump" and game.player.velocity.y > 0,"short Space jump selects jump clip")
	await frames(95)
	check(actor.current_clip in ["Fall","Land","Idle"],"jump transitions into fall or landing")
	game.magic.queue_command("boost"); await frames(15)
	var body_position: Vector3 = game.player.global_position
	var visual_y := actor.avatar.position.y
	await frames(13)
	check(actor.in_loop and actor.echo.visible and actor.current_clip == "Fall","boost uses skinned falling loop and echo")
	check(absf(actor.avatar.position.y - visual_y) > 0.1,"visible character descends between loop apertures")
	check(game.player.global_position.distance_to(body_position) < 0.01,"cosmetic loop leaves player collider stationary")
	check(not game.magic.loop_actor.echo.visible,"old sphere echo remains hidden")
	await capture("08-canyon-loop")
	game.player.reset_player("character_reset"); await frames(90)
	check(not actor.in_loop and not actor.echo.visible and actor.avatar.position.is_zero_approx(),"reset restores one model at original visual origin")
	check(not actor.material.get_shader_parameter("loop_clip"),"reset removes loop clipping")
	game.presentation.receive("cut_release",{}); await frames(3)
	check(actor.current_clip == "Cut","cut feedback drives cut animation")
	await capture("09-canyon-cut")
	await frames(100); check(actor.current_clip == "Idle","one-shot animation returns to idle")
	game.magic.queue_command("space_down"); await frames(70)
	check(actor.current_clip == "Cast","long Space hover holds casting pose")
	game.magic.queue_command("cancel"); game.magic.queue_command("space_up"); await frames(90)
	check(not actor.in_loop and not actor.echo.visible,"cancel leaves no duplicate character")
	var report := {"checks":checks,"failures":failures,"triangles":indices.size()/3,"bones":21,"rendered":rendered,"clips":actor.clips.keys(),"anchors":actor.sockets.keys()}
	var file := FileAccess.open(OUTPUT + ("rendered-results.json" if rendered else "test-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RESULT portal_character ",JSON.stringify(report))
	game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
