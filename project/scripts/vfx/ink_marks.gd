class_name InkMarks
extends MeshInstance3D

## Bounded batches of ray-projected polygons. Only changed 32-stamp batches are uploaded.
const BATCH_SIZE: int = 32
@export_range(32,2048,32) var mark_budget: int = 768
@export var dry_seconds: float = 7.0
@export var scrape_interval: float = 0.07
var marks: Array[Dictionary] = []
var clock: float = 0.0
var dirty: bool = false
var scrape_clock: float = 0.0
var batch_clock: float = 0.0
var last_contact: Vector3 = Vector3.INF
var deposited_count: int = 0
var geometry := ArrayMesh.new()
var batches: Dictionary = {}
var dirty_batches: Dictionary = {}
var ink := ShaderMaterial.new()
var player: RavagePlayer
var manager: DestructionManager
var pending_impacts: Array[Dictionary] = []
var last_motion := Vector3.ZERO

func _ready() -> void:
	add_to_group("ink_marks")
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = geometry
	batches[0] = geometry
	ink.shader = preload("res://shaders/ink_stain.gdshader")
	ink.set_shader_parameter("dry_seconds",dry_seconds)
	player = get_tree().get_first_node_in_group("player")
	manager = get_tree().get_first_node_in_group("destruction_manager")
	for hook in player.hooks:
		hook.attached.connect(on_hook.bind(hook,false))
		hook.released.connect(on_hook.bind(hook,true))
	player.motion_requested.connect(func(_motion: Vector3,velocity: Vector3): last_motion=velocity)
	player.motion_completed.connect(on_motion)
	manager.destruction_event.connect(on_break)

