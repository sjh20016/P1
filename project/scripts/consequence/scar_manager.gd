class_name RavageScarManager
extends Node

@export var budget:int=384
var marks:Array[WeakRef]=[]
var peak:int=0
var vertices_written:int=0
var material:StandardMaterial3D

func _ready() -> void:
	add_to_group("damage_scars")
	material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(0.012,0.012,0.014)
	material.cull_mode=BaseMaterial3D.CULL_DISABLED

func prune() -> void:
	for i in range(marks.size()-1,-1,-1):
		if not is_instance_valid(marks[i].get_ref()): marks.remove_at(i)

func clear() -> void:
	for item in marks:
		var mark=item.get_ref()
		if is_instance_valid(mark):
			mark.mesh=null;mark.material_override=null;mark.queue_free()
	marks.clear()

func _exit_tree() -> void: clear()

func deposit(owner:Node3D,event,local_center:Vector3,normal:Vector3,extent:float=1.0) -> MeshInstance3D:
	prune()
	while marks.size()>=budget:
		var old=marks.pop_front().get_ref()
		if is_instance_valid(old):
			old.mesh=null;old.material_override=null;old.queue_free()
	var axis:Vector3=owner.global_basis.inverse()*event.direction
	axis=axis.slide(normal).normalized()
	if axis.length_squared()<0.2: axis=Vector3.RIGHT if absf(normal.z)>0.5 else Vector3.FORWARD
	var across:=normal.cross(axis).normalized()
	var data:=PackedVector3Array()
	var random:=RandomNumberGenerator.new();random.seed=event.seed
	var polylines:Array=[]
	if event.type==RavageDamageEvent.Type.SLASH:
		polylines.append([Vector2(-extent,0),Vector2(-0.2,0.07),Vector2(extent,-0.02)])
		polylines.append([Vector2(-0.3,0.03),Vector2(0.1,0.32),Vector2(0.4,0.37)])
	else:
		for i in (8 if event.type!=RavageDamageEvent.Type.PULL else 6):
			var angle:=TAU*float(i)/8.0+random.randf_range(-0.2,0.2)
			var direction:=Vector2(cos(angle),sin(angle))
			polylines.append([Vector2.ZERO,direction*extent*0.3+Vector2(-0.05,0.07),direction*extent*0.64+direction.orthogonal()*0.12,direction*extent])
		for i in 10:
			var a:=Vector2(cos(TAU*i/10.0),sin(TAU*i/10.0))*extent*random.randf_range(0.37,0.55)
			var b:=Vector2(cos(TAU*(i+1)/10.0),sin(TAU*(i+1)/10.0))*extent*0.46
			for uv:Vector2 in [Vector2.ZERO,a,b]: data.append(owner.scar_surface_point(local_center+axis*uv.x+across*uv.y,normal))
	for line:Array in polylines:
		for i in line.size()-1:
			var a:Vector2=line[i];var b:Vector2=line[i+1]
			var width:=0.045 if event.type==RavageDamageEvent.Type.SLASH else 0.032
			var side:Vector2=(b-a).orthogonal().normalized()*width*extent
			for uv:Vector2 in [a-side,b-side,b+side,a-side,b+side,a+side]:
				data.append(owner.scar_surface_point(local_center+axis*uv.x+across*uv.y,normal))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=data
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mark:=MeshInstance3D.new();mark.name="DamageScar";mark.mesh=mesh;mark.material_override=material
	owner.add_child(mark)
	marks.append(weakref(mark));peak=maxi(peak,marks.size());vertices_written+=data.size()
	return mark

