extends SceneTree

func _initialize() -> void:
	call_deferred("run")
func frames(n:int) -> void:
	for i in n: await process_frame
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/rnd003/"+name+".png"))
	print("CAPTURE ",name)
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	await frames(60)
	await capture("01-menu")
	game.start_course()
	await frames(80)
	await capture("02-course-launch")
	var p:RavagePlayer=game.player
	var h:GrappleController=p.hooks[0]
	print("FIRST SHOT ",h.shoot()," ",h.targeting.reason)
	await frames(35)
	await capture("03-hybrid-pull")
	h.intentional_release=true
	h.release()
	p.camera_rig.look_at(game.course.get_node("GateA").global_position,Vector3.UP)
	await frames(20)
	print("GATE SHOT ",h.shoot()," ",h.targeting.reason)
	await frames(90)
	await capture("04-route-ram")
	game.get_node("Telemetry").save_run("res://../build/rnd003/course_first_leg.json")
	game.sweep_practice()
	await frames(12)
	await capture("05-sweep")
	await frames(55)
	print("PRACTICE sweeps=",p.get_node("TentacleSweep").sweep_event_count," speed=",p.velocity.length())
	game.get_node("UI/HUD").debug_enabled=true
	await capture("06-debug")
	game.get_node("Telemetry").save_run("res://../build/rnd003/sweep_playtest.json")
	game.queue_free()
	await frames(5)
	quit()
