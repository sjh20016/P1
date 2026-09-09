class_name DestructibleSegment
extends StaticBody3D

@export var broken_scene: PackedScene = preload("res://scenes/destruction/broken_block.tscn")
@export var destruction_threshold: float = 19.0
@export var local_bounds: AABB = AABB(Vector3(-3, -2, -1), Vector3(6, 4, 2))
@export var label: String = "FRACTURE"
@export var debris_at_hit: bool = false
@export var managed_by_building: bool = false
var broken: bool = false
var last_break_time: float = -100.0

func _ready() -> void:
	add_to_group("destructible")
	collision_layer = 2
	collision_mask = 4

func break_segment(hit_position: Vector3, hit_direction: Vector3, strength: float) -> bool:
	if broken or not is_finite(strength) or strength < destruction_threshold:
		return false
	if not hit_position.is_finite() or not hit_direction.is_finite():
		return false
	var manager: DestructionManager = get_tree().get_first_node_in_group("destruction_manager")
	if not is_instance_valid(manager):
		return false
	broken = true
	last_break_time = Time.get_ticks_msec() / 1000.0
	# Disable the collision layer immediately, before the player's move_and_slide.
	collision_layer = 0
	collision_mask = 0
	$IntactVisual.hide()
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	var debris_transform := Transform3D(Basis.IDENTITY,hit_position) if debris_at_hit else global_transform
	manager.emit_broken(broken_scene, debris_transform, hit_position, hit_direction, strength)
	return true

func restore() -> void:
	broken = false
	collision_layer = 2
	collision_mask = 4
	$IntactVisual.show()
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", false)
