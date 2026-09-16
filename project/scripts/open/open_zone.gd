extends Node3D

const VERSION:String="0.07"
var session:Node3D
var towers:Array=[]
var states:Array[OpenDamageState]=[]
var ruins:Array=[]
var active:Array=[]
var pending:Array=[]
var visited:Dictionary={}
var seams:int=0
var chains:int=0
var chain_targets:Dictionary={}
var clashes:int=0
var clash_pairs:Dictionary={}
var pull_actions:int=0
var dual_pull:Node
var completion_age:float=100
var complete:bool=false
var elapsed:float=0
var scheduler:float=0
var frames_us:Array[int]=[]
var samples:Array[Dictionary]=[]
var last_frame:int=0
var sample_clock:float=0
var build_max_us:int=0
var activation_max_us:int=0
var loading:bool=true
var ready_count:int=0
var marker:Label3D

func _ready() -> void:
	add_to_group("open_zone")
	session=get_tree().get_first_node_in_group("session")
	position=Vector3(2000,48,0)
	make_floor()
	make_platform(Vector3(0,2.5,36),Vector3(12,1,10))
	make_platform(Vector3(14,-2,18),Vector3(1,40,1))
	marker=Label3D.new();marker.font=preload("res://assets/placeholders/ui_zh.tres");marker.font_size=46
	marker.text="撞开前方能量塔，松钩穿出\n右侧黑环双塔：双钩抓两侧，按住 Q"
	marker.pixel_size=0.012;marker.outline_size=0;marker.modulate=Color(0.02,0.02,0.02)
	marker.position=Vector3(0,10,15);add_child(marker)
	session.player.spawn_position=to_global(Vector3(0,4,36))
	session.player.reset_player("open_zone")
	session.player.controls_enabled=false
	session.player.camera_rig.rotation=Vector3(-0.08,0,0)
	session.player.collision_mask=3|16
	var shape:SphereShape3D=session.player.get_node("CollisionShape3D").shape.duplicate()
	shape.radius=0.44;session.player.get_node("CollisionShape3D").shape=shape
	for building in get_tree().get_nodes_in_group("buildings"): building.collision_layer=0
	session.get_node("StaticTowerForest").hide()
	dual_pull=preload("res://scripts/open/dual_pull.gd").new();add_child(dual_pull)

func add_tower(index:int) -> void:
	var state:=OpenDamageState.new();state.id=index
	state.kind=3 if index in [7,15,26] else (2 if index in [0,8,18,29] else (1 if index%7==2 else 0))
	if index in [1,2,22,23]: state.kind=4
	var tower=preload("res://scripts/open/open_tower.gd").new();tower.state=state;tower.zone=self
	tower.name="OpenTower%02d" % index
	var column:=index%6;var row:=index/6
	tower.position=Vector3(column*56,((row+column)%3)*4,-row*56)
	if state.kind==4:
		tower.position.y=4
		if index in [2,23]: tower.position.x-=16
	if index in [13,21,32]:
		var source=towers[index-6]
		tower.position=source.position+Vector3(0,-4,-27)
	add_child(tower);towers.append(tower);states.append(state)
	var base_height:float=tower.position.y+4.0
	if base_height>0.05:
		make_platform(Vector3(tower.position.x,-22+base_height*0.5,tower.position.z),Vector3(16,base_height,16))
	build_max_us=maxi(build_max_us,tower.rebuild_us)

func _process(_delta:float) -> void:
	var now:=Time.get_ticks_usec()
	if loading:
		# One compact building per rendered frame. Controls start after the world is ready.
		add_tower(ready_count);ready_count+=1
		if ready_count==36:
			loading=false;update_interest(true);session.player.controls_enabled=true;last_frame=0
		return
	if last_frame>0 and frames_us.size()<36000: frames_us.append(now-last_frame)
	last_frame=now

func _physics_process(delta:float) -> void:
	if loading: return
	elapsed+=delta;scheduler-=delta;sample_clock-=delta
	completion_age+=delta
	if scheduler<=0: scheduler=0.10;update_interest()
	if not pending.is_empty() and active.size()<3:
		var job:Dictionary=pending.pop_front()
		var tower=job.tower.get_ref()
		if is_instance_valid(tower) and not tower.state.detached:
			var macro=preload("res://scripts/open/open_macro.gd").new();add_child(macro)
			macro.configure(self,tower,job.event);active.append(macro)
	if not complete and visited.size()>=8 and ((seams>=2 and chains>=2) or clashes>=1):
		complete=true;completion_age=0
		session.manager.award_bonus(1500)
	if sample_clock<=0:
		sample_clock=1.0
		if samples.size()<1200: samples.append(snapshot())

func update_interest(immediate:bool=false) -> void:
	var p:Vector3=session.player.global_position
	var predicted:Vector3=p+session.player.velocity*0.8
	var changes:int=0
	for tower in towers+ruins:
		var distance:float=tower.global_position.distance_to(p)
		var wanted:bool=distance<180 or tower.global_position.distance_to(predicted)<120
		if tower.near and distance<210: wanted=true
		for hook in session.player.hooks:
			if hook.active and hook.target==tower: wanted=true
		if tower.near!=wanted:
			# Synchronous safety zone covers the full 150 m grapple range plus travel margin.
			if immediate or distance<170 or changes<2:
				tower.set_near(wanted);changes+=1
				activation_max_us=maxi(activation_max_us,tower.activation_us)

func queue_collapse(tower,event) -> void:
	for job in pending:
		if job.tower.get_ref()==tower: return
	if tower.state.detached: return
	pending.append({"tower":weakref(tower),"event":event})

