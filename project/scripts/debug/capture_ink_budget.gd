extends SceneTree

func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	var game = load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.begin()
	var p: RavagePlayer = game.player
	p.controls_enabled = false
	var ink: InkMarks = game.get_node("InkMarks")
	var tower: DestructibleBuilding = game.get_node("StaticTowerForest/B250")
	var bounds := tower.section_bounds[24]
	var face := tower.global_position+Vector3(bounds.get_center().x,bounds.get_center().y,bounds.end.z)
	p.global_position = face+Vector3(0,-2,14)
	p.camera_rig.look_at(face,Vector3.UP)
	await frames(60)
	var contacts: Array[Dictionary] = []
	for i in 768:
		var point := face+Vector3(-4.6+(i%24)*0.4,-8.0+(i/24 as int)*0.5,0)
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.BACK*4,point+Vector3.FORWARD*4,3,[p.get_rid()])
		var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			contacts.append(hit)
			ink.deposit(hit.position,hit.normal,hit.collider,0.17)
	ink.rebuild()
	await frames(120)
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for step in 480:
		await process_frame
		var current := Time.get_ticks_usec()
		times.append(float(current-previous)/1000.0)
		previous=current
		if step%5==0:
			var hit: Dictionary = contacts[step%contacts.size()]
			ink.deposit(hit.position,hit.normal,hit.collider,0.17)
	times.sort()
	var passed: bool = ink.marks.size()==768 and ink.render_batch_count()==24 and game.manager.active_debris.is_empty()
	print("INK BUDGET RENDER ","PASS" if passed else "FAIL"," marks=",ink.marks.size()," batches=",ink.render_batch_count()," fps=",Engine.get_frames_per_second()," frame_p50_ms=",times[times.size()/2]," frame_p95_ms=",times[int(times.size()*0.95)])
	game.queue_free()
	await frames(5)
	quit(0 if passed else 1)
