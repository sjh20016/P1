extends SceneTree

var failures:int=0
var rows:Array[Dictionary]=[]
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1
func frames(n:int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.start_course()
	var p:RavagePlayer=game.player
	p.controls_enabled=false
	game.get_node("ImpactVFX").enabled=false
	var h:GrappleController=p.hooks[0]
	var original_hz:=Engine.physics_ticks_per_second
	for hz in [60,90,120]:
		Engine.physics_ticks_per_second=hz
		game.start_course()
		var c:Node3D=game.course
		c.position.x=1000 # isolate authored course fixtures from the tower forest
		p.controls_enabled=false
		var gate:DestructibleSegment=c.get_node("GateB")
		var anchor:StaticBody3D=c.get_node("AnchorSweep")
		p.global_position=c.global_position+Vector3(-18,55,-108)
		p.velocity=Vector3(35,-45,0)
		await frames(3)
		var ray:=PhysicsRayQueryParameters3D.create(c.global_position+Vector3(0,33,-110),anchor.global_position,3,[p.get_rid()])
		var hit:=p.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==gate,"route B lower swing angle initially blocked at %d Hz" % hz)
		var attach_ray:=PhysicsRayQueryParameters3D.create(p.global_position,anchor.global_position,3,[p.get_rid()])
		var visible:=p.get_world_3d().direct_space_state.intersect_ray(attach_ray)
		check(not visible.is_empty() and visible.collider==anchor,"route B initial upper grapple is visible at %d Hz" % hz)
		if not visible.is_empty(): h.attach_to(visible.position,visible.collider)
		p.controls_enabled=true
		await frames(hz)
		p.controls_enabled=false
		var speed:=p.velocity.length()
		var slash:bool=gate.broken and game.get_node("Telemetry").slashes>0
		check(slash,"real moving taut rope severs course crossbeam at %d Hz" % hz)
		h.release()
		await frames(2)
		hit=p.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==anchor,"route B cut opens previously blocked lower swing angle at %d Hz" % hz)
		check(c.structure_triggered,"severed support starts the bounded canopy reaction")
		rows.append({"physics_hz":hz,"crossbeam_cut":slash,"exit_speed":speed,"slashes":game.get_node("Telemetry").slashes,"finite":p.velocity.is_finite(),"peak_rigidbodies":game.manager.peak_rigidbodies})
	Engine.physics_ticks_per_second=original_hz
	# Input-driven short wall hold and jump, rather than calling the launch helper.
	game.start_course()
	var c:Node3D=game.course
	c.position.x=1000
	p.controls_enabled=false
	p.wall_experiment=true
	p.global_position=c.get_node("WallLab").global_position+Vector3(-2,3,0)
	p.velocity=Vector3(6,-3,0)
	p.camera_rig.rotation=Vector3.ZERO
	await frames(3)
	Input.action_press("wall_hold")
	p.controls_enabled=true
	await frames(36)
	check(p.wall_age<0.15 and p.adhesion_time>0,"Shift briefly holds an actual wall contact")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	Input.action_release("wall_hold")
	check(p.velocity.x < -15 and p.velocity.y>10 and c.wall_launches==1,"Space launches outward from physical wall contact")
	p.controls_enabled=false
	# Shared burst limit prevents rapid alternating hands from doubling the impulse.
	var a:StaticBody3D=c.get_node("AnchorRescue")
	p.global_position=a.global_position+Vector3(0,-25,20)
	p.velocity=Vector3.ZERO
	p.kick_cooldown=0
	h.attach_to(a.global_position,a)
	var first:=p.velocity
	p.hooks[1].attach_to(a.global_position,a)
	check(p.velocity.is_equal_approx(first),"simultaneous dual grab shares a single kick")
	h.intentional_release=true
	h.release()
	check(h.status_text=="ZIP" and p.velocity.is_equal_approx(first),"tap release preserves the snap impulse")
	p.hooks[1].release()
	p.kick_cooldown=0
	h.attach_to(a.global_position,a)
	p.velocity=Vector3(20,0,-20)
	Input.action_press("reel_in")
	for i in 90:
		h.acceleration()
		h.update_input(1.0/120.0)
	Input.action_release("reel_in")
	var before:=p.velocity.length()
	var charge:=h.charge
	h.intentional_release=true
	h.release()
	check(charge>0.7 and h.status_text=="SLINGSHOT" and p.velocity.length()>before+8,"Q reel builds charge and deliberate release adds launch speed")
	h.attach_to(a.global_position,a)
	h.charge=1
	p.release_cooldown=0
	before=p.velocity.length()
	h.release()
	check(is_equal_approx(before,p.velocity.length()),"automatic detach does not spend charge as an unintended boost")
	# Repeated course replacement must disconnect old station callbacks and restore controls.
	for i in 4:
		game.start_course()
		await frames(2)
	p.wall_normal=Vector3.LEFT
	p.perform_wall_launch()
	check(game.course.wall_launches==1 and p.controls_enabled,"course restart leaves one active course and playable controls")
	var file:=FileAccess.open("res://../build/rnd003/course_physics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"));file.close()
	game.queue_free()
	await process_frame
	print("RND COURSE RESULT failures=",failures)
	quit(failures)
