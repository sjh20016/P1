extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game);game.start_consequence(1)
	var lab=game.consequence;var p:RavagePlayer=game.player
	for i in 15: await physics_frame
	p.controls_enabled=false
	var anchor=lab.get_node("侧向扫切抓梁");anchor.position=Vector3(55,16,-38)
	p.camera_rig.look_at(anchor.global_position)
	for i in 3: await physics_frame
	var grabbed:bool=p.hooks[0].shoot();p.controls_enabled=true
	var start:float=lab.elapsed
	while lab.elapsed-start<4: await physics_frame
	print("SWEEP LAB grabbed=",grabbed," pos=",lab.to_local(p.global_position)," history=",lab.towers[1].damage_history," macros=",lab.macros.peak)
	var success:bool=grabbed and lab.macros.peak>0 and lab.macros.last_detach_type==RavageDamageEvent.Type.SLASH
	game.queue_free();await process_frame;print("CONSEQUENCE SWEEP RESULT failures=",0 if success else 1);quit(0 if success else 1)
