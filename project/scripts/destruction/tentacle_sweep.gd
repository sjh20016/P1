class_name TentacleSweep
extends Node

@export var cut_speed_threshold: float = 22.0
@export var tension_threshold: float = 6.0
@export var sweep_speed_threshold: float = 12.0
@export var sweep_radius: float = 0.22
@export var target_cooldown: float = 0.18
@export var spatial_candidates: bool = true
var sweep_event_count: int = 0
var sweep_speed: float = 0.0
var cooldowns: Dictionary = {}
var candidate_count: int = 0
var query_box := BoxShape3D.new()
var query := PhysicsShapeQueryParameters3D.new()
@onready var player: RavagePlayer = get_parent()

func _ready() -> void:
	query.shape=query_box
	query.collision_mask=2
	player.motion_completed.connect(check_sweeps)
	player.reset_performed.connect(func(): cooldowns.clear())

func check_sweeps(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] -= delta
		if cooldowns[key] <= 0:
			cooldowns.erase(key)
	for hook in player.hooks:
		check_hook(hook, delta)
		hook.remember_segment()

func check_hook(hook: GrappleController, delta: float) -> void:
	if not hook.active or not hook.history_valid or delta <= 0:
		return
	sweep_speed = maxf(player.global_position.distance_to(hook.previous_start), hook.grapple_point.distance_to(hook.previous_end)) / delta
	if player.velocity.length() < cut_speed_threshold or hook.tension < tension_threshold or sweep_speed < sweep_speed_threshold:
		return
	# Swept quad = two triangles. Target boxes are authored alongside collision shapes.
	var candidates:=find_candidates(hook)
	candidate_count=candidates.size()
	for segment: DestructibleSegment in candidates:
		if segment.broken or segment == hook.target or cooldowns.has(segment.get_instance_id()):
			continue
		var inverse := segment.global_transform.affine_inverse()
		var a := inverse * hook.previous_start
		var b := inverse * hook.previous_end
		var c := inverse * player.global_position
		var d := inverse * hook.grapple_point
		if SweepGeometry.swept_line_box(a, b, c, d, segment.local_bounds, sweep_radius):
			var center := segment.global_transform * segment.local_bounds.get_center()
			if segment.has_method("sweep_hit"):
				var hit: Variant = segment.sweep_hit(hook.previous_start,hook.previous_end,player.global_position,hook.grapple_point,sweep_radius)
				if hit == null:
					continue
				center = hit
			var manager: DestructionManager=get_tree().get_first_node_in_group("destruction_manager")
			var direction:Vector3=(player.global_position-hook.previous_start).normalized()
			var context:Dictionary={"kind":"SLASH","before":player.velocity.length(),"after":player.velocity.length(),"tension":hook.tension,"normal":(hook.grapple_point-player.global_position).cross(direction).normalized()}
			if manager.break_with_context(segment,center,direction,player.velocity.length(),context):
				cooldowns[segment.get_instance_id()] = target_cooldown
				sweep_event_count += 1

func find_candidates(hook: GrappleController) -> Array:
	if not spatial_candidates:
		return get_tree().get_nodes_in_group("destructible")
	# The physics server prunes distant buildings before the exact swept-quad test.
	var bounds:=AABB(hook.previous_start,Vector3.ZERO)
	for point:Vector3 in [hook.previous_end,player.global_position,hook.grapple_point]:
		bounds=bounds.expand(point)
	bounds=bounds.grow(sweep_radius+0.05)
	query_box.size=bounds.size
	query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	var hits:=player.get_world_3d().direct_space_state.intersect_shape(query,1024)
	# Dense overlap must remain correct instead of silently dropping the 1025th target.
	if hits.size()>=1024:
		return get_tree().get_nodes_in_group("destructible")
	var candidates:Array=[]
	for hit in hits:
		var body:Node=hit.collider
		if body is DestructibleSegment and not candidates.has(body): candidates.append(body)
	return candidates
