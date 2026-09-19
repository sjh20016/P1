class_name RavageDamageEvent
extends RefCounted

enum Type { RAM, SLASH, PULL, COLLAPSE, PIERCE, SPIN }
var type:Type=Type.RAM
var position:=Vector3.ZERO
var normal:=Vector3.BACK
var direction:=Vector3.FORWARD
var source_velocity:=Vector3.ZERO
var energy:float=0.0
var tension:float=0.0
var radius:float=2.6
var depth:int=0
var source_id:int=0
var seed:int=4
var context:Dictionary={}

func configure_hit(hit:Vector3,axis:Vector3,strength:float,data:Dictionary) -> void:
	position=hit
	direction=axis.normalized()
	energy=strength
	normal=data.get("normal",-direction)
	source_velocity=direction*float(data.get("before",strength))
	tension=float(data.get("tension",0.0))
	context=data.duplicate()
	type={"BODY":Type.RAM,"RAM":Type.RAM,"SLASH":Type.SLASH,"PULL":Type.PULL,"COLLAPSE":Type.COLLAPSE}.get(data.get("kind","BODY"),Type.RAM)
	depth=int(data.get("depth",0))
	radius=float(data.get("radius",2.6))
	source_id=int(data.get("source_id",0))

func valid() -> bool:
	return position.is_finite() and direction.is_finite() and normal.is_finite() and is_finite(energy) and energy>0 and depth>=0

func feedback_context() -> Dictionary:
	var data:=context.duplicate()
	data["kind"]=["BODY","SLASH","PULL","COLLAPSE","PIERCE","SPIN"][type]
	data["normal"]=normal
	data["depth"]=depth
	data["source_id"]=source_id
	return data
