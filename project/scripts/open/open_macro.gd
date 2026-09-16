extends CharacterBody3D

var zone:Node3D
var payload:Node3D
var source_event
var age:float=0
var rest_basis:=Basis.IDENTITY
var fall_axis:=Vector3.FORWARD
var contacts:Dictionary={}
var stable:float=0
var stable_position:=Vector3.ZERO
var grounded:bool=false
var contact_age:float=10.0
var tilt_axis:=Vector3.LEFT
var shapes:Array[CollisionShape3D]=[]
var tower_ref:WeakRef

func configure(world:Node3D,tower,event) -> void:
	zone=world;source_event=event
	tower_ref=weakref(tower)
	global_transform=Transform3D(tower.global_basis,tower.to_global(Vector3(0,-6,0)))
	rest_basis=global_basis
	stable_position=global_position
	collision_layer=16;collision_mask=3|16
	if event.type==RavageDamageEvent.Type.PULL:
		fall_axis=event.direction.slide(Vector3.UP).normalized()
		tilt_axis=Vector3.UP.cross(fall_axis).normalized()
	payload=preload("res://scripts/open/open_tower.gd").new()
	payload.state=tower.state.take_upper();payload.zone=zone;payload.moving=true
	add_child(payload);payload.position=Vector3(0,6,0)
	rebuild_shapes()
	tower.rebuild()
	add_collision_exception_with(tower)
	for surface in tower.surfaces: add_collision_exception_with(surface)
	force_update_transform()

func rebuild_shapes() -> void:
	for shape in shapes:
		shape.disabled=true;shape.queue_free()
	shapes.clear()
	for bounds:AABB in payload.shape_boxes:
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=bounds.size
		collision.shape=shape;collision.position=bounds.get_center()+payload.position;add_child(collision);shapes.append(collision)

func is_open_macro() -> bool:
	return true

func receive_damage(event) -> Dictionary:
	if event.type!=RavageDamageEvent.Type.COLLAPSE: return {"changed":false}
	var result:Dictionary=payload.state.apply(payload.to_local(event.position),event)
	if not result.get("changed",false): return result
	payload.rebuild();rebuild_shapes()
	zone.session.manager.emit_broken(payload.broken_scene,Transform3D(Basis.IDENTITY,event.position),event.position,event.direction,event.energy)
	zone.record_hit(payload.state.id,event,result)
	return result

func _physics_process(delta:float) -> void:
	age+=delta
	contact_age+=delta
	if age<0.18: return
	if age<0.58:
		global_basis=Basis(tilt_axis,pow((age-0.18)/0.4,2)*0.25)*rest_basis
		return
	if velocity==Vector3.ZERO and age<0.7: velocity=fall_axis*14+Vector3.DOWN*3
	if contacts.is_empty() and not grounded:
		global_basis=Basis(tilt_axis,minf(1.05,0.25+(age-0.58)*0.6))*rest_basis
	velocity+=Vector3.DOWN*25*delta
	var motion:=velocity*delta
	for step in 3:
		var collision:=move_and_collide(motion,false,0.02)
		if collision==null: break
		contact_age=0
		var target=collision.get_collider()
		var normal:=collision.get_normal()
		if is_instance_valid(target) and target.has_method("is_open_macro"):
			if zone.resolve_macro_contact(self,target,collision.get_position(),normal):
				motion=collision.get_remainder()*0.55;continue
		var recipient=target.tower_ref.get_ref() if is_instance_valid(target) and target.get("tower_ref") is WeakRef else target
		var id:int=recipient.get_instance_id() if is_instance_valid(recipient) else 0
		var damage:=false
		if is_instance_valid(target) and not target.has_method("is_open_macro") and target.has_method("receive_damage") and not contacts.has(id) and source_event.depth<2:
			contacts[id]=true
			var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.COLLAPSE
			event.depth=source_event.depth+1;event.source_id=source_event.source_id
			event.position=collision.get_position();event.normal=normal;event.direction=velocity.normalized()
			event.energy=clampf(velocity.length()*3,30,90);event.radius=4.5
			var result:Dictionary=zone.session.manager.apply_damage(target,event)
			damage=result.get("changed",false)
		if damage:
			velocity*=0.78;motion=collision.get_remainder()*0.78;continue
		if normal.y>0.35: grounded=true
		velocity=velocity.slide(normal)*0.68
		motion=collision.get_remainder().slide(normal)*0.68
		break
	# Measure a contact window, allowing tiny recovery jitter from the collision solver.
	# Reset the window as soon as the shell travels or loses physical contact.
	if contact_age>0.15 or global_position.distance_to(stable_position)>0.1 or age<0.8:
		stable=0;stable_position=global_position
	else: stable+=delta
	if stable>0.65: settle()
	elif global_position.y < zone.global_position.y-180:
		zone.active.erase(self);queue_free()

func settle() -> void:
	set_physics_process(false);collision_layer=0;collision_mask=0
	payload.reparent(zone,true);payload.moving=false;payload.set_near(true)
	zone.ruins.append(payload);zone.active.erase(self)
	queue_free()
