extends SceneTree

func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/"+name+".png"))
	print("CAPTURE ",name)
func run() -> void:
	var game = load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.begin()
	var p: RavagePlayer = game.player
	p.controls_enabled = false
	var tower: DestructibleBuilding = game.get_node("StaticTowerForest/B250")
	var bounds := tower.section_bounds[24]
	var face := tower.global_position+Vector3(bounds.get_center().x,bounds.get_center().y,bounds.end.z)
	print("TEST WALL ",face," bounds ",bounds)
	p.global_position = face+Vector3(-4,-2,10)
	p.camera_rig.look_at(face+Vector3.UP,Vector3.UP)
	await frames(60)
	await capture("05-ink-clean")
	var hook: GrappleController = p.hooks[0]
	for i in 5:
		var point := face+Vector3(-4+i*2,sin(float(i)*1.2)*1.5,0)
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.BACK*2,point+Vector3.FORWARD*2,3,[p.get_rid()])
		var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			hook.attach_to(hit.position,hit.collider)
			await frames(18)
			hook.release()
	# Let the real movement/collision signal paint a sliding trace across this wall.
	p.global_position = face+Vector3(-6,5,0.73)
	p.velocity = Vector3(12,0,-5)
	p.controls_enabled = true
	await create_timer(0.6).timeout
	p.controls_enabled = false
	p.velocity = Vector3.ZERO
	p.global_position = face+Vector3(-4,-2,10)
	p.camera_rig.look_at(face+Vector3.UP,Vector3.UP)
	await frames(12)
	await capture("06-ink-wet")
	await create_timer(8.0).timeout
	await capture("07-ink-dry")
	print("INK CAPTURE marks=",game.get_node("InkMarks").marks.size()," fps=",Engine.get_frames_per_second())
	p.global_position = face+Vector3(-5,-6,35)
	p.camera_rig.look_at(face+Vector3.UP*4,Vector3.UP)
	await frames(30)
	await capture("08-tower-before")
	tower.break_segment(face,Vector3.BACK,55)
	await frames(10)
	await capture("09-tower-impact")
	await create_timer(6.0).timeout
	await capture("10-tower-cut")
	print("ART RENDER RESULT events=",game.manager.event_count," marks=",game.get_node("InkMarks").marks.size()," fps=",Engine.get_frames_per_second())
	game.queue_free()
	await frames(5)
	quit()
