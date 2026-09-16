class_name DestructionManager
extends Node3D

signal destruction_event(hit_position: Vector3, hit_direction: Vector3, strength: float)
signal impact_reported(context: Dictionary)
signal damage_applied(event, result:Dictionary, target)
signal feedback_beat(context:Dictionary)
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
var combo:int=0
var combo_left:float=0.0
var last_reward:int=0
var reward_text:String=""
var feedback_count:int=0
var _applying:bool=false
var _last_beat_ms:int=-1000
var _last_priority:int=0
var _last_target:int=0
var _reward_age:float=10.0
var _reward_priority:int=0

func break_with_context(target, hit: Vector3, direction: Vector3, strength: float, context: Dictionary) -> bool:
	var event:=RavageDamageEvent.new();event.configure_hit(hit,direction,strength,context)
	return bool(apply_damage(target,event).get("changed",false))

func apply_damage(target,event) -> Dictionary:
	if not is_instance_valid(target) or not event.valid() or event.depth>max_chain_depth or event.type>=RavageDamageEvent.Type.PIERCE:
		return {"changed":false,"rejected":true}
	var previous_context:=next_context
	var previous_applying:=_applying
	next_context=event.feedback_context()
	_applying=true
	var result:Dictionary
	if target.has_method("receive_damage"):
		result=target.receive_damage(event)
	elif target.has_method("break_segment"):
		result={"changed":target.break_segment(event.position,event.direction,event.energy),"legacy":true}
	else: result={"changed":false}
	_applying=previous_applying
	next_context=previous_context
	if result.get("changed",false):
		damage_events+=1;deepest_chain=maxi(deepest_chain,event.depth)
		if event.type==RavageDamageEvent.Type.COLLAPSE: secondary_events+=1
		damage_applied.emit(event,result,target)
		var context:Dictionary=event.feedback_context()
		context.merge(result,true)
		context["position"]=event.position
		context["direction"]=event.direction
		context["strength"]=event.energy
		var recipient=target.tower_ref.get_ref() if target.get("tower_ref") is WeakRef else target
		context["target_id"]=recipient.get_instance_id() if is_instance_valid(recipient) else 0
		publish_result(context)
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
	_reward_age+=delta
	combo_left=maxf(0.0,combo_left-delta)
	if combo_left==0: combo=0
	prune()

func prune() -> void:
	active_debris = active_debris.filter(func(piece): return is_instance_valid(piece) and not piece.is_queued_for_deletion())

func emit_broken(scene: PackedScene, transform_at_hit: Transform3D, hit: Vector3, direction: Vector3, strength: float) -> void:
	var context:=next_context.duplicate()
	context["kind"]=context.get("kind","BREAK")
	context["position"]=hit
	context["direction"]=direction
	context["strength"]=strength
	var fracture_scene:PackedScene=preload("res://scenes/consequence/slash_fragments.tscn") if context.kind=="SLASH" else scene
	var broken: Node3D = fracture_scene.instantiate()
	if ink_art:
		LivingInkArt.apply(broken)
	var pieces: Array[DebrisPiece] = []
	for child in broken.get_children():
		if child is DebrisPiece:
			pieces.append(child)
	assert(pieces.size() >= (2 if context.kind=="SLASH" else 3) and pieces.size() <= 6, "Broken prefab must stay within its authored fragment budget")
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
		var directional_scale:=0.48 if context.kind=="BODY" else 0.34
		var spread:=4.0 if context.kind=="BODY" else 7.0
		piece.linear_velocity = direction.normalized() * clampf(strength * directional_scale, 8.0, 32.0) + outward * spread + Vector3.UP * 4.0
		if context.kind=="SLASH": piece.linear_velocity=direction.normalized()*3+outward*0.8+Vector3.UP*0.5
		piece.angular_velocity = Vector3(1.3 + index, -2.1 + index * 0.8, 1.7)
		active_debris.append(piece)
	peak_rigidbodies = maxi(peak_rigidbodies, active_debris.size())
	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = debris_lifetime + 0.6
	broken.add_child(cleanup)
	cleanup.timeout.connect(broken.queue_free)
	cleanup.start()
	if not _applying: publish_result(context)

func publish_result(context:Dictionary) -> void:
	# Geometry and rewards are immediate. Only the audiovisual beat is rate limited.
	last_context=context.duplicate(true)
	var strength:float=context.get("strength",0.0)
	var target_id:int=context.get("target_id",0)
	var structural:bool=context.get("bond_broken",false)
	var chain:int=context.get("depth",0)
	var priority:=3 if context.get("dual_clash",false) else (2 if structural or chain>0 else 1)
	if target_id!=_last_target and strength>=26:
		combo=mini(combo+1,5)
		_last_target=target_id
	combo_left=5.0
	var base:int=100+mini(int(context.get("removed",0))+int(context.get("severed",0)),12)*12
	if structural: base+=400
	if context.get("dual_clash",false): base+=700
	var earned:=roundi(base*(1.0+0.2*maxi(combo-1,0))*(1.0+0.5*mini(chain,2)))
	score+=earned
	var same_burst:bool=_reward_age<0.14
	last_reward=last_reward+earned if same_burst else earned
	_reward_age=0
	if not same_burst or priority>=_reward_priority:
		_reward_priority=priority
		reward_text="结构断裂" if structural else ("连锁破坏" if chain>0 else ("切开接缝" if context.kind=="SLASH" else "撞开通路"))
		if context.get("boost",false): reward_text="能量释放 · 加速"
		if context.kind=="PULL": reward_text="牵引断裂" if structural else "牵引裂开"
		if context.get("dual_clash",false): reward_text="双塔互撞"
	last_context["reward"]=earned
	event_count+=1
	last_hit_position=context.position
	last_hit_age=0
	last_impact_name=impact_profile(strength).name
	destruction_event.emit(context.position,context.direction,strength)
	impact_reported.emit(last_context.duplicate(true))
	var now:=Time.get_ticks_msec()
	if now-_last_beat_ms>=140 or (priority>_last_priority and now-_last_beat_ms>=45):
		_last_beat_ms=now
		_last_priority=priority
		feedback_count+=1
		feedback_beat.emit(last_context.duplicate(true))

func award_bonus(points:int) -> void:
	# The contract panel owns this announcement, preserving the hit that completed it.
	score+=maxi(0,points)

func reset_feedback() -> void:
	combo=0;combo_left=0;_last_target=0;last_reward=0;reward_text=""
	_last_beat_ms=-1000;_last_priority=0;_reward_age=10;_reward_priority=0;feedback_count=0

func clear_debris() -> void:
	for piece in active_debris:
		if is_instance_valid(piece):
			piece.queue_free()
	active_debris.clear()
	for child in get_children():
		child.queue_free()
