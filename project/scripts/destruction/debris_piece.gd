class_name DebrisPiece
extends RigidBody3D

@export var lifetime: float = 4.5
var age: float = 0.0
var visual: Node3D

func _ready() -> void:
	add_to_group("debris")
	continuous_cd = true
	contact_monitor = false
	collision_layer = 8
	collision_mask = 1
	visual = get_node_or_null("Visual")

func _physics_process(delta: float) -> void:
	age += delta
	if is_instance_valid(visual) and age > lifetime - 0.65:
		visual.scale = Vector3.ONE * maxf(0.01, (lifetime - age) / 0.65)
	if age >= lifetime or global_position.y < -160:
		queue_free()
