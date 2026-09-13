extends SceneTree
var failures:int=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game);game.start_consequence()
	var p:RavagePlayer=game.player;var lab=game.consequence
	for i in 15: await physics_frame
	# Scripted input/aim, real M03 hook motor + body sweep; no damage injection or velocity assignment.
	p.camera_rig.look_at(lab.towers[0].global_position+Vector3(0,5,8.4))
	Input.action_press("jump");Input.action_press("forward")
	check(p.hooks[0].shoot(),"D01 normal targeting finds intact breach tower")
	p.controls_enabled=true
	var started:float=lab.elapsed
	while lab.elapsed-started<4 and not lab.exit_crossed:
		if lab.towers[0].damage_count>0 and p.hooks[0].active:
			p.hooks[0].intentional_release=true;p.hooks[0].release()
		await physics_frame
	print("ROUTE METRICS position=",lab.to_local(p.global_position)," speed=",p.velocity.length()," events=",lab.towers[0].damage_count)
	check(lab.entry_crossed,"D01 M03 motor and actual body impact open entry and enter cavity")
	check(lab.exit_crossed,"D01 player breaches exit with retained momentum")
	if lab.exit_crossed:
		p.camera_rig.look_at(lab.to_global(Vector3(0,5,-23)))
		check(p.hooks[1].shoot(),"D01 normal targeting can acquire exit structure after breach")
	check(p.hooks[0].profile.movement_model==2,"M03 remains default without grapple algorithm changes")
	Input.action_release("jump");Input.action_release("forward")
	game.queue_free();await process_frame;print("CONSEQUENCE ROUTE RESULT failures=",failures);quit(failures)
