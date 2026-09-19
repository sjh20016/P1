extends SceneTree

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.begin()
	var p:RavagePlayer=game.player
	p.get_node("TentacleSweep").spatial_candidates=OS.get_cmdline_user_args().has("--optimized")
	p.controls_enabled=false
	game.get_node("ImpactVFX").enabled=false
	var ink:InkMarks=game.get_node("InkMarks")
	ink.process_mode=Node.PROCESS_MODE_DISABLED
	var buildings:=get_nodes_in_group("buildings")
	var total:=0
	var random:=RandomNumberGenerator.new()
	random.seed=303
	for b:DestructibleBuilding in buildings:
		b.activate()
		for i in random.randi_range(1,3):
			var index:=random.randi_range(0,b.sections.size()-1)
			var section:=b.sections[index]
			if section.break_segment(b.global_transform*b.section_bounds[index].get_center(),Vector3.RIGHT,50): total+=1
		await physics_frame
	game.manager.clear_debris()
	ink.clear_marks()
	ink.process_mode=Node.PROCESS_MODE_INHERIT
	game.get_node("ImpactVFX").enabled=true
	p.global_position=Vector3(0,48,-60)
	p.velocity=Vector3(12,3,-20)
	p.hooks[0].attach_to(game.get_node("Anchor2").global_position,game.get_node("Anchor2"))
	p.hooks[1].attach_to(game.get_node("Anchor3").global_position,game.get_node("Anchor3"))
	p.controls_enabled=true
	for i in 120: await process_frame
	var times:Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now:=Time.get_ticks_usec()
		times.append(float(now-previous)/1000)
		previous=now
	times.sort()
	var row:Dictionary={"active_buildings":buildings.size(),"broken_bands":total,"remaining_destructibles":get_nodes_in_group("destructible").size(),"fps":Engine.get_frames_per_second(),"frame_p50_ms":times[times.size()/2],"frame_p95_ms":times[int(times.size()*0.95)],"rigidbodies":game.manager.active_debris.size(),"ink":ink.marks.size(),"finite":p.velocity.is_finite() and p.global_position.is_finite()}
	print("SEGMENTED STRESS ",JSON.stringify(row))
	var suffix:="optimized" if OS.get_cmdline_user_args().has("--optimized") else "baseline"
	var file:=FileAccess.open("res://../build/rnd003/segmented_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(row,"\t"));file.close()
	game.queue_free()
	await process_frame
	quit()
