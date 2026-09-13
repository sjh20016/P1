extends SceneTree
var game
var camera:Camera3D
func _initialize() -> void: call_deferred("run")
func frames(n:int) -> void:
	for i in n: await process_frame
func shot(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../build/rnd004/"+name+".png"))
	print("CAPTURE ",name)
func aim(pos:Vector3,target:Vector3) -> void:
	camera.global_position=pos;camera.look_at(target)
func hide_signs(lab:Node) -> void:
	for child in lab.get_children():
		if child is Label3D: child.hide()
func damage(tower,kind:int):
	var event:=RavageDamageEvent.new();event.type=kind;event.energy=55
	event.position=tower.to_global(Vector3(0,0,8.4));event.direction=Vector3.RIGHT if kind==1 else Vector3.FORWARD
	game.manager.apply_damage(tower,event)
func run() -> void:
	game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game)
	await frames(50);await shot("01-menu")
	game.start_consequence();game.player.controls_enabled=false
	await frames(30);await shot("02-breach-start")
	game.get_node("UI").hide()
	camera=Camera3D.new();game.add_child(camera);camera.current=true;camera.fov=60
	var lab=game.consequence;var tower=lab.towers[0]
	hide_signs(lab)
	aim(tower.global_position+Vector3(19,8,32),tower.global_position)
	await frames(20);await shot("03-intact")
	damage(tower,0);await frames(110);await shot("04-ram")
	game.start_consequence(3);game.player.controls_enabled=false
	lab=game.consequence;tower=lab.towers[0]
	hide_signs(lab)
	damage(tower,1);await frames(110);await shot("05-slash")
	game.start_consequence(2);game.player.controls_enabled=false
	lab=game.consequence;tower=lab.towers[1]
	hide_signs(lab)
	aim(tower.global_position+Vector3(-40,20,10),tower.global_position+Vector3(0,-1,-11))
	await frames(15);await shot("06-domino-intact")
	damage(tower,1)
	var impact_time:float=lab.elapsed
	while lab.elapsed-impact_time<0.5: await process_frame
	await shot("07-delay")
	while lab.elapsed-impact_time<1.5: await process_frame
	await shot("08-falling")
	while lab.elapsed-impact_time<4: await process_frame
	await shot("09-secondary")
	while lab.elapsed-impact_time<13: await process_frame
	await shot("10-ruin")
	var contact:Vector3=game.manager.last_hit_position
	aim(contact+Vector3(14,8,20),contact)
	await frames(10);await shot("11-contact-scar")
	var file:=FileAccess.open("res://../build/rnd004/render_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":lab.metrics,"final":lab.snapshot(),"frame_us":lab.frame_us,"panel_activation_us":lab.towers.map(func(t):return t.activation_us),"activation_us":lab.macros.activation_us},"\t"));file.close()
	print("RENDER METRICS ",JSON.stringify(lab.snapshot()))
	game.queue_free();await frames(5);quit()
