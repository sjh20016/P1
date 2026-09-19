extends SceneTree
var game
var camera:Camera3D
var results:Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game)
	camera=Camera3D.new();game.add_child(camera);camera.current=true;camera.fov=70
	for scenario in ["domino","all_panels_and_scars","two_macro_burst"]:
		game.start_consequence(2);game.player.controls_enabled=false
		var lab=game.consequence
		camera.global_position=lab.to_global(Vector3(-20,22,36));camera.look_at(lab.to_global(Vector3(20,0,-32)))
		while lab.elapsed<2: await process_frame
		lab.frame_us.clear();lab.metrics.clear()
		if scenario=="all_panels_and_scars":
			for tower in lab.towers: tower.activate_panels()
			for i in 384:
				var panel=lab.towers[i%3].panels[i/3]
				var event:=RavageDamageEvent.new();event.type=i%2;event.energy=55;event.seed=i;event.direction=Vector3.RIGHT
				lab.scars.deposit(panel,event,Vector3.ZERO,panel.face_normal,1.3)
		else:
			for i in ([1,2] if scenario=="two_macro_burst" else [1]):
				var tower=lab.towers[i]
				var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.SLASH;event.energy=55;event.direction=Vector3.RIGHT;event.position=tower.to_global(Vector3(0,0,8.4))
				game.manager.apply_damage(tower,event)
		while lab.elapsed<14: await process_frame
		results.append({"scenario":scenario,"frames_us":lab.frame_us.duplicate(),"samples":lab.metrics.duplicate(true),"macro_activation_us":lab.macros.activation_us.duplicate(),"panel_activation_us":lab.towers.map(func(t):return t.activation_us),"peak_macros":lab.macros.peak,"final":lab.snapshot()})
		print("PERFORMANCE ",scenario," frames=",lab.frame_us.size()," final=",JSON.stringify(lab.snapshot()))
	var file:=FileAccess.open("res://../build/rnd004/performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	game.queue_free()
	for i in 12: await process_frame
	quit()
