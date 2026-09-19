extends SceneTree

var failures:int=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(n:int) -> void:
	for i in n: await physics_frame
func event_at(pos:Vector3,kind:int=0):
	var e:=RavageDamageEvent.new();e.type=kind;e.position=pos;e.energy=55;e.normal=Vector3.BACK;e.direction=Vector3.FORWARD
	return e
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game);game.begin()
	var scars:=RavageScarManager.new();game.add_child(scars)
	var p:RavagePlayer=game.player;p.controls_enabled=false
	var tower=load("res://scenes/consequence/breachable_tower.tscn").instantiate();tower.position=Vector3(1000,0,0);game.add_child(tower)
	await frames(3)
	check(not tower.panel_mode and tower.panels.is_empty(),"D01 panels remain lazy before first real damage")
	var event=event_at(tower.global_position+Vector3(0,0,8.4))
	var result:Dictionary=game.manager.apply_damage(tower,event)
	await frames(3)
	check(tower.panel_mode and result.removed>0 and result.remaining>370,"D01 RAM removes local panels while retaining surrounding shell")
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(1000,0,12),Vector3(1000,0,6),3,[p.get_rid()])
	check(p.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"D01 breached opening has no leftover collider")
	var rim_ray:=PhysicsRayQueryParameters3D.create(Vector3(1006,0,12),Vector3(1006,0,6),3,[p.get_rid()])
	check(not p.get_world_3d().direct_space_state.intersect_ray(rim_ray).is_empty(),"D01 wall beside opening remains solid")
	check(scars.marks.size()>0,"D02 surviving rim receives permanent radial scars")
	var mark:MeshInstance3D=scars.marks[0].get_ref()
	var parent:Node3D=mark.get_parent()
	var local:=mark.transform
	var original:=mark.global_transform
	parent.rotation.z=0.2;parent.position.y+=0.3
	check(mark.transform==local and not mark.global_transform.is_equal_approx(original),"D02 scar follows owner rotation and translation in local space")
	parent.rotation=Vector3.ZERO;parent.position.y-=0.3
	var centered=event_at(parent.to_global(Vector3(0,0,0.4)))
	parent.chip_corner(centered);await frames(2)
	var hull:ConvexPolygonShape3D=parent.get_node("Collision").shape
	var extent:=AABB(hull.points[0],Vector3.ZERO)
	for point in hull.points: extent=extent.expand(point)
	check(extent.size.x>0.5 and extent.size.y>0.5 and extent.size.z>0.5,"D01 face-center chip keeps a nondegenerate 3D convex collider")
	event=event_at(tower.global_position+Vector3(0,0,-8.4));event.normal=Vector3.FORWARD
	game.manager.apply_damage(tower,event);await frames(3)
	var rows:Array=[]
	var shape:SphereShape3D=p.get_node("CollisionShape3D").shape.duplicate();p.get_node("CollisionShape3D").shape=shape
	for ratio in [0.5,0.6,0.7]:
		shape.radius=0.72*0.82*ratio
		p.global_position=Vector3(1001.62,0,14)
		await frames(2)
		for i in 80:
			p.move_and_collide(Vector3(0,0,-0.4))
			await physics_frame
		var passed:bool=p.global_position.z < -12
		rows.append({"visual_core_ratio":ratio,"radius":shape.radius,"passed_edge_route":passed,"final_z":p.global_position.z})
		if ratio==0.6:check(passed,"D01 60 percent collider enters, traverses cavity and exits at an edge approach")
	var second=load("res://scenes/consequence/breachable_tower.tscn").instantiate();second.position=Vector3(1040,0,0);game.add_child(second)
	await frames(2)
	event=event_at(second.global_position+Vector3(0,0,8.4),RavageDamageEvent.Type.SLASH);event.direction=Vector3.RIGHT
	var cut:Dictionary=game.manager.apply_damage(second,event)
	check(cut.severed>0 and cut.removed==0 and cut.scar_type!=result.scar_type,"D05 SLASH leaves displaced lips and a narrow seam rather than RAM holes")
	var graph:=RavageSupportGraph.new()
	graph.configure([{"id":0,"support":true},{"id":1},{"id":2},{"id":3}],[{"a":0,"b":1,"health":100},{"a":1,"b":2,"health":50},{"a":2,"b":3,"health":50}])
	graph.weaken(1,50)
	var detached:=graph.detached_components()
	check(detached.size()==1 and detached[0]==[2,3],"D03 broken middle bond detaches C+D and retains supported A+B")
	event.depth=3
	check(game.manager.apply_damage(second,event).get("rejected",false),"D05 secondary damage above chain depth is rejected")
	var file:=FileAccess.open("res://../build/rnd004/collider_race.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
	game.queue_free();await process_frame
	print("CONSEQUENCE CORE RESULT failures=",failures)
	quit(failures)
