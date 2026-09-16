extends SceneTree
var game
var camera:Camera3D
var output_dir:String
func _initialize() -> void: call_deferred("run")
func frames(n:int) -> void:
	for i in n: await process_frame
func shot(title:String) -> void:
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output_dir.path_join(title+".png"))
	assert(error==OK,"Screenshot could not be saved")
	print("CAPTURE ",title)
func run() -> void:
	output_dir=ProjectSettings.globalize_path("res://../build/rnd006").simplify_path()
	DirAccess.make_dir_recursive_absolute(output_dir)
	game=load("res://scenes/maps/open_main.tscn").instantiate();root.add_child(game);game.start_open()
	var zone=game.open_zone
	while zone.loading: await process_frame
	game.player.controls_enabled=false
	await frames(45);await shot("01-start")
	game.get_node("UI").hide()
	camera=Camera3D.new();game.add_child(camera);camera.current=true;camera.fov=65
	camera.global_position=zone.to_global(Vector3(-70,75,90));camera.look_at(zone.to_global(Vector3(115,0,-130)))
	await frames(20);await shot("02-open-world")
	var tower=zone.towers[0]
	camera.global_position=tower.to_global(Vector3(-24,10,36));camera.look_at(tower.global_position)
	var event:=RavageDamageEvent.new();event.energy=60;event.direction=Vector3.FORWARD;event.position=tower.to_global(Vector3(0,0,8.4))
	game.manager.apply_damage(tower,event)
	await frames(5);await shot("03-impact")
	await frames(90);await shot("04-breach")
	tower=zone.towers[7]
	game.player.global_position=tower.to_global(Vector3(-20,6,24));zone.update_interest(true)
	camera.global_position=tower.to_global(Vector3(-45,23,32));camera.look_at(tower.to_global(Vector3(0,0,-15)))
	event=RavageDamageEvent.new();event.energy=55;event.direction=Vector3.RIGHT;event.type=RavageDamageEvent.Type.SLASH
	event.position=tower.to_global(Vector3(0,-6,8.4));game.manager.apply_damage(tower,event)
	await frames(75);await shot("05-chain")
	await frames(600);await shot("06-ruin")
	print("CAPTURE METRICS ",JSON.stringify(zone.snapshot()))
	zone.save_run(output_dir.path_join("capture-metrics.json"))
	game.queue_free();await frames(12);quit()
