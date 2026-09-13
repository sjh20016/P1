extends DestructibleSegment

@export var panel_id:int=0
@export var chunk_id:int=0
@export var face_normal:=Vector3.BACK
var tower_ref:WeakRef
var cut:bool=false
var detached:bool=false
var chipped:bool=false
var chip_sign:=Vector2.ONE
var chip_amount:float=0.0

func _ready() -> void:
	super._ready()
	managed_by_building=true
	tower_ref=weakref(get_parent().get_parent())

func receive_damage(event) -> Dictionary:
	var tower=tower_ref.get_ref()
	if not is_instance_valid(tower): return {"changed":false}
	return tower.receive_damage(event)

func erase_panel() -> void:
	if broken: return
	broken=true
	visible=false
	collision_layer=0;collision_mask=0
	for child in get_children():
		if child is CollisionShape3D: child.set_deferred("disabled",true)
		if child is DestructibleSegment:
			child.broken=true;child.collision_layer=0;child.collision_mask=0
		if child is MeshInstance3D and child.name==&"DamageScar":
			child.mesh=null;child.material_override=null;child.queue_free()

func sever(event) -> void:
	if broken or cut: return
	cut=true
	$IntactVisual.hide()
	collision_layer=0;collision_mask=0
	$Collision.set_deferred("disabled",true)
	var size:=local_bounds.size
	var local_direction:Vector3=global_basis.inverse()*event.direction
	var split_axis:=1
	if absf(local_direction.y)>0.65: split_axis=0 if absf(face_normal.z)>0.5 else 2
	var gap:=0.28
	var half:=size
	half[split_axis]=(size[split_axis]-gap)*0.5
	for sign in [-1.0,1.0]:
		var piece:=DestructibleSegment.new()
		piece.name="CutLip"
		piece.managed_by_building=true
		piece.debris_at_hit=true
		piece.local_bounds=AABB(-half*0.5,half)
		piece.position[split_axis]=sign*(size[split_axis]+gap)*0.25
		piece.position+=face_normal*sign*0.09
		var visual:=MeshInstance3D.new();visual.name="IntactVisual"
		var mesh:=BoxMesh.new();mesh.size=half;mesh.material=preload("res://assets/placeholders/paper.tres")
		visual.mesh=mesh;piece.add_child(visual)
		var shape:=BoxShape3D.new();shape.size=half
		var collision:=CollisionShape3D.new();collision.name="Collision";collision.shape=shape;piece.add_child(collision)
		var cap:=MeshInstance3D.new();var cap_mesh:=BoxMesh.new()
		var cap_size:=half;cap_size[split_axis]=0.04;cap_mesh.size=cap_size
		cap_mesh.material=preload("res://assets/placeholders/cut_ink.tres");cap.mesh=cap_mesh
		cap.position[split_axis]=-sign*half[split_axis]*0.5
		visual.add_child(cap)
		add_child(piece)
		piece.force_update_transform()

func chip_corner(event) -> void:
	if chipped or cut or broken: return
	chipped=true
	var axis:=Vector3.RIGHT if absf(face_normal.z)>0.5 else Vector3.FORWARD
	var hit:Vector3=to_local(event.position)
	chip_sign=Vector2(1 if hit.dot(axis)>=0 else -1,1 if hit.y>=0 else -1)
	chip_amount=0.4+float(panel_id%4)*0.13
	var outline:Array[Vector2]=[Vector2(-1,-1),Vector2(1,-1),Vector2(1,1-chip_amount),Vector2(1-chip_amount,1),Vector2(-1,1)]
	var points:=PackedVector3Array()
	for depth in [-0.4,0.4]:
		for uv in outline: points.append(axis*uv.x*chip_sign.x+Vector3.UP*uv.y*chip_sign.y+face_normal*depth)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,4):
		for id:int in [0,i,i+1,5,5+i+1,5+i]: surface.add_vertex(points[id])
	for i in 5:
		var j:=(i+1)%5
		for id:int in [i,j,j+5,i,j+5,i+5]: surface.add_vertex(points[id])
	surface.generate_normals()
	var mesh:=surface.commit();mesh.surface_set_material(0,preload("res://assets/placeholders/paper.tres"))
	$IntactVisual.mesh=mesh
	var shape:=ConvexPolygonShape3D.new();shape.points=points;$Collision.set_deferred("shape",shape)

func scar_surface_point(point:Vector3,normal:Vector3) -> Vector3:
	var p:=point.clamp(local_bounds.position,local_bounds.end)
	if chipped:
		var axis:=Vector3.RIGHT if absf(face_normal.z)>0.5 else Vector3.FORWARD
		var excess:=p.dot(axis)*chip_sign.x+p.y*chip_sign.y-(2-chip_amount-0.015)
		if excess>0: p-=axis*chip_sign.x*excess*0.5+Vector3.UP*chip_sign.y*excess*0.5
	if absf(normal.z)>0.5: p.z=normal.z*0.416
	else: p.x=normal.x*0.416
	return p

func set_macro_moving(moving:bool) -> void:
	detached=moving
	collision_layer=0 if moving or broken or cut else 2
	for child in get_children():
		if child is DestructibleSegment:
			child.collision_layer=0 if moving or child.broken else 2
			child.collision_mask=0 if moving else 4
