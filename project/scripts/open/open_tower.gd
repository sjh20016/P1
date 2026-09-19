extends DestructibleSegment

var state:OpenDamageState
var zone:Node3D
var near:bool=false
var moving:bool=false
var surfaces:Array=[]
var shape_boxes:Array[AABB]=[]
var visual:MultiMeshInstance3D
var marks:MultiMeshInstance3D
var cue:Node3D
var activation_us:int=0
var rebuild_us:int=0
var pull_charge:float=0
var pull_ink:MultiMeshInstance3D

func _ready() -> void:
	super._ready()
	managed_by_building=true
	if state==null: state=OpenDamageState.new()
	local_bounds=AABB(Vector3(-8.4,-18,-8.4),Vector3(16.8,36,16.8))
	destruction_threshold=38.0 if state.kind==1 else 26.0
	structure_weight=2 if state.kind==1 else 1
	visual=MultiMeshInstance3D.new();visual.name="IntactVisual";add_child(visual)
	marks=MultiMeshInstance3D.new();add_child(marks)
	visual.multimesh=MultiMesh.new();visual.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var mesh:=BoxMesh.new();mesh.size=Vector3.ONE
	var paper:=ShaderMaterial.new();paper.shader=preload("res://shaders/open_wall.gdshader");mesh.material=paper
	visual.multimesh.mesh=mesh
	marks.multimesh=MultiMesh.new();marks.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	var black:=BoxMesh.new();black.size=Vector3.ONE;black.material=preload("res://assets/placeholders/cut_ink.tres")
	marks.multimesh.mesh=black
	rebuild()
	make_cue()

func make_cue() -> void:
	if state.kind==0 or moving: return
	cue=Node3D.new();add_child(cue)
	var title:=Label3D.new();title.font=preload("res://assets/placeholders/ui_zh.tres");title.font_size=48
	title.pixel_size=0.035;title.outline_size=0;title.modulate=Color(0.03,0.03,0.03)
	title.position=Vector3(0,21,0);title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	title.text=["","重壳 38+","能量 / 加速","弱缝 / 连锁","牵引核 / 双钩 + Q"][state.kind]
	cue.add_child(title)
	for side in 4:
		var n:=state.normal(side)
		var bar:=MeshInstance3D.new();var mesh:=BoxMesh.new()
		mesh.size=Vector3(15,0.18,0.12) if side<2 else Vector3(0.12,0.18,15)
		mesh.material=preload("res://assets/placeholders/cut_ink.tres");bar.mesh=mesh
		bar.position=n*8.46+Vector3.UP*(-6 if state.kind in [3,4] else 8)
		cue.add_child(bar)
	if state.kind==4: make_pull_cue()

func can_pull() -> bool:
	return state.kind==4 and near and not moving and not state.detached and state.bond>0

func target_hint() -> String:
	if state.detached: return "残塔 / 可继续撞开和抓取"
	if state.kind==2 and state.boost_used: return "能量已释放 / 继续寻找下一个目标"
	return ["普通墙 / 正面撞击 26+","重壳 / 正面撞击 38+","能量 / 首次撞开获得加速","弱缝 / 绷紧触手扫过下方黑线","牵引核 / 双钩抓两座，按住 Q"][state.kind]

func make_pull_cue() -> void:
	var eye_mesh:=TorusMesh.new();eye_mesh.inner_radius=1.2;eye_mesh.outer_radius=1.5
	eye_mesh.rings=20;eye_mesh.ring_segments=6;eye_mesh.material=preload("res://assets/placeholders/cut_ink.tres")
	for side in 4:
		var eye:=MeshInstance3D.new();eye.mesh=eye_mesh
		eye.quaternion=Quaternion(Vector3.UP,state.normal(side))
		eye.position=state.normal(side)*8.46+Vector3.UP*6;cue.add_child(eye)
	pull_ink=MultiMeshInstance3D.new();pull_ink.position.y=-6;cue.add_child(pull_ink)
	var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
	var mesh:=BoxMesh.new();mesh.size=Vector3.ONE;mesh.material=preload("res://assets/placeholders/cut_ink.tres")
	multi.mesh=mesh;multi.instance_count=16
	for side in 4:
		var n:=state.normal(side);var tangent:=Vector3.RIGHT if side<2 else Vector3.BACK
		for branch in 4:
			var direction:Vector3=(Vector3.UP+tangent*(float(branch)-1.5)*0.3).normalized()
			var crosswise:Vector3=n.cross(direction).normalized()
			multi.set_instance_transform(side*4+branch,Transform3D(Basis(direction*7.0,crosswise*0.18,n*0.035),n*8.46+tangent*(branch-1.5)*2.0+Vector3.UP*3.5))
	pull_ink.multimesh=multi;pull_ink.visible=false

