extends SceneTree

func _initialize() -> void: call_deferred("run")
func frames(n:int) -> void:
	for i in n: await physics_frame
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/rnd003/"+name+".png"))
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.start_course()
	var p:RavagePlayer=game.player
	var h:GrappleController=p.hooks[0]
	var c:Node3D=game.course
	c.assisted_run=true
	p.controls_enabled=false
	c.stage=3
	p.global_position=Vector3(-18,55,-108)
	p.velocity=Vector3(35,-45,0)
	p.camera_rig.look_at(c.get_node("AnchorSweep").global_position,Vector3.UP)
	game.get_node("Telemetry").event("scripted_station_setup",{"stage":4})
	await frames(10)
	print("COURSE B SHOT ",h.shoot()," target=",h.target)
	p.controls_enabled=true
	await frames(90)
	await capture("07-course-sever")
	print("COURSE B beam=",c.get_node("GateB").broken," reaction=",c.structure_triggered," speed=",p.velocity.length())
	h.release()
	p.controls_enabled=false
	c.stage=4
	p.global_position=Vector3(0,48,-160)
	p.velocity=Vector3(0,0,-50)
	p.camera_rig.rotation=Vector3.ZERO
	game.get_node("Telemetry").event("scripted_station_setup",{"stage":5})
	await frames(4)
	p.controls_enabled=true
	await frames(56)
	await capture("08-course-interior")
	print("COURSE C entrance=",c.get_node("ShellFront").broken," position=",p.global_position)
	p.controls_enabled=false
	c.stage=5
	p.global_position=Vector3(5,-121,-199)
	p.velocity=Vector3(0,-24,0)
	p.fall_grace=true
	p.camera_rig.look_at(c.get_node("AnchorRescue").global_position,Vector3.UP)
	game.get_node("Telemetry").event("scripted_station_setup",{"stage":6})
	await frames(10)
	await capture("09-course-fall-grace")
	print("COURSE RESCUE SHOT ",h.shoot()," target=",h.target)
	p.controls_enabled=true
	await frames(180)
	await capture("10-course-recovered")
	print("COURSE RECOVERY count=",game.get_node("Telemetry").recoveries," velocity=",p.velocity)
	h.release()
	p.controls_enabled=false
	c.stage=7
	p.global_position=Vector3(0,-53,-232)
	p.velocity=Vector3(0,0,-55)
	p.camera_rig.rotation=Vector3.ZERO
	game.get_node("Telemetry").event("scripted_station_setup",{"stage":8})
	await frames(4)
	p.controls_enabled=true
	await frames(70)
	await capture("11-course-finish")
	print("COURSE FINAL gate=",c.get_node("FinalGate").broken," complete=",c.completed," speed=",p.velocity.length())
	game.get_node("Telemetry").save_run("res://../build/rnd003/course_stations_playtest.json")
	game.queue_free()
	await process_frame
	quit()
