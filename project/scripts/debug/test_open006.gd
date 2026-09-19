extends SceneTree
var failures:int=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(n:int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var game=load("res://scenes/maps/open_main.tscn").instantiate();root.add_child(game);game.start_open()
	var zone=game.open_zone
	while zone.loading: await process_frame
	var player:RavagePlayer=game.player;player.controls_enabled=false
	await frames(3)
	check(zone.towers.size()==36 and zone.states.size()==36,"36 reachable buildings use independent damage states")
	check(game.get_node("StaticTowerForest").get_child_count()==0,"open startup does not preload legacy city")
	check(player.hooks[0].shoot(),"actual targeting acquires the open entry wall")
	player.hooks[0].release()
	var tower=zone.towers[0]
	check(tower.surfaces.size()==4 and tower.get_child_count()<12,"intact tower has four merged collision walls")
	var anchor:Vector3=tower.to_global(Vector3(6,9,8.4))
	var surface=tower.surfaces[0]
	check(player.hooks[0].attach_to(anchor,surface) and player.hooks[0].target==tower,"grapple stores stable building identity")
	var event:=RavageDamageEvent.new();event.energy=55;event.direction=Vector3.FORWARD;event.normal=Vector3.BACK
	event.position=tower.to_global(Vector3(0,0,8.4))
	var result:Dictionary=game.manager.apply_damage(tower,event)
	check(result.get("boost",false) and tower.state.boost_used,"first body breach consumes the energy reward")
	await frames(3);player.hooks[0].update_input(0.01)
	check(result.changed and tower.anchor_valid(anchor) and player.hooks[0].active,"unaffected grapple survives collision rebuilding")
	player.hooks[0].release()
	var query:=PhysicsRayQueryParameters3D.create(tower.to_global(Vector3(0,0,12)),tower.to_global(Vector3(0,0,6)),3,[player.get_rid()])
	check(player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"RAM opens collision through actual center of impact")
	var signature:String=tower.state.signature()
	player.global_position=zone.to_global(Vector3(340,0,-300));zone.update_interest(true)
	check(not tower.near and tower.surfaces.is_empty(),"leaving removes distant collision bodies")
	player.global_position=tower.to_global(Vector3(0,0,18));zone.update_interest(true);await frames(3)
	check(tower.near and signature==tower.state.signature() and player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"return restores exact opening and state without healing")
	player.hooks[0].attach_to(anchor,tower)
	event.position=anchor
	game.manager.apply_damage(tower,event)
	await frames(3);player.hooks[0].update_input(0.01)
	check(not player.hooks[0].active,"destroying the actual anchor releases the hook")
	var second=zone.towers[1]
	player.global_position=second.to_global(Vector3(0,0,14));zone.update_interest(true);await frames(3)
	player.velocity=Vector3(0,0,-60);player.controls_enabled=true
	await frames(75);player.controls_enabled=false
	check(second.state.revision>=2 and second.to_local(player.global_position).z< -10,"actual swept movement breaches entry and exit walls")
	var structural=zone.towers[7]
	player.global_position=structural.to_global(Vector3(-18,8,12));zone.update_interest(true);await frames(3)
	event=RavageDamageEvent.new();event.energy=55;event.type=RavageDamageEvent.Type.SLASH;event.direction=Vector3.RIGHT
	event.position=structural.to_global(Vector3(0,-6,8.4))
	result=game.manager.apply_damage(structural,event)
	check(result.bond_broken,"marked weak seam breaks with one strong slash")
	var deadline:float=zone.elapsed+18
	while zone.elapsed<deadline and (not zone.active.is_empty() or not zone.pending.is_empty()): await physics_frame
	for macro in zone.active: print("UNSETTLED ",macro.position," velocity=",macro.velocity," contacts=",macro.contacts," stable=",macro.stable)
	check(zone.chains>0 and zone.towers[13].state.revision>0,"swept falling shell really strikes the receiver tower")
	check(zone.active.is_empty() and not zone.ruins.is_empty(),"macro settles through contact into compact persistent ruin")
	var ruin_signature:String=zone.ruins[0].state.signature() if not zone.ruins.is_empty() else ""
	player.global_position=zone.to_global(Vector3(340,0,-300));zone.update_interest(true);await frames(3)
	player.global_position=structural.global_position;zone.update_interest(true);await frames(3)
	check(not zone.ruins.is_empty() and zone.ruins[0].state.signature()==ruin_signature,"ruin retains state across exit and return")
	print("OPEN006 METRICS ",JSON.stringify(zone.snapshot()))
	game.restart_active_run()
	while game.open_zone.loading: await process_frame
	check(game.open_zone.visited.is_empty() and game.manager.score==0,"F5 resets contract, world state and reward")
	game.queue_free();await frames(12)
	print("OPEN006 RESULT failures=",failures);quit(failures)