func has_macro_capacity(count:int) -> bool:
	return active.size()+pending.size()+count<=3

func begin_dual_pull(a,b,anchor_a:Vector3,anchor_b:Vector3,tension:float) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b) or a==b: return false
	if not a.can_pull() or not b.can_pull() or not has_macro_capacity(2): return false
	if not a.anchor_valid(anchor_a) or not b.anchor_valid(anchor_b): return false
	if not is_finite(tension) or tension<dual_pull.MIN_TENSION: return false
	if a.to_local(anchor_a).y< -5 or b.to_local(anchor_b).y< -5: return false
	var span:Vector3=(b.global_position-a.global_position).slide(Vector3.UP)
	if span.length()<24 or span.length()>84 or absf(a.global_position.y-b.global_position.y)>12: return false
	var along:float=(session.player.global_position-a.global_position).dot(span)/span.length_squared()
	if along<0.12 or along>0.88: return false
	# Both admissions complete before either bond changes. These two synchronous
	# events reserve the already checked slots through queue_collapse().
	pull_actions+=1
	var pair:Array=[a,b];var anchors:Array[Vector3]=[anchor_a,anchor_b]
	for i in 2:
		var tower=pair[i];var other=pair[1-i]
		var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.PULL
		var point:Vector3=tower.to_local(anchors[i]);point.y=-6
		event.position=tower.to_global(point)
		event.direction=(other.global_position-tower.global_position).slide(Vector3.UP).normalized()
		event.normal=tower.state.normal(tower.state.face_at(point))
		# A previously weakened bond must still pass the tower's damage threshold.
		event.energy=maxf(tower.destruction_threshold,tower.state.bond/0.6+1);event.tension=tension
		event.source_id=session.player.get_instance_id()
		event.context={"dual_id":pull_actions}
		session.manager.apply_damage(tower,event)
	return true

func resolve_macro_contact(a,b,point:Vector3,normal:Vector3) -> bool:
	# Only a real swept collision enters here. One pair may pay out once per run.
	if maxi(a.source_event.depth,b.source_event.depth)>=2: return false
	var first:int=a.get_instance_id();var second:int=b.get_instance_id()
	var key:String=str(mini(first,second))+":"+str(maxi(first,second))
	if clash_pairs.has(key): return false
	clash_pairs[key]=true
	var dual:bool=int(a.source_event.context.get("dual_id",0))>0 and a.source_event.context.get("dual_id")==b.source_event.context.get("dual_id")
	var energy:float=clampf((a.velocity-b.velocity).length()*3,60,120)
	var changed:bool=false
	for target in [b,a]:
		var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.COLLAPSE
		event.position=point;event.normal=normal if target==b else -normal
		event.direction=-event.normal;event.energy=energy;event.radius=5.0
		event.depth=maxi(a.source_event.depth,b.source_event.depth)+1;event.source_id=a.source_event.source_id
		event.context={"dual_clash":dual and not changed,"dual_id":a.source_event.context.get("dual_id",0)}
		var result:Dictionary=session.manager.apply_damage(target,event)
		changed=changed or result.get("changed",false)
	if changed:
		if dual: clashes+=1
		a.contacts[second]=true;b.contacts[first]=true
		a.velocity*=0.55;b.velocity*=0.55
	return changed

func record_hit(id:int,event,result:Dictionary) -> void:
	if id<1000: visited[id]=true
	if result.get("bond_broken",false): seams+=1
	if event.type==RavageDamageEvent.Type.COLLAPSE and not chain_targets.has(id%1000):
		chain_targets[id%1000]=true;chains+=1

func snapshot() -> Dictionary:
	var near_count:int=0;var surface_count:int=0;var scar_count:int=0
	for tower in towers+ruins:
		if tower.near: near_count+=1
		surface_count+=tower.surfaces.size();scar_count+=tower.marks.multimesh.instance_count
	return {"seconds":elapsed,"buildings":towers.size(),"visited":visited.size(),"seams":seams,"chains":chains,"clashes":clashes,"pull_actions":pull_actions,"complete":complete,"near":near_count,"surfaces":surface_count,"scar_instances":scar_count,"macros":active.size(),"pending":pending.size(),"ruins":ruins.size(),"debris":session.manager.active_debris.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"memory":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"activation_max_us":activation_max_us,"build_max_us":build_max_us}

func save_run(path:String="",workload:Dictionary={}) -> String:
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute("user://open007")
		path="user://open007/run-%d.json" % Time.get_unix_time_from_system()
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return ""
	file.store_string(JSON.stringify({"version":VERSION,"samples":samples,"frames_us":frames_us,"final":snapshot(),"workload":workload},"\t"));file.close()
	return ProjectSettings.globalize_path(path)

func make_platform(where:Vector3,size:Vector3) -> void:
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;body.position=where;add_child(body)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;collision.shape=box;body.add_child(collision)
	var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;mesh.material=preload("res://assets/placeholders/paper.tres")
	visual.mesh=mesh;body.add_child(visual)

func make_floor() -> void:
	make_platform(Vector3(140,-23,-140),Vector3(390,2,390))
	# Widely spaced black floor dashes supply scale and a readable flight grid.
	var view:=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	var mesh:=BoxMesh.new();mesh.size=Vector3(2,0.035,0.3);mesh.material=preload("res://assets/placeholders/cut_ink.tres")
	multi.mesh=mesh;multi.instance_count=121
	for row in 11:
		for col in 11: multi.set_instance_transform(row*11+col,Transform3D(Basis.IDENTITY,Vector3(col*32-20,-21.96,-row*32+20)))
	view.multimesh=multi;add_child(view)

func _exit_tree() -> void:
	pending.clear()
