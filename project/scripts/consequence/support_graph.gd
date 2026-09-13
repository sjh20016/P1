class_name RavageSupportGraph
extends RefCounted

var nodes:Dictionary={}
var bonds:Array[Dictionary]=[]

func configure(authored_nodes:Array,authored_bonds:Array) -> void:
	nodes.clear();bonds.clear()
	for row in authored_nodes: nodes[int(row.id)]=row.duplicate(true)
	for row in authored_bonds: bonds.append(row.duplicate(true))

func weaken(index:int,amount:float) -> bool:
	if index<0 or index>=bonds.size() or amount<=0: return false
	var bond:Dictionary=bonds[index]
	if bond.get("broken",false): return false
	bond.health=maxf(0.0,float(bond.health)-amount)
	if bond.health<=0:
		bond["broken"]=true
		return true
	return false

func neighbors(id:int) -> Array[int]:
	var result:Array[int]=[]
	for bond in bonds:
		if bond.get("broken",false): continue
		var other:int=-1
		if int(bond.a)==id: other=int(bond.b)
		elif int(bond.b)==id: other=int(bond.a)
		if other>=0 and nodes[other].get("active",true): result.append(other)
	return result

func detached_components() -> Array:
	# Flood once from all world supports, then collect unsupported components.
	var reached:Dictionary={}
	var queue:Array[int]=[]
	for id:int in nodes:
		if nodes[id].get("support",false) and nodes[id].get("active",true):
			queue.append(id);reached[id]=true
	var cursor:=0
	while cursor<queue.size():
		var id:=queue[cursor];cursor+=1
		for other in neighbors(id):
			if not reached.has(other): reached[other]=true;queue.append(other)
	var components:Array=[]
	for id:int in nodes:
		if reached.has(id) or not nodes[id].get("active",true): continue
		var component:Array[int]=[id]
		reached[id]=true;cursor=0
		while cursor<component.size():
			var current:=component[cursor];cursor+=1
			for other in neighbors(current):
				if not reached.has(other): reached[other]=true;component.append(other)
		components.append(component)
	return components

func detach(component:Array) -> void:
	for id in component: nodes[int(id)]["active"]=false
