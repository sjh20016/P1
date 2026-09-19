extends SceneTree
# Continuous scripted flight workload, not a claim of human playtesting.
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output_dir:=ProjectSettings.globalize_path("res://../build/rnd006").simplify_path()
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://scenes/maps/open_main.tscn").instantiate();root.add_child(game);game.start_open()
	var zone=game.open_zone
	while zone.loading: await process_frame
	game.player.controls_enabled=false
	game.get_node("ImpactVFX").stop_enabled=false
	var start:=Time.get_ticks_msec()
	var previous:=start
	var previous_us:=Time.get_ticks_usec()
	var wall_frames:Array[int]=[]
	var visit:int=0
	var dwell:float=0.0
	var struck:bool=false
	var runtime:int=300000
	if OS.get_cmdline_user_args().has("--quick"): runtime=20000
	var path:Array[int]=[]
	for row in 6:
		for col in 6: path.append(row*6+(col if row%2==0 else 5-col))
	var signatures:Dictionary={}
	var revisits:int=0
	var state_failures:int=0
	while Time.get_ticks_msec()-start<runtime:
		await process_frame
		var now_us:=Time.get_ticks_usec()
		var frame_us:=now_us-previous_us;previous_us=now_us;wall_frames.append(frame_us)
		if frame_us>100000:
			print("FRAME GAP ",JSON.stringify({"wall_seconds":(now_us*0.001-start)*0.001,"frame_ms":frame_us*0.001,"visit":visit,"memory":OS.get_static_memory_usage()}))
		var now:=Time.get_ticks_msec()
		var delta:=minf((now-previous)*0.001,0.05);previous=now
		var tower=zone.towers[path[visit%36]]
		var lap:=visit/36
		var destination:Vector3=tower.to_global(Vector3(0,float(lap%3)*8.0-6,18))
		var offset:Vector3=destination-game.player.global_position
		if offset.length()>1:
			game.player.velocity=offset.normalized()*65
			game.player.global_position=game.player.global_position.move_toward(destination,65*delta)
			game.player.camera_rig.look_at(tower.global_position)
		else:
			game.player.velocity=Vector3.ZERO
			dwell+=delta
			if not struck:
				if signatures.has(tower.state.id):
					revisits+=1
					# Structural chain can legitimately modify another tower between visits.
					if tower.state.revision==signatures[tower.state.id].revision and tower.state.signature()!=signatures[tower.state.id].signature: state_failures+=1
				var event:=RavageDamageEvent.new();event.energy=55;event.type=RavageDamageEvent.Type.SLASH if tower.state.kind==3 or lap%2==1 else RavageDamageEvent.Type.RAM
				event.direction=Vector3.RIGHT if event.type==1 else Vector3.FORWARD
				event.position=tower.to_global(Vector3((lap%3-1)*4,-6 if tower.state.kind==3 else float(lap%3)*8.0-6,8.4))
				game.manager.apply_damage(tower,event)
				signatures[tower.state.id]={"signature":tower.state.signature(),"revision":tower.state.revision}
				struck=true
			if dwell>0.35: visit+=1;dwell=0;struck=false
	var result:Dictionary={"wall_seconds":(Time.get_ticks_msec()-start)*0.001,"visits":visit,"revisits":revisits,"state_failures":state_failures,"final":zone.snapshot(),"audio_driver_note":"See launch command; consumed engine flags cannot identify the driver here.","movement":"scripted continuous flight at 65 m/s; damage via production entry"}
	print("MARATHON RESULT ",JSON.stringify(result))
	# The SceneTree frame signal runs before Node._process. Capture the final frame
	# here too, so a final OS/driver stall cannot disappear when the test exits.
	zone.frames_us=wall_frames
	zone.save_run(output_dir.path_join("marathon-quick.json" if runtime<300000 else "marathon.json"),result)
	game.queue_free()
	for i in 12: await process_frame
	quit(state_failures)
