extends SceneTree
var results:Dictionary={}
func _initialize() -> void: call_deferred("run")
func frames(n:int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var scars:=RavageScarManager.new();scene.add_child(scars)
	var tower=load("res://scenes/consequence/breachable_tower.tscn").instantiate();scene.add_child(tower);tower.activate_panels()
	var event:=RavageDamageEvent.new();event.energy=55;event.direction=Vector3.RIGHT
	var start:=Time.get_ticks_usec()
	for i in 384:
		event.type=i%2;event.seed=i
		var panel=tower.panels[i]
		scars.deposit(panel,event,Vector3.ZERO,panel.face_normal,1.2)
	results.mesh_scar={"marks":384,"create_us":Time.get_ticks_usec()-start,"vertex_bytes":scars.vertices_written*12,"render_objects":scars.marks.size()}
	# Independent mask trial: one 512 RGBA mask per authored tower face; uploads included.
	var masks:Array[Image]=[];var textures:Array[ImageTexture]=[]
	for i in 4:
		var img:=Image.create(512,512,false,Image.FORMAT_RGBA8);img.fill(Color.TRANSPARENT)
		masks.append(img);textures.append(ImageTexture.create_from_image(img))
	start=Time.get_ticks_usec()
	for i in 384:
		var face:=i%4;var x:=35+(i*73)%440;var y:=35+(i*37)%440
		for offset in range(-22,23):
			var spread:int=22-absi(offset) if i%2==0 else 2
			for dy in range(-spread,spread+1): masks[face].set_pixel(x+offset,y+dy,Color.BLACK)
		textures[face].update(masks[face])
	results.texture_scar={"marks":384,"paint_upload_us":Time.get_ticks_usec()-start,"cpu_image_bytes":4*512*512*4,"gpu_bytes_estimate":4*512*512*4,"draw_surfaces":4,"moving_chunk_uv_remap_implemented":false}
	textures.clear();masks.clear();scars.clear();tower.queue_free();await frames(2)
	var ground:=StaticBody3D.new();scene.add_child(ground);ground.collision_layer=1
	var gs:=BoxShape3D.new();gs.size=Vector3(200,1,200)
	var gc:=CollisionShape3D.new();gc.shape=gs;gc.position.y=-0.5;ground.add_child(gc)
	# A true property tween cannot respond to contact without an additional sweep layer.
	var proxy:=AnimatableBody3D.new();scene.add_child(proxy);proxy.position=Vector3(-30,18,0)
	var ps:=BoxShape3D.new();ps.size=Vector3(16,12,16)
	var pc:=CollisionShape3D.new();pc.shape=ps;proxy.add_child(pc)
	proxy.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(proxy,"position",Vector3(-30,-5,-15),1.0)
	await frames(90)
	results.tween_macro={"final_y":proxy.position.y,"penetrates_foundation":proxy.position.y<6,"secondary_contact_callback":false}
	proxy.queue_free()
	var bodies:Array[RigidBody3D]=[]
	for i in 3:
		var body:=RigidBody3D.new();body.mass=120;body.contact_monitor=true;body.max_contacts_reported=8;body.continuous_cd=true
		body.collision_layer=16;body.collision_mask=1;body.position=Vector3(-45+i*45,18,0);body.rotation.x=-0.3-i*0.04
		var shape:=BoxShape3D.new();shape.size=Vector3(16,12,16)
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);scene.add_child(body)
		body.linear_velocity=Vector3(0,-3,-12);body.angular_velocity=Vector3(-0.55,0,0)
		bodies.append(body)
	await frames(480)
	var physics_rows:Array=[]
	for body in bodies: physics_rows.append({"position":str(body.position),"rotation":str(body.rotation),"speed":body.linear_velocity.length(),"sleeping":body.sleeping,"contacts":body.get_contact_count()})
	results.rigid_macro=physics_rows
	results.renderer=DisplayServer.get_name()
	var file:=FileAccess.open("res://../build/rnd004/candidate_races.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("CANDIDATE RACES ",JSON.stringify(results))
	scene.queue_free();await frames(3);quit()
