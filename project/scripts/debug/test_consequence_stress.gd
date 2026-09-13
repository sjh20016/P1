extends SceneTree
var failures:int=0
var rows:Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(n:int) -> void:
	for i in n: await physics_frame
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game);game.begin();game.player.controls_enabled=false
	game.get_node("ImpactVFX").enabled=false
	for budget in [4,6,8]:
		var sandbox:=Node3D.new();game.add_child(sandbox)
		var manager=load("res://scripts/consequence/macro_manager.gd").new();manager.budget=budget;sandbox.add_child(manager)
		var scars:=RavageScarManager.new();sandbox.add_child(scars)
		var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.SLASH;event.direction=Vector3.RIGHT;event.energy=55
		for i in budget+1:
			var tower=load("res://scenes/consequence/breachable_tower.tscn").instantiate();tower.position=Vector3(2000+i*30,150,0);tower.structural=true;sandbox.add_child(tower)
			event.position=tower.to_global(Vector3(0,0,8.4));game.manager.apply_damage(tower,event)
		check(manager.active.size()==budget and manager.ruins.size()==1,"macro overflow becomes ruin at budget %d" % budget)
		check(manager.peak==budget,"macro peak obeys budget %d" % budget)
		var owner=manager.active[0].payload.get_child(0)
		for i in 450:
			event.seed=i;scars.deposit(owner,event,Vector3.ZERO,owner.face_normal,1.0)
		await frames(4);scars.prune()
		check(scars.marks.size()<=384,"scar FIFO cap remains bounded at budget %d" % budget)
		rows.append({"budget":budget,"peak":manager.peak,"activation_us":manager.activation_us.duplicate(),"scars":scars.marks.size(),"debris":game.manager.active_debris.size()})
		manager.clear();sandbox.queue_free();game.manager.clear_debris();await frames(4)
	# Accepted depth 2 and rejected depth 3 use the same pipeline on fresh wall areas.
	var target=load("res://scenes/consequence/breachable_tower.tscn").instantiate();target.position=Vector3(2000,0,0);game.add_child(target)
	var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.COLLAPSE;event.energy=60;event.depth=2;event.position=target.to_global(Vector3(0,0,8.4))
	check(game.manager.apply_damage(target,event).get("changed",false),"COLLAPSE at depth 2 is accepted")
	var before:int=target.damage_count;event.depth=3;event.position.x+=4
	check(game.manager.apply_damage(target,event).get("rejected",false) and target.damage_count==before,"depth 3 cannot modify geometry or extend chain")
	var file:=FileAccess.open("res://../build/rnd004/budget_stress.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
	game.queue_free();await frames(12);print("CONSEQUENCE STRESS RESULT failures=",failures);quit(failures)