func on_hook(hook: GrappleController, releasing: bool) -> void:
	if not is_instance_valid(hook.target):
		return
	var normal := (player.global_position-hook.grapple_point).normalized()
	var query := PhysicsRayQueryParameters3D.create(hook.grapple_point+normal*2.0,hook.grapple_point-normal*2.0,3,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		deposit(hit.position,hit.normal,hit.collider,0.35 if releasing else 0.8)

func on_break(position_at_hit: Vector3,direction: Vector3,strength: float) -> void:
	if manager.last_context.get("local_scars",false): return
	pending_impacts.append({"point":position_at_hit,"direction":direction,"strength":strength,"kind":manager.last_context.get("kind","BREAK")})
	prune()

func on_motion(delta: float) -> void:
	scrape_clock -= delta
	if scrape_clock > 0:
		return
	scrape_clock = scrape_interval
	if last_motion.length()>7 and player.get_slide_collision_count()>0:
		var contact := player.get_slide_collision(0)
		var point := contact.get_position()
		if not last_contact.is_finite() or point.distance_to(last_contact)>0.35:
			deposit(point,contact.get_normal(),contact.get_collider(),clampf(last_motion.length()*0.025,0.45,1.65),last_motion)
			last_contact=point
	for hook in player.hooks:
		if hook.active and hook.tension>6:
			var query := PhysicsRayQueryParameters3D.create(player.global_position,hook.grapple_point,3,[player.get_rid(),hook.target.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				deposit(hit.position,hit.normal,hit.collider,0.5,last_motion)

func _physics_process(_delta: float) -> void:
	# Re-query after the destroyed collider has been disabled, then stain remaining edges.
	for impact in pending_impacts:
		var point: Vector3 = impact.point
		for i in 12:
			var angle := TAU*float(i)/12.0
			var bias:Vector3=impact.direction*0.75 if impact.kind=="BODY" else Vector3.ZERO
			var direction := (Vector3(cos(angle),sin(angle)*0.75,sin(angle+0.8))+bias).normalized()
			var query := PhysicsRayQueryParameters3D.create(point+direction*0.12,point+direction*17.0,3,[player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				var slash:bool=impact.kind=="SLASH"
				deposit(hit.position,hit.normal,hit.collider,0.35 if slash else clampf(float(impact.strength)*0.035,0.9,2.3),impact.direction*20.0)
	pending_impacts.clear()

func deposit(point: Vector3, normal: Vector3, target: Object, radius: float, stroke: Vector3 = Vector3.ZERO) -> bool:
	if is_instance_valid(target) and (target.has_method("grapple_anchor") or target.has_method("anchor_valid")): return false
	if not target is StaticBody3D or target.collision_layer==0 or not point.is_finite() or normal.length_squared()<0.5:
		return false
	# Training rings have spherical aim assists; do not paint the empty space inside them.
	if str(target.name).begins_with("Anchor") or target.name==&"PracticeAnchor":
		return false
	if not marks.is_empty() and marks[-1].point.distance_to(point)<radius*0.3 and clock-marks[-1].birth<0.25:
		return false
	var tangent := Vector3.UP.cross(normal).normalized()
	if tangent.length_squared()<0.1:
		tangent = Vector3.RIGHT
	var vertical := normal.cross(tangent).normalized()
	var drift := stroke.slide(normal).normalized()
	if drift.length_squared()>0.1:
		tangent = drift
		vertical = normal.cross(tangent).normalized()
	var points := PackedVector3Array([point+normal*0.025])
	var uvs := PackedVector2Array([Vector2(0.5,0.5)])
	var valid: Array[bool] = [true]
	var sides := 24
	var rings := 3
	var seed := float(deposited_count)*0.731+0.1
	# Concentric samples conform to curved towers: a single fan would sink into the cylinder.
	for ring in range(1,rings+1):
		for i in sides:
			var angle := TAU*float(i)/sides
			var irregular := 0.88+0.09*sin(angle*3.0+seed)+0.055*cos(angle*7.0+seed)
			var x := cos(angle)*irregular
			var y := sin(angle)*irregular
			if stroke.length_squared()>1:
				x *= 2.0
			elif y < -0.7:
				y *= 1.55
			x *= float(ring)/rings
			y *= float(ring)/rings
			var sample := point+(tangent*x+vertical*y)*radius
			var query := PhysicsRayQueryParameters3D.create(sample+normal*0.7,sample-normal*1.3,3,[player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			var ok: bool = not hit.is_empty() and hit.collider==target and hit.normal.dot(normal)>0.6
			valid.append(ok)
			points.append(hit.position+hit.normal*0.025 if ok else sample)
			uvs.append(Vector2(x,y)*0.5+Vector2.ONE*0.5)
	var vertices := PackedVector3Array()
	var texcoords := PackedVector2Array()
	for i in sides:
		var j := (i+1)%sides
		var triangles: Array[Vector3i] = [Vector3i(0,1+i,1+j)]
		for ring in range(1,rings):
			var inner := 1+(ring-1)*sides
			var outer := 1+ring*sides
			triangles.append(Vector3i(inner+i,outer+i,outer+j))
			triangles.append(Vector3i(inner+i,outer+j,inner+j))
		for triangle in triangles:
			if valid[triangle.x] and valid[triangle.y] and valid[triangle.z]:
				for index in [triangle.x,triangle.y,triangle.z]:
					vertices.append(points[index])
					texcoords.append(uvs[index])
	if vertices.is_empty():
		return false
	while marks.size()>=mark_budget:
		var removed: Dictionary = marks.pop_front()
		dirty_batches[int(removed.slot)/BATCH_SIZE as int] = true
	var slot := deposited_count%mark_budget
	marks.append({"owner":weakref(target),"point":point,"vertices":vertices,"uv":texcoords,"birth":clock,"seed":seed,"slot":slot})
	dirty_batches[slot/BATCH_SIZE as int] = true
	deposited_count += 1
	dirty = true
	return true

func prune() -> void:
	for index in range(marks.size()-1,-1,-1):
		var target: Object = marks[index].owner.get_ref()
		if is_instance_valid(target) and target.collision_layer==0 and target.has_method("resolve_grapple"):
			target = target.resolve_grapple(marks[index].point)
			if target:
				marks[index].owner = weakref(target)
		if not is_instance_valid(target) or target.collision_layer==0:
			dirty_batches[int(marks[index].slot)/BATCH_SIZE as int] = true
			marks.remove_at(index)
			dirty = true

func _process(delta: float) -> void:
	clock += delta
	ink.set_shader_parameter("ink_clock",clock)
	batch_clock -= delta
	if batch_clock<=0:
		batch_clock=0.08
		prune()
		if dirty:
			rebuild()

func rebuild() -> void:
	dirty=false
	for batch_id: int in dirty_batches:
		rebuild_batch(batch_id)
	dirty_batches.clear()

func rebuild_batch(batch_id: int) -> void:
	if not batches.has(batch_id):
		var part := MeshInstance3D.new()
		part.name = "Batch%02d" % batch_id
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part_mesh := ArrayMesh.new()
		part.mesh = part_mesh
		add_child(part)
		batches[batch_id] = part_mesh
	var batch: ArrayMesh = batches[batch_id]
	batch.clear_surfaces()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var ages := PackedVector2Array()
	for mark in marks:
		if int(mark.slot)/BATCH_SIZE as int != batch_id:
			continue
		vertices.append_array(mark.vertices)
		uvs.append_array(mark.uv)
		for i in mark.vertices.size():
			ages.append(Vector2(mark.birth,mark.seed))
	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_TEX_UV2]=ages
	batch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	batch.surface_set_material(0,ink)

func render_batch_count() -> int:
	var count := 0
	for batch: ArrayMesh in batches.values():
		if batch.get_surface_count()>0:
			count += 1
	return count

func clear_marks() -> void:
	marks.clear()
	pending_impacts.clear()
	for batch: ArrayMesh in batches.values():
		batch.clear_surfaces()
	dirty_batches.clear()
	dirty=false
	deposited_count=0
	last_contact=Vector3.INF
