extends Node3D

const NAMES=["A / 撞穿白塔","B / 切断与坠落","C / 连锁碰撞","D / 留下伤口"]
const HINTS=["空格起跳并抓正面；撞入后松钩，保持惯性穿出，再抓出口梁。","按住左键抓住前方高梁，向侧下方摆荡，让绷紧触手掠过塔身。","抓前方高梁并向下摆荡切塔；观察落块撞击后塔，再抓残壁。","反复撞击或扫切同一座塔；绕到侧面观察仍然保留的残壁。"]
var scenario:int=0
var towers:Array=[]
var scars:Node
var macros:Node3D
var session:Node3D
var checkpoint:Vector3
var elapsed:float=0
var entry_crossed:bool=false
var exit_crossed:bool=false
var exit_grabbed:bool=false
var metrics:Array[Dictionary]=[]
var metric_clock:float=0
var frame_us:Array[int]=[]
var last_frame:int=0

func _ready() -> void:
	add_to_group("consequence_lab")
	session=get_tree().get_first_node_in_group("session")
	scars=RavageScarManager.new();add_child(scars)
	macros=preload("res://scripts/consequence/macro_manager.gd").new();add_child(macros)
	# A small authored annex leaves the existing 358-tower city and M03 course intact.
	position=Vector3(1000,48,0)
	make_floor()
	var poses:=[Vector3.ZERO,Vector3(38,0,-46),Vector3(38,-6,-69)]
	for i in 3:
		var tower=preload("res://scenes/consequence/breachable_tower.tscn").instantiate()
		tower.name=["BreachTower","SeverTower","ReceiverTower"][i]
		tower.position=poses[i];tower.structural=i>0;tower.fall_direction=Vector3.FORWARD
		add_child(tower);towers.append(tower)
		# Sparse interior beams leave the central flight path open.
		for chunk in 4:
			var y:float=-9+chunk*6
			for z in [-5.8,5.8]:
				var beam:=make_block("内环梁",poses[i]+Vector3(0,y-2.5,z),Vector3(12,0.25,0.5))
				beam.set_meta("macro_group",chunk);beam.reparent(tower,true)
			for x in [-6.0,6.0]:
				var column:=make_block("内柱",poses[i]+Vector3(x,y,0),Vector3(0.4,5.7,0.4))
				column.set_meta("macro_group",chunk);column.reparent(tower,true)
	make_block("出口抓梁",Vector3(0,5,-23),Vector3(14,1.4,1.4))
	make_block("侧向扫切抓梁",Vector3(55,16,-38),Vector3(2,4,2))
	make_block("回程抓梁",Vector3(-16,8,20),Vector3(2,10,2))
	make_block("出发台",Vector3(0,3.1,28),Vector3(10,1,4))
	make_block("切割出发台",Vector3(18,15.1,-46),Vector3(4,1,4))
	make_sign("撞入 / 穿过 / 再次抓取",Vector3(0,13,8.6))
	make_sign("支撑接缝",Vector3(38,2,-37.5))
	make_sign("连锁受击塔",Vector3(38,8,-60.5))
	# Short strokes identify authored weak seams without covering the cut itself.
	for x in [-7.0,7.0]: make_visual(Vector3(38+x,0,-37.55),Vector3(1.4,0.12,0.04),true)

func make_floor() -> void:
	var floor_body:=StaticBody3D.new();floor_body.name="WorldFoundation";floor_body.collision_layer=1;floor_body.collision_mask=0
	add_child(floor_body);floor_body.position=Vector3(20,-19.5,-24)
	var shape:=BoxShape3D.new();shape.size=Vector3(118,1,145)
	var collision:=CollisionShape3D.new();collision.shape=shape;floor_body.add_child(collision)
	var mesh:=BoxMesh.new();mesh.size=shape.size;mesh.material=preload("res://assets/placeholders/paper.tres")
	var visual:=MeshInstance3D.new();visual.mesh=mesh;floor_body.add_child(visual)
	for i in 8:
		make_visual(Vector3(-34,-18.96,25-i*14),Vector3(2,0.02,0.12),true)
	for i in 5:
		make_block("外侧支柱",Vector3(-28,-1,15-i*22),Vector3(3,34,3))

