extends SceneTree

var failures:int=0
func _initialize() -> void:
	call_deferred("run")
func check(ok:bool,message:String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func frames(n:int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var rows:Array[Dictionary]=[]
	for angle in [0.0,30.0,60.0]:
		var incoming:=Vector3(sin(deg_to_rad(angle))*50,0,-cos(deg_to_rad(angle))*50)
		for weight in 3:
			var after:=ImpactResponse.penetrate(incoming,Vector3.BACK,weight)
			check(absf(after.x-incoming.x*0.99)<0.001,"glancing tangent retained at angle %d weight %d" % [int(angle),weight])
			rows.append({"angle":angle,"weight":weight,"before":50.0,"no_loss":50.0,"uniform_82_percent":41.0,"normal_response_speed":after.length(),"normal_retention":after.z/incoming.z,"tangent_retention":0.99})
	var game=load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.start_course()
	var course:Node3D=game.course
	course.position.x=1000
	var p:RavagePlayer=game.player
	p.controls_enabled=false
	var gate:DestructibleSegment=course.get_node("GateA")
	p.global_position=gate.global_position+Vector3(0,0,12)
	p.velocity=Vector3(0,0,-50)
	await frames(3)
	var anchor:StaticBody3D=course.get_node("AnchorA")
	var space:=p.get_world_3d().direct_space_state
	var ray:=PhysicsRayQueryParameters3D.create(p.global_position,anchor.global_position,3,[p.get_rid()])
	var before:=space.intersect_ray(ray)
	check(not before.is_empty() and before.collider==gate,"route A: wall blocks the shortcut anchor before impact")
	p.controls_enabled=true
	await frames(65)
	p.controls_enabled=false
	check(gate.broken and p.global_position.z<gate.global_position.z,"body impact actually penetrates gate")
	check(game.manager.last_context.kind=="BODY" and game.manager.last_context.after<game.manager.last_context.before and p.velocity.length()>30,"body impact exchanges momentum while preserving flight")
	ray=PhysicsRayQueryParameters3D.create(gate.global_position+Vector3(0,0,10),anchor.global_position,3,[p.get_rid()])
	var after:=space.intersect_ray(ray)
	check(not after.is_empty() and after.collider==anchor,"route A: impact reveals a new usable anchor")
	var h:GrappleController=p.hooks[0]
	check(h.attach_to(after.position,anchor),"route A: re-grapple after penetration")
	h.release()
	# Route C uses an enclosed room and a genuinely occluded anchor.
	var front:DestructibleSegment=course.get_node("ShellFront")
	var inner:StaticBody3D=course.get_node("AnchorInner")
	ray=PhysicsRayQueryParameters3D.create(front.global_position+Vector3(0,0,10),inner.global_position,3,[p.get_rid()])
	before=space.intersect_ray(ray)
	check(not before.is_empty() and before.collider==front,"route C: room anchor initially hidden by front wall")
	front.break_segment(front.global_position,Vector3.FORWARD,50)
	await frames(2)
	after=space.intersect_ray(ray)
	check(not after.is_empty() and after.collider==inner,"route C: broken entrance opens interior movement space")
	# Full map towers remain available well below the old -100 m reset plane.
	p.global_position=Vector3(0,-145,-100)
	p.velocity=Vector3(0,-30,0)
	for i in 20: p.update_fall_recovery(0.1)
	check(p.fall_grace and p.global_position.y<-140,"ordinary fall below old reset depth keeps control")
	var tower:DestructibleBuilding=game.get_node("StaticTowerForest/B250")
	p.global_position=tower.global_position+Vector3(20,-180,0)
	p.velocity=Vector3(0,-24,0)
	p.fall_grace=true
	var recovery_before:int=game.get_node("Telemetry").recoveries
	h.attach_to(p.global_position+Vector3(-12,65,0),tower)
	p.controls_enabled=true
	await frames(180)
	p.controls_enabled=false
	check(game.get_node("Telemetry").recoveries>recovery_before,"grapple turns a dangerous fall upward and records recovery")
	h.release()
	p.global_position=Vector3(10000,-200,10000)
	p.velocity=Vector3.UP*30
	for i in 42: p.update_fall_recovery(0.1)
	check(p.global_position.y==-200,"upward recovery is not interrupted just because the rescue scan is empty")
	p.velocity=Vector3.DOWN*30
	for i in 42: p.update_fall_recovery(0.1)
	check(p.global_position.distance_to(p.spawn_position)<1,"unreachable empty space resets after grace")
	p.wall_normal=Vector3.LEFT
	p.perform_wall_launch()
	check(p.velocity.x < -15 and p.velocity.y>10 and p.velocity.length()<82,"wall launch gives an outward upward impulse")
	var file:=FileAccess.open("res://../build/rnd003/impact_race.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	game.get_node("Telemetry").save_run("res://../build/rnd003/impact_recovery_telemetry.json")
	game.queue_free()
	await process_frame
	print("RND IMPACT RECOVERY RESULT failures=",failures)
	quit(failures)
