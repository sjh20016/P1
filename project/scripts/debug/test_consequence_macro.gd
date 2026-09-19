extends SceneTree
var failures:int=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(n:int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game)
	game.start_consequence(2);game.player.controls_enabled=false
	var lab=game.consequence
	await frames(4)
	var tower=lab.towers[1]
	var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.SLASH
	event.position=tower.to_global(Vector3(0,0,8.4));event.direction=Vector3.RIGHT;event.energy=55
	var result:Dictionary=game.manager.apply_damage(tower,event)
	check(result.bond_broken and lab.macros.active.size()==1,"D03 severed support creates ONE macro for upper component")
	var macro=lab.macros.active[0]
	var origin:Transform3D=macro.global_transform
	await frames(6)
	check(macro.global_transform.is_equal_approx(origin),"D04 crack delay precedes macro movement")
	while lab.elapsed<0.62: await physics_frame
	check(not macro.global_basis.is_equal_approx(origin.basis),"D04 large structure begins visibly tilting after delay")
	while lab.elapsed<13: await physics_frame
	print("MACRO METRICS ",JSON.stringify(lab.snapshot()))
	check(game.manager.secondary_events>0 and lab.towers[2].damage_count>0,"D05 actual falling proxy collision damages second tower")
	check(game.manager.deepest_chain<=2,"D05 secondary chain remains bounded")
	check(lab.macros.active.is_empty() and lab.macros.ruins.size()>0,"D04 all moving macros convert to persistent static ruins")
	var ruin=lab.macros.ruins[0] if not lab.macros.ruins.is_empty() else Node3D.new()
	var colliders:=0;var followed:=0
	for panel in ruin.get_children():
		if panel.collision_layer==2: colliders+=1
		for child in panel.get_children():
			if child.name==&"DamageScar": followed+=1
	check(colliders>100,"D04 ruin retains detailed collision without active rigid bodies")
	check(followed>0,"D02 scars remain attached to fallen wall pieces")
	check(lab.macros.peak<=6 and game.manager.peak_rigidbodies<=48,"D04 macro and debris budgets remain independent")
	var file:=FileAccess.open("res://../build/rnd004/macro_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":lab.metrics,"activation_us":lab.macros.activation_us,"final":lab.snapshot()},"\t"));file.close()
	game.restart_run();await frames(4)
	check(get_nodes_in_group("consequence_towers").is_empty() and get_nodes_in_group("macro_manager").is_empty(),"D04 reset removes lab and all macro state")
	check(is_equal_approx(game.player.get_node("CollisionShape3D").shape.radius,0.72),"M03 original collider restored on returning to city")
	lab=null;tower=null;macro=null;ruin=null;event=null;result.clear()
	game.queue_free()
	# Let queued collision/mesh deletion drain before shutting the server down.
	await frames(12)
	print("CONSEQUENCE MACRO RESULT failures=",failures);quit(failures)
