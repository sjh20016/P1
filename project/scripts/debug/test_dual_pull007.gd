extends SceneTree

var failures:int=0
var game

func _initialize() -> void: call_deferred("run")
func frames(count:int) -> void:
	for i in count: await physics_frame
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1

func run() -> void:
	game=load("res://scenes/maps/open_main.tscn").instantiate();root.add_child(game);game.start_open()
	var zone=game.open_zone
	while zone.loading: await process_frame
	var player:RavagePlayer=game.player;player.controls_enabled=false
	var pull=zone.dual_pull;pull.set_physics_process(false)
	var a=zone.towers[1];var b=zone.towers[2]
	player.global_position=(a.global_position+b.global_position)*0.5+Vector3(0,10,26)
	zone.update_interest(true);await frames(3)
	var anchor_a:Vector3=a.to_global(Vector3(8.4,6,0))
	var anchor_b:Vector3=b.to_global(Vector3(-8.4,6,0))
	player.camera_rig.look_at(anchor_a);await frames(3)
	check(player.hooks[0].shoot() and player.hooks[0].target==a,"actual left targeting acquires the first pull core")
	player.camera_rig.look_at(anchor_b);await frames(3)
	check(player.hooks[1].shoot() and player.hooks[1].target==b,"actual right targeting acquires the second pull core")
	player.velocity=Vector3.ZERO
	player.hooks[1].attach_to(anchor_a,a)
	player.hooks[0].tension=100;player.hooks[1].tension=100
	pull.step(1.0,true)
	check(pull.charge==0 and zone.pull_actions==0,"same building cannot trigger a dual pull")
	player.hooks[1].attach_to(anchor_b,b)
	player.hooks[1].tension=0;pull.step(0.4,true)
	check(pull.charge==0,"both sides must have real tension")
	player.hooks[1].tension=100;pull.step(0.3,true)
	check(pull.charge>0 and a.pull_charge>0 and a.state.revision==0 and game.manager.score==0,"charge preview does not damage or award points")
	pull.step(1.0,false)
	check(pull.charge==0 and a.pull_charge==0 and a.state.bond==100,"releasing Q cancels charge without damage")
	# Actual input, hook forces and player movement drive this activation.
	pull.set_physics_process(true);player.controls_enabled=true;player.velocity=Vector3.ZERO
	Input.action_press("reel_in")
	var deadline:float=zone.elapsed+3
	while zone.elapsed<deadline and zone.pull_actions==0: await physics_frame
	Input.action_release("reel_in");player.controls_enabled=false
	check(zone.pull_actions==1 and a.state.bond==0 and b.state.bond==0,"held Q and actual hook forces sever both marked bonds")
	check(not player.hooks[0].active and not player.hooks[1].active,"detachment releases both hooks while retaining movement")
	await frames(4)
	check(zone.active.size()==2 and zone.pending.is_empty(),"one action creates exactly two moving chunks within budget")
	check(not zone.has_macro_capacity(2),"another pair cannot exceed the three-macro limit")
	var peak_bodies:int=0
	deadline=zone.elapsed+14
	while zone.elapsed<deadline and (not zone.active.is_empty() or not zone.pending.is_empty()):
		await physics_frame
		peak_bodies=maxi(peak_bodies,game.manager.active_debris.size())
	for macro in zone.active: print("UNSETTLED007 ",macro.position," velocity=",macro.velocity," contacts=",macro.contacts)
	check(zone.clashes==1,"two independently moving chunks generate one real mutual collision")
	check(zone.chains>=1 and zone.ruins.size()==2 and zone.active.is_empty(),"mutual collision damages shell and settles both pieces as ruins")
	check(peak_bodies<=48,"clash fragments stay within the shared budget")
	var score:int=game.manager.score
	await frames(120)
	check(game.manager.score==score and zone.clashes==1,"continued contact cannot repeat the clash reward")
	var signatures:Array[String]=[]
	for ruin in zone.ruins: signatures.append(ruin.state.signature())
	player.global_position=zone.to_global(Vector3(340,0,-310));zone.update_interest(true);await frames(3)
	player.global_position=a.global_position+Vector3(20,10,20);zone.update_interest(true);await frames(3)
	var unchanged:bool=zone.ruins.size()==signatures.size()
	for i in zone.ruins.size(): unchanged=unchanged and zone.ruins[i].state.signature()==signatures[i]
	check(unchanged,"clash ruins preserve their damaged state across revisit")
	print("DUAL007 METRICS ",JSON.stringify(zone.snapshot())," score=",game.manager.score)
	game.restart_active_run()
	while game.open_zone.loading: await process_frame
	check(game.open_zone.clashes==0 and game.open_zone.pull_actions==0 and game.open_zone.dual_pull.charge==0 and game.manager.score==0,"F5 clears action, pairing, reward and preview state")
	game.queue_free();await frames(12)
	print("DUAL007 RESULT failures=",failures);quit(failures)
