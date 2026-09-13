extends DestructibleSegment

@export var panels_scene:PackedScene
@export_file("*.json") var metadata_path:String
@export var structural:bool=false
@export var fall_direction:=Vector3.RIGHT
var panel_mode:bool=false
var panels:Array=[]
var metadata:Dictionary={}
var graph:=RavageSupportGraph.new()
var damage_history:Array[Dictionary]=[]
var detached_chunks:Array[int]=[]
var damage_count:int=0
var activation_us:int=0

func _ready() -> void:
	super._ready()
	add_to_group("consequence_towers")
	metadata=JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	graph.configure(metadata.chunks,metadata.bonds)

func activate_panels() -> void:
	if panel_mode: return
	var started:=Time.get_ticks_usec()
	panel_mode=true
	var panel_root:=panels_scene.instantiate()
	add_child(panel_root)
	for panel in panel_root.get_children():
		panels.append(panel)
		panel.force_update_transform()
	$IntactVisual.hide();collision_layer=0;collision_mask=0
	remove_from_group("destructible")
	for child in get_children():
		if child is CollisionShape3D: child.set_deferred("disabled",true)
	activation_us=Time.get_ticks_usec()-started

func resolve_grapple(point:Vector3) -> StaticBody3D:
	if not panel_mode: return self
	var nearest:StaticBody3D
	var distance:=INF
	for panel in panels:
		if panel.broken or panel.cut or panel.detached: continue
		var p:Vector3=panel.to_local(point)
		var d:float=p.distance_to(p.clamp(panel.local_bounds.position,panel.local_bounds.end))
		if d<distance: distance=d;nearest=panel
	return nearest if distance<1.5 else null

func break_segment(point:Vector3,axis:Vector3,strength:float) -> bool:
	var manager=get_tree().get_first_node_in_group("destruction_manager")
	var event:=RavageDamageEvent.new();event.configure_hit(point,axis,strength,manager.next_context)
	return bool(manager.apply_damage(self,event).get("changed",false))

func receive_damage(event) -> Dictionary:
	if event.energy<destruction_threshold and event.type!=RavageDamageEvent.Type.PULL: return {"changed":false}
	activate_panels()
	var closest
	var nearest:=INF
	for panel in panels:
		if panel.broken or panel.detached: continue
		var point:Vector3=panel.to_local(event.position)
		var distance:float=point.distance_squared_to(point.clamp(panel.local_bounds.position,panel.local_bounds.end))
		if distance<nearest: nearest=distance;closest=panel
	if closest==null or nearest>36: return {"changed":false}
	var face:Vector3=closest.global_basis*closest.face_normal
	var cut_axis:Vector3=event.direction.slide(face).normalized()
	if cut_axis.length_squared()<0.1: cut_axis=closest.global_basis*(Vector3.RIGHT if absf(closest.face_normal.z)>0.5 else Vector3.FORWARD)
	var cross_axis:=face.cross(cut_axis).normalized()
	var removed:=0;var severed:=0
	var scars=get_tree().get_first_node_in_group("damage_scars")
	for panel in panels:
		if panel.broken or panel.detached: continue
		var normal:Vector3=panel.global_basis*panel.face_normal
		if normal.dot(face)<0.8: continue
		var delta:Vector3=panel.global_position-event.position
		if absf(delta.dot(face))>1.2: continue
		var along:=delta.dot(cut_axis);var across:=delta.dot(cross_axis)
		var in_wound:bool=delta.slide(face).length()<event.radius
		if event.type==RavageDamageEvent.Type.SLASH:
			across=(panel.global_position-closest.global_position).dot(cross_axis)
			in_wound=absf(along)<4.5 and absf(across)<0.7
			if in_wound and not panel.cut: panel.sever(event);severed+=1
		elif event.type!=RavageDamageEvent.Type.PULL and in_wound:
			panel.erase_panel();removed+=1
		elif event.type==RavageDamageEvent.Type.RAM or event.type==RavageDamageEvent.Type.COLLAPSE:
			if delta.slide(face).length()<event.radius+1.6: panel.chip_corner(event)
		if not panel.broken and scars!=null and delta.slide(face).length()<event.radius+2.5:
			var local_hit:Vector3=panel.to_local(event.position)
			if event.type==RavageDamageEvent.Type.SLASH and in_wound: local_hit=Vector3(0,0.24,0)
			# Marks belong to the surviving wall or moving chunk, never world space.
			var extent:float=clampf(event.energy/12.0,3.6,5.2) if event.type==RavageDamageEvent.Type.RAM or event.type==RavageDamageEvent.Type.COLLAPSE else clampf(event.energy/24.0,1.0,3.0)
			scars.deposit(panel,event,local_hit,panel.face_normal,extent)
	var local_hit:=to_local(event.position)
	var bond_broken:=false
	if structural and graph.nodes[closest.chunk_id].get("active",true):
		for i in graph.bonds.size():
			var bond:Dictionary=graph.bonds[i]
			if absf(local_hit.y-float(bond.seam_y))<=3.1:
				var scale:=2.4 if event.type==RavageDamageEvent.Type.SLASH else (1.0 if event.type==RavageDamageEvent.Type.PULL else 0.65)
				if graph.weaken(i,event.energy*scale): bond_broken=true
		if bond_broken:
			for component:Array in graph.detached_components():
				graph.detach(component)
				for id:int in component: detached_chunks.append(id)
				var macro_manager=get_tree().get_first_node_in_group("macro_manager")
				if macro_manager: macro_manager.detach_component(self,component,event)
	var changed:bool=removed>0 or severed>0 or bond_broken or event.type==RavageDamageEvent.Type.PULL
	if changed:
		damage_count+=1
		if damage_history.size()>=64: damage_history.pop_front()
		damage_history.append({"type":event.type,"local_position":local_hit,"depth":event.depth,"removed":removed,"severed":severed})
		var manager=get_tree().get_first_node_in_group("destruction_manager")
		manager.emit_broken(broken_scene,Transform3D(Basis.IDENTITY,event.position),event.position,event.direction,event.energy)
	return {"changed":changed,"removed":removed,"severed":severed,"scar_type":event.type,"bond_broken":bond_broken,"remaining":intact_panel_count()}

func intact_panel_count() -> int:
	var count:=0
	for panel in panels:
		if not panel.broken: count+=1
	return count

func restore() -> void:
	if has_node("Panels"):
		var old=get_node("Panels");remove_child(old);old.queue_free()
	panels.clear();panel_mode=false;damage_count=0;damage_history.clear();detached_chunks.clear()
	graph.configure(metadata.chunks,metadata.bonds)
	add_to_group("destructible")
	super.restore()

func sweep_hit(a:Vector3,b:Vector3,c:Vector3,d:Vector3,radius:float) -> Variant:
	var inverse:=global_transform.affine_inverse()
	for row in metadata.panels:
		var pos:Vector3=Vector3(row.position[0],row.position[1],row.position[2])
		var size:Vector3=Vector3(row.size[0],row.size[1],row.size[2])
		var bounds:=AABB(pos-size*0.5,size)
		if SweepGeometry.swept_line_box(inverse*a,inverse*b,inverse*c,inverse*d,bounds,radius):
			var hit:Variant=bounds.grow(radius).intersects_segment(inverse*c,inverse*d)
			return global_transform*(hit if hit!=null else bounds.get_center())
	return null
