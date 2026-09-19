extends CharacterBody3D

# One swept proxy per disconnected component. Visible panels never become rigid bodies.
var manager:Node3D
var payload:Node3D
var source_event
var fall_axis:=Vector3.FORWARD
var rotation_axis:=Vector3.LEFT
var rest_basis:=Basis.IDENTITY
var age:float=0
var stable_time:float=0
var settled:bool=false
var launched:bool=false
var hit_targets:Dictionary={}
var source_tower:WeakRef
var height:float=12
var contact_events:Array[Dictionary]=[]

func configure(owner_manager,tower,component:Array,event) -> void:
	manager=owner_manager;source_event=event;source_tower=weakref(tower)
	fall_axis=tower.fall_direction.normalized()
	rotation_axis=Vector3.UP.cross(fall_axis).normalized()
	var first:int=component.min();var last:int=component.max()
	var bottom:float=-12+first*6
	height=(last-first+1)*6
	global_transform=Transform3D(tower.global_basis,tower.to_global(Vector3(0,bottom,0)))
	rest_basis=global_basis
	collision_layer=16;collision_mask=3|16
	platform_floor_layers=0;platform_wall_layers=0
	payload=Node3D.new();payload.name="Structure";add_child(payload)
	for panel in tower.panels:
		add_collision_exception_with(panel)
		for child in panel.get_children():
			if child is PhysicsBody3D: add_collision_exception_with(child)
		if panel.chunk_id in component and not panel.broken:
			panel.set_macro_moving(true)
			panel.reparent(payload,true)
	for child in tower.get_children():
		if child.has_meta("macro_group"):
			add_collision_exception_with(child)
			if int(child.get_meta("macro_group")) in component and not child.broken:
				child.collision_layer=0;child.collision_mask=0;child.reparent(payload,true)
	for side in 4:
		var box:=BoxShape3D.new()
		box.size=Vector3(16,height,0.8) if side<2 else Vector3(0.8,height,16)
		var shape:=CollisionShape3D.new();shape.shape=box
		shape.position=Vector3(0,height*0.5,8 if side==0 else -8) if side<2 else Vector3(8 if side==2 else -8,height*0.5,0)
		add_child(shape)
	force_update_transform()

func _physics_process(delta:float) -> void:
	if settled: return
	age+=delta
	if age<0.22:
		payload.rotation.z=sin(age*90)*0.004*(age/0.22)
		return
	payload.rotation=Vector3.ZERO
	if age<0.72:
		var t:=clampf((age-0.22)/0.5,0,1)
		global_basis=Basis(rotation_axis,t*t*0.3)*rest_basis
		return
	if not launched:
		launched=true
		velocity=fall_axis*12+Vector3.DOWN*3
	if hit_targets.is_empty(): global_basis=Basis(rotation_axis,minf(1.05,0.3+(age-0.72)*0.55))*rest_basis
	velocity+=Vector3.DOWN*22*delta
	# Rotation stops after the first damage contact; translation supplies actual contact positions.
	var motion:=velocity*delta
	for step in 4:
		var collision:=move_and_collide(motion,false,0.015)
		if collision==null: stable_time=0;break
		manager.collision_count+=1
		var target=collision.get_collider()
		var normal:=collision.get_normal()
		var contact:=collision.get_position()
		var damaged:=false
		if is_instance_valid(target) and (target.has_method("receive_damage") or target.has_method("break_segment")):
			var recipient=target.tower_ref.get_ref() if target.get("tower_ref") is WeakRef else target
			var target_id:int=recipient.get_instance_id()
			var previous:Dictionary=hit_targets.get(target_id,{"age":-10.0,"count":0})
			if age-float(previous.age)>0.3 and int(previous.count)<3 and source_event.depth<2:
				hit_targets[target_id]={"age":age,"count":int(previous.count)+1}
				var event:=RavageDamageEvent.new()
				event.type=RavageDamageEvent.Type.COLLAPSE;event.depth=source_event.depth+1
				event.position=contact;event.normal=normal;event.direction=velocity.normalized()
				event.source_velocity=velocity;event.energy=clampf(velocity.length()*3,22,100)
				event.radius=3.3;event.source_id=get_instance_id();event.seed=source_event.seed+17
				var damage_manager=get_tree().get_first_node_in_group("destruction_manager")
				var result:Dictionary=damage_manager.apply_damage(target,event)
				damaged=result.get("changed",false)
				contact_events.append({"position":contact,"depth":event.depth,"changed":damaged,"speed":velocity.length()})
		if damaged:
			velocity*=0.78;motion=collision.get_remainder()*0.78
			continue
		velocity=velocity.slide(normal)*0.78
		motion=collision.get_remainder().slide(normal)*0.78
		if velocity.length()<2: stable_time+=delta
		if normal.y>0.45 and velocity.length()<4: stable_time+=delta
		break
	if stable_time>0.55: settle("rest")
	elif age>9: settle("time_budget")

func settle(reason:String="rest") -> void:
	if settled: return
	settled=true;set_physics_process(false);velocity=Vector3.ZERO
	collision_layer=0;collision_mask=0
	manager.became_ruin(self,payload,reason)
	queue_free()
