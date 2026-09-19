class_name OpenDamageState
extends RefCounted

# 96 logical cells; no per-cell nodes. 0 solid, 1 hole, 2 horizontal cut, 3 detached.
const COLS:int=4
const ROWS:int=6
var id:int=0
var kind:int=0 # shell, resistant, energy, structural, pull core
var cells:=PackedByteArray()
var cut_offsets:=PackedFloat32Array()
var scars:Array[Dictionary]=[]
var bond:float=100.0
var detached:bool=false
var boost_used:bool=false
var revision:int=0

func _init() -> void:
	cells.resize(96);cells.fill(0)
	cut_offsets.resize(96);cut_offsets.fill(0.0)

func center(index:int) -> Vector3:
	var face:=index/24
	var column:=index%4
	var row:=(index%24)/4
	return Vector3(column*4-6,row*6-15,8 if face==0 else -8) if face<2 else Vector3(8 if face==2 else -8,row*6-15,column*4-6)

func normal(face:int) -> Vector3:
	return [Vector3.BACK,Vector3.FORWARD,Vector3.RIGHT,Vector3.LEFT][face]

func face_at(point:Vector3) -> int:
	return (0 if point.z>=0 else 1) if absf(point.z)>=absf(point.x) else (2 if point.x>=0 else 3)

func apply(point:Vector3,event) -> Dictionary:
	var face:=face_at(point)
	if event.type==RavageDamageEvent.Type.PULL:
		# Tension acts on the marked bond, even if a nearby shell panel is missing.
		if kind not in [3,4] or detached or bond<=0 or absf(point.y+6.0)>=4.0:
			return {"changed":false}
		bond=maxf(0.0,bond-event.energy*0.6)
		revision+=1
		if scars.size()>=8: scars.pop_front()
		scars.append({"point":point,"face":face,"slash":false,"pull":true})
		return {"changed":true,"removed":0,"severed":0,"bond_broken":bond==0,"boost":false,"local_scars":true}
	var nearest:int=-1
	var distance:float=INF
	for index in range(face*24,(face+1)*24):
		if cells[index]==1 or cells[index]==3: continue
		var d:=center(index).distance_squared_to(point)
		if d<distance: distance=d;nearest=index
	if nearest<0 or distance>49: return {"changed":false}
	var removed:int=0
	var severed:int=0
	var slash:bool=event.type==RavageDamageEvent.Type.SLASH
	var row:=(nearest%24)/4
	for index in range(face*24,(face+1)*24):
		if cells[index]==1 or cells[index]==3: continue
		var delta:=center(index)-point
		var bounds:=box(face,center(index),Vector2(4,6))
		var in_wound:bool=index==nearest or point.distance_to(point.clamp(bounds.position,bounds.end))<event.radius*0.65
		if slash:
			in_wound=(index%24)/4==row and delta.slide(normal(face)).length()<6.5
			if in_wound and cells[index]==0:
				cells[index]=2;cut_offsets[index]=clampf(point.y-center(index).y,-2.8,2.8);severed+=1
		elif event.type!=RavageDamageEvent.Type.PULL and in_wound:
			cells[index]=1;removed+=1
	var previous:=bond
	# A marked seam is a gameplay rule, not an invisible general structural solver.
	if kind in [3,4] and not detached and absf(point.y+6.0)<4.0:
		bond=maxf(0.0,bond-event.energy*(2.4 if slash else 0.6))
	var broken:bool=previous>0 and bond==0
	var changed:bool=removed+severed>0 or previous>bond
	var boost:bool=changed and kind==2 and not boost_used and event.type==RavageDamageEvent.Type.RAM
	if boost: boost_used=true
	if changed:
		revision+=1
		if scars.size()>=8: scars.pop_front()
		scars.append({"point":point,"face":face,"slash":slash})
	return {"changed":changed,"removed":removed,"severed":severed,"bond_broken":broken,"boost":boost,"local_scars":true}

func boxes() -> Array[AABB]:
	var result:Array[AABB]=[]
	# Greedy rectangles combine intact cells; cuts retain two thin-separated lips.
	var used:=PackedByteArray();used.resize(96);used.fill(0)
	for face in 4:
		for row in ROWS:
			for col in COLS:
				var index:=face*24+row*4+col
				if used[index]==1 or cells[index]==1 or cells[index]==3: continue
				if cells[index]==2:
					var cut:=cut_offsets[index]
					var lower:=cut+3.0-0.24;var upper:=3.0-cut-0.24
					if lower>0.05: result.append(box(face,center(index)+Vector3.UP*(-3+lower*0.5),Vector2(4,lower)))
					if upper>0.05: result.append(box(face,center(index)+Vector3.UP*(3-upper*0.5),Vector2(4,upper)))
					used[index]=1;continue
				var w:=1
				while col+w<COLS and cells[index+w]==0 and used[index+w]==0: w+=1
				var h:=1
				while row+h<ROWS:
					var extend:=true
					for x in w:
						if cells[index+h*4+x]!=0 or used[index+h*4+x]!=0: extend=false;break
					if not extend: break
					h+=1
				for y in h:
					for x in w: used[index+y*4+x]=1
				var c:=center(index)+Vector3.UP*(h-1)*3
				c+=(Vector3.RIGHT if face<2 else Vector3.BACK)*(w-1)*2
				result.append(box(face,c,Vector2(w*4,h*6)))
	return result

func box(face:int,c:Vector3,size:Vector2) -> AABB:
	var extent:=Vector3(size.x,size.y,0.8) if face<2 else Vector3(0.8,size.y,size.x)
	return AABB(c-extent*0.5,extent)

func take_upper() -> OpenDamageState:
	var part:=OpenDamageState.new();part.id=id+1000;part.kind=0;part.cells.fill(1)
	for i in 96:
		if (i%24)/4>=2:
			part.cells[i]=cells[i];part.cut_offsets[i]=cut_offsets[i];cells[i]=3
	for scar in scars:
		if scar.point.y>=-6: part.scars.append(scar.duplicate(true))
	scars=scars.filter(func(s):return s.point.y < -6)
	detached=true;revision+=1
	return part

func signature() -> String:
	return str(id)+":"+str(cells.hex_encode())+":"+str(cut_offsets)+":"+str(bond)+":"+str(boost_used)
