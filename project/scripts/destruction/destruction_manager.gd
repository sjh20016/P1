class_name DestructionManager
extends Node3D

signal destruction_event(hit_position: Vector3, hit_direction: Vector3, strength: float)
@export_range(6, 54, 1) var rigidbody_budget: int = 48
@export var debris_lifetime: float = 4.5
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
	var broken: Node3D = scene.instantiate()
	var pieces: Array[DebrisPiece] = []
	for child in broken.get_children():
		if child is DebrisPiece:
			pieces.append(child)
	assert(pieces.size() >= 3 and pieces.size() <= 6, "Broken prefab must contain 3–6 prebuilt rigid bodies")
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
		piece.linear_velocity = direction.normalized() * clampf(strength * 0.34, 8.0, 26.0) + outward * 7.0 + Vector3.UP * 4.0
		piece.angular_velocity = Vector3(1.3 + index, -2.1 + index * 0.8, 1.7)
		active_debris.append(piece)
	peak_rigidbodies = maxi(peak_rigidbodies, active_debris.size())
	get_tree().create_timer(debris_lifetime + 0.6, false).timeout.connect(func():
		if is_instance_valid(broken):
			broken.queue_free())
	event_count += 1
	last_impact_name = impact_profile(strength).name
	score += roundi(strength * 10.0)
	last_hit_position = hit
	last_hit_age = 0.0
	destruction_event.emit(hit, direction, strength)

func clear_debris() -> void:
	for piece in active_debris:
		if is_instance_valid(piece):
			piece.queue_free()
	active_debris.clear()
	for child in get_children():
		child.queue_free()
