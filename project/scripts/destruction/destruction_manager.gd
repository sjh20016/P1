class_name DestructionManager
extends Node3D

signal destruction_event(hit_position: Vector3, hit_direction: Vector3, strength: float)
signal impact_reported(context: Dictionary)
signal damage_applied(event, result:Dictionary, target)
@export_range(6, 54, 1) var rigidbody_budget: int = 48
@export var debris_lifetime: float = 4.5
@export var ink_art: bool = false
@export var small_impact: ImpactProfile = preload("res://assets/placeholders/impact_small.tres")
@export var medium_impact: ImpactProfile = preload("res://assets/placeholders/impact_medium.tres")
@export var heavy_impact: ImpactProfile = preload("res://assets/placeholders/impact_heavy.tres")
var active_debris: Array[DebrisPiece] = []
var event_count: int = 0
var score: int = 0
var last_hit_position: Vector3
var last_hit_age: float = 100.0
var peak_rigidbodies: int = 0
var last_impact_name: String = ""
var next_context: Dictionary = {}
var last_context: Dictionary = {}
var max_chain_depth:int=2
var damage_events:int=0
var secondary_events:int=0
var deepest_chain:int=0

func break_with_context(target, hit: Vector3, direction: Vector3, strength: float, context: Dictionary) -> bool:
	var event:=RavageDamageEvent.new();event.configure_hit(hit,direction,strength,context)
	return bool(apply_damage(target,event).get("changed",false))

func apply_damage(target,event) -> Dictionary:
	if not is_instance_valid(target) or not event.valid() or event.depth>max_chain_depth or event.type>=RavageDamageEvent.Type.PIERCE:
		return {"changed":false,"rejected":true}
	next_context=event.feedback_context()
	var result:Dictionary
	if target.has_method("receive_damage"):
		result=target.receive_damage(event)
	elif target.has_method("break_segment"):
		result={"changed":target.break_segment(event.position,event.direction,event.energy),"legacy":true}
	else: result={"changed":false}
	next_context.clear()
	if result.get("changed",false):
		damage_events+=1;deepest_chain=maxi(deepest_chain,event.depth)
		if event.type==RavageDamageEvent.Type.COLLAPSE: secondary_events+=1
		damage_applied.emit(event,result,target)
	return result

func impact_profile(strength: float) -> ImpactProfile:
	if strength >= heavy_impact.minimum_speed:
		return heavy_impact
	if strength >= medium_impact.minimum_speed:
		return medium_impact
	return small_impact

func _ready() -> void:
	add_to_group("destruction_manager")

func _physics_process(delta: float) -> void:
	last_hit_age += delta
	prune()

func prune() -> void:
	active_debris = active_debris.filter(func(piece): return is_instance_valid(piece) and not piece.is_queued_for_deletion())

func emit_broken(scene: PackedScene, transform_at_hit: Transform3D, hit: Vector3, direction: Vector3, strength: float) -> void:
	last_context=next_context.duplicate()
	last_context["kind"]=last_context.get("kind","BREAK")
	last_context["position"]=hit
	last_context["direction"]=direction
	last_context["strength"]=strength
	next_context.clear()
	var fracture_scene:PackedScene=preload("res://scenes/consequence/slash_fragments.tscn") if last_context.kind=="SLASH" else scene
	var broken: Node3D = fracture_scene.instantiate()
	if ink_art:
		LivingInkArt.apply(broken)
	var pieces: Array[DebrisPiece] = []
	for child in broken.get_children():
		if child is DebrisPiece:
			pieces.append(child)
	assert(pieces.size() >= (2 if last_context.kind=="SLASH" else 3) and pieces.size() <= 6, "Broken prefab must stay within its authored fragment budget")
	prune()
	while active_debris.size() + pieces.size() > rigidbody_budget:
		var oldest: DebrisPiece = active_debris.pop_front()
		# Immediately remove physics participation; deletion occurs at frame end.
		oldest.freeze = true
		oldest.collision_layer = 0
		oldest.collision_mask = 0
		oldest.queue_free()
	add_child(broken)
	broken.global_transform = transform_at_hit
	for index in pieces.size():
		var piece := pieces[index]
		piece.lifetime = debris_lifetime + float(index % 3) * 0.15
		var outward := (piece.global_position - hit).normalized()
		if outward.length_squared() < 0.1:
			outward = Vector3.UP
		var directional_scale:=0.48 if last_context.kind=="BODY" else 0.34
		var spread:=4.0 if last_context.kind=="BODY" else 7.0
		piece.linear_velocity = direction.normalized() * clampf(strength * directional_scale, 8.0, 32.0) + outward * spread + Vector3.UP * 4.0
		if last_context.kind=="SLASH": piece.linear_velocity=direction.normalized()*3+outward*0.8+Vector3.UP*0.5
		piece.angular_velocity = Vector3(1.3 + index, -2.1 + index * 0.8, 1.7)
		active_debris.append(piece)
	peak_rigidbodies = maxi(peak_rigidbodies, active_debris.size())
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = debris_lifetime + 0.6
	broken.add_child(cleanup)
	cleanup.timeout.connect(broken.queue_free)
	cleanup.start()
	event_count += 1
	last_impact_name = impact_profile(strength).name
	score += roundi(strength * 10.0)
	last_hit_position = hit
	last_hit_age = 0.0
	destruction_event.emit(hit, direction, strength)
	impact_reported.emit(last_context)

func clear_debris() -> void:
	for piece in active_debris:
		if is_instance_valid(piece):
			piece.queue_free()
	active_debris.clear()
	for child in get_children():
		child.queue_free()
