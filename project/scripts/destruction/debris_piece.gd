class_name DebrisPiece
extends RigidBody3D

@export var lifetime: float = 4.5
var age: float = 0.0
var visual: Node3D
var visual_scale := Vector3.ONE

func _ready() -> void:
	add_to_group("debris")
	continuous_cd = true
	contact_monitor = false
	collision_layer = 8
	collision_mask = 3
	visual = get_node_or_null("Visual")
	if visual:
		visual_scale = visual.scale

func _physics_process(delta: float) -> void:
	age += delta
	if is_instance_valid(visual) and age > lifetime - 0.65:
		visual.scale = visual_scale * maxf(0.01, (lifetime - age) / 0.65)
	if age >= lifetime or global_position.y < -160:
		queue_free()