func set_pull_charge(value:float) -> void:
	pull_charge=clampf(value,0,1)
	if is_instance_valid(pull_ink):
		pull_ink.visible=pull_charge>0.01
		pull_ink.scale=Vector3(1,maxf(0.001,pull_charge),1)

func set_near(value:bool) -> void:
	if near==value: return
	var started:=Time.get_ticks_usec()
	near=value
	rebuild_collision()
	activation_us=Time.get_ticks_usec()-started

func rebuild() -> void:
	var started:=Time.get_ticks_usec()
	shape_boxes=state.boxes()
	visual.multimesh.instance_count=shape_boxes.size()
	for i in shape_boxes.size():
		var b:=shape_boxes[i]
		visual.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(b.size),b.get_center()))
	rebuild_marks()
	rebuild_collision()
	if is_instance_valid(cue): cue.visible=not state.boost_used and not state.detached
	rebuild_us=Time.get_ticks_usec()-started

func rebuild_collision() -> void:
	# Replace collision bodies atomically: old layers go dark before the next motion test.
	for body in surfaces:
		body.collision_layer=0;body.collision_mask=0;body.remove_from_group("destructible");body.queue_free()
	surfaces.clear()
	collision_layer=2 if near and not moving else 0
	if not near or moving: return
	for bounds in shape_boxes:
		var body=preload("res://scripts/open/open_surface.gd").new()
		body.tower_ref=weakref(self);body.position=bounds.get_center()
		body.local_bounds=AABB(-bounds.size*0.5,bounds.size)
		body.face_normal=state.normal(state.face_at(body.position))
		body.structure_weight=structure_weight;body.destruction_threshold=destruction_threshold;body.managed_by_building=true
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=bounds.size;shape.shape=box
		body.add_child(shape);add_child(body);body.force_update_transform();surfaces.append(body)

func anchor_valid(point:Vector3) -> bool:
	if not near or moving: return false
	var p:=to_local(point)
	for bounds in shape_boxes:
		if bounds.grow(0.12).has_point(p): return true
	return false

func receive_damage(event) -> Dictionary:
	if moving or event.energy<destruction_threshold: return {"changed":false}
	var result:=state.apply(to_local(event.position),event)
	if not result.changed: return result
	rebuild()
	var manager=get_tree().get_first_node_in_group("destruction_manager")
	manager.emit_broken(broken_scene,Transform3D(Basis.IDENTITY,event.position),event.position,event.direction,event.energy)
	if result.bond_broken and is_instance_valid(zone): zone.queue_collapse(self,event)
	if is_instance_valid(zone): zone.record_hit(state.id,event,result)
	return result

func rebuild_marks() -> void:
	var transforms:Array[Transform3D]=[]
	for scar in state.scars:
		var n:=state.normal(int(scar.face))
		var tangent:=Vector3.RIGHT if int(scar.face)<2 else Vector3.BACK
		var origin:Vector3=scar.point
		origin=origin.slide(n)+n*8.425
		# Strokes attach only to surviving shell, and remain with the tower/ruin.
		var pulled:bool=scar.get("pull",false)
		for i in (3 if scar.slash else (5 if pulled else 8)):
			var angle:float=0.0 if scar.slash else (lerpf(PI*0.12,PI*0.88,i/4.0) if pulled else TAU*i/8.0)
			var direction:Vector3=(tangent*cos(angle)+Vector3.UP*sin(angle)).normalized()
			var center:Vector3=origin+direction*(3.2 if not scar.slash else (i-1)*2.0)
			var on_shell:bool=false
			for step in range(1,13):
				center=origin+direction*(float(step)*0.75 if not scar.slash else (i-1)*2.0)+Vector3.UP*(0.35 if scar.slash else 0.0)
				for box in shape_boxes:
					if box.grow(0.08).has_point(center): on_shell=true;break
				if on_shell: break
			if not on_shell: continue
			var across:Vector3=n.cross(direction).normalized()
			transforms.append(Transform3D(Basis(direction*2.6,across*0.13,n*0.025),center))
	marks.multimesh.instance_count=transforms.size()
	for i in transforms.size(): marks.multimesh.set_instance_transform(i,transforms[i])

func sweep_hit(a:Vector3,b:Vector3,c:Vector3,d:Vector3,radius:float) -> Variant:
	var inv:=global_transform.affine_inverse()
	for box in shape_boxes:
		if SweepGeometry.swept_line_box(inv*a,inv*b,inv*c,inv*d,box,radius):
			var hit:Variant=box.grow(radius).intersects_segment(inv*c,inv*d)
			return global_transform*(hit if hit!=null else box.get_center())
	return null
