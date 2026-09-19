class_name DestructibleBuilding
extends DestructibleSegment

## The complete mesh is cheap to draw. The offline-authored sections appear on first hit.
@export var sections_scene: PackedScene
@export var section_bounds: Array[AABB] = []
@export var source_name: String = ""
var detailed: Node3D
var sections: Array[DestructibleSegment] = []

func _ready() -> void:
	super._ready()
	add_to_group("buildings")

func activate() -> void:
	if is_instance_valid(detailed):
		return
	detailed = sections_scene.instantiate()
	add_child(detailed)
	sections.clear()
	for child in detailed.get_children():
		if child is DestructibleSegment:
			sections.append(child)
	collision_layer = 0
	collision_mask = 0
	$IntactVisual.hide()
	remove_from_group("destructible")
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)

func section_index_at(world_point: Vector3) -> int:
	var local := to_local(world_point)
	var nearest := 0
	var distance := INF
	for i in section_bounds.size():
		var box := section_bounds[i].grow(0.04)
		if box.has_point(local):
			return i
		var closest := local.clamp(box.position, box.end)
		var d := closest.distance_squared_to(local)
		if d < distance:
			distance = d
			nearest = i
	return nearest

func resolve_grapple(world_point: Vector3) -> StaticBody3D:
	if not is_instance_valid(detailed):
		return self
	var index := section_index_at(world_point)
	if index < sections.size() and not sections[index].broken:
		return sections[index]
	return null

func break_segment(hit_position: Vector3, hit_direction: Vector3, strength: float) -> bool:
	if strength < destruction_threshold or not is_finite(strength) or not hit_position.is_finite() or not hit_direction.is_finite():
		return false
	activate()
	return sections[section_index_at(hit_position)].break_segment(hit_position, hit_direction, strength)

func restore() -> void:
	if is_instance_valid(detailed):
		for section in sections:
			section.collision_layer = 0
			section.collision_mask = 0
			section.remove_from_group("destructible")
		remove_child(detailed)
		detailed.queue_free()
	detailed = null
	sections.clear()
	add_to_group("destructible")
	super.restore()

func sweep_hit(a: Vector3, b: Vector3, c: Vector3, d: Vector3, radius: float) -> Variant:
	var inverse := global_transform.affine_inverse()
	var la := inverse*a
	var lb := inverse*b
	var lc := inverse*c
	var ld := inverse*d
	for box in section_bounds:
		if SweepGeometry.swept_line_box(la,lb,lc,ld,box,radius):
			# Hit the band traversed by the rope, not the center of the entire tower.
			for step in 5:
				var t := float(step)/4.0
				var start := la.lerp(lc,t)
				var end := lb.lerp(ld,t)
				var point: Variant = box.grow(radius).intersects_segment(start,end)
				if point != null:
					return global_transform * (point as Vector3)
			return global_transform * Geometry3D.get_closest_point_to_segment(box.get_center(),lc,ld)
	return null
