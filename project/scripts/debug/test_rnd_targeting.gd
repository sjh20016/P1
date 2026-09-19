extends SceneTree

var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func box(world: Node3D,pos: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	body.position=pos
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	world.add_child(body)
	return body
func run() -> void:
	preload("res://scripts/debug/input_setup.gd").install()
	var world:=Node3D.new()
	root.add_child(world)
	var p: RavagePlayer=load("res://scenes/player/player.tscn").instantiate()
	p.controls_enabled=false
	world.add_child(p)
	p.global_position=Vector3(0,12,10)
	var target:=box(world,Vector3(0,12,-45),Vector3(6,16,3))
	var camera: Camera3D=p.get_node("CameraRig/SpringArm3D/Camera3D")
	camera.top_level=true
	camera.global_position=Vector3(0,13,18)
	await physics_frame
	await physics_frame
	var h: GrappleController=p.hooks[0]
	h.profile=h.profile.duplicate()
	var results:Array[Dictionary]=[]
	for model in 3:
		h.profile.targeting_model=model
		var success:=0
		var rays:=0
		var total_us:=0
		for offset in [-7.0,-6.0,-4.0,-2.0,0.0,2.0,4.0,6.0,7.0]:
			camera.look_at(Vector3(offset,12,-45),Vector3.UP)
			var start:=Time.get_ticks_usec()
			var hit:=h.aim_result()
			total_us+=Time.get_ticks_usec()-start
			rays+=h.targeting.ray_count
			if not hit.is_empty() and hit.collider==target: success+=1
		var row:Dictionary={"targeting":model,"hits":success,"attempts":9,"miss_rate":1.0-float(success)/9.0,"rays":rays,"query_us":total_us}
		results.append(row)
		print("TARGET RACE ",JSON.stringify(row))
	if results[2].hits<=results[0].hits: failures+=1
	# Camera can see around this wall, but the player's hand cannot.
	p.global_position=Vector3(0,12,0)
	camera.global_position=Vector3(7,13,8)
	camera.look_at(Vector3(0,12,-45),Vector3.UP)
	var blocker:=box(world,Vector3(0,12,-3),Vector3(5,20,2))
	await physics_frame
	await physics_frame
	var blocked:=h.aim_result()
	if not blocked.is_empty() and blocked.collider==target: failures+=1
	print("OCCLUSION target_rejected=",blocked.is_empty() or blocked.collider!=target," reason=",h.targeting.reason)
	blocker.queue_free()
	await physics_frame
	await physics_frame
	p.global_position=Vector3(0,-150,10)
	target.global_position=Vector3(0,-148,-45)
	camera.global_position=Vector3(0,-148,18)
	camera.look_at(Vector3(10,-148,-45),Vector3.UP)
	await physics_frame
	await physics_frame
	p.fall_grace=false
	p.velocity=Vector3.ZERO
	var regular:=h.aim_result()
	p.fall_grace=true
	var emergency:=h.aim_result()
	if emergency.is_empty(): failures+=1
	print("PANIC regular=",not regular.is_empty()," emergency=",not emergency.is_empty())
	var file:=FileAccess.open("res://../build/rnd003/targeting_race.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("RND TARGETING RESULT failures=",failures)
	quit(failures)