func make_block(title:String,where:Vector3,size:Vector3) -> DestructibleSegment:
	var block:=DestructibleSegment.new();block.name=title;block.position=where;block.managed_by_building=true;block.debris_at_hit=true
	block.local_bounds=AABB(-size*0.5,size)
	var mesh:=BoxMesh.new();mesh.size=size;mesh.material=preload("res://assets/placeholders/paper.tres")
	var visual:=MeshInstance3D.new();visual.name="IntactVisual";visual.mesh=mesh;block.add_child(visual)
	var shape:=BoxShape3D.new();shape.size=size
	var collision:=CollisionShape3D.new();collision.name="Collision";collision.shape=shape;block.add_child(collision)
	add_child(block)
	return block

func make_visual(where:Vector3,size:Vector3,ink:bool=false) -> void:
	var mesh:=BoxMesh.new();mesh.size=size;mesh.material=preload("res://assets/placeholders/cut_ink.tres") if ink else preload("res://assets/placeholders/paper.tres")
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.position=where;add_child(visual)

func make_sign(words:String,where:Vector3) -> void:
	var sign:=Label3D.new();sign.text=words;sign.font=preload("res://assets/placeholders/ui_zh.tres");sign.font_size=48;sign.pixel_size=0.009
	sign.modulate=Color(0.04,0.04,0.045);sign.outline_size=0;sign.position=where;add_child(sign)

func start(which:int=0) -> void:
	scenario=posmod(which,4)
	checkpoint=to_global(Vector3(0,4,28) if scenario==0 or scenario==3 else Vector3(18,16,-46))
	session.player.spawn_position=checkpoint;session.player.reset_player("consequence_lab")
	var shape:SphereShape3D=session.player.get_node("CollisionShape3D").shape.duplicate()
	shape.radius=0.35424;session.player.get_node("CollisionShape3D").shape=shape
	session.player.camera_rig.rotation=Vector3(-0.025,0,0)
	if scenario==1 or scenario==2: session.player.camera_rig.look_at(to_global(Vector3(55,16,-38)))
	session.set_movement_model(2)
	session.notice="后果实验场 / F9 切换实验，F5 重置";session.notice_time=4

func _physics_process(delta:float) -> void:
	elapsed+=delta;metric_clock+=delta
	var p:Vector3=to_local(session.player.global_position)
	if absf(p.x)<7.5 and absf(p.y)<10 and p.z<7 and p.z> -7: entry_crossed=true
	if entry_crossed and p.z< -12: exit_crossed=true
	if exit_crossed:
		for hook in session.player.hooks:
			if hook.active and is_instance_valid(hook.target) and hook.target.global_position.z<global_position.z-15: exit_grabbed=true
	if metric_clock>0.5:
		metric_clock=0;scars.prune()
		if metrics.size()<1200: metrics.append(snapshot())

func _process(_delta:float) -> void:
	var now:=Time.get_ticks_usec()
	if last_frame>0 and frame_us.size()<18000: frame_us.append(now-last_frame)
	last_frame=now

func save_run() -> String:
	DirAccess.make_dir_recursive_absolute("user://consequence004")
	var path:="user://consequence004/run-%d.json" % Time.get_unix_time_from_system()
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return ""
	file.store_string(JSON.stringify({"scenario":scenario,"samples":metrics,"frame_us":frame_us,"macro_activation_us":macros.activation_us,"panel_activation_us":towers.map(func(t):return t.activation_us),"final":snapshot()},"\t"))
	file.close();return path

func snapshot() -> Dictionary:
	var panels:=0;var structural_count:=0
	for tower in towers:
		if tower.panel_mode: panels+=tower.intact_panel_count()
		if tower.structural and tower.panel_mode: structural_count+=1
	return {"time":elapsed,"fps":Engine.get_frames_per_second(),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"active_debris":session.manager.active_debris.size(),"active_macros":macros.active.size(),"static_ruins":macros.ruins.size(),"active_structural_towers":structural_count,"active_panels":panels,"scars":scars.marks.size(),"secondary_events":session.manager.secondary_events,"chain_depth":session.manager.deepest_chain,"collisions":macros.collision_count}
