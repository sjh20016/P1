class_name PortalFracturePiece
extends RigidBody3D

var field: PortalFractureField
var age := 0.0
var settled := false
var life := 3.0
var depth := 0
var contact_delay := .35
var last_speed := 0.0
var reactivations := 0
var local_bounds: AABB
var precise_collision: CollisionShape3D
var moving_collisions: Array[CollisionShape3D] = []
var maximum_speed := 42.0

func prepare_collision(mesh: ArrayMesh, offset: Vector3, patches: Array) -> void:
	for points: PackedVector3Array in patches:
		var centered := PackedVector3Array()
		for point in points: centered.append(point+offset)
		var shape := ConvexPolygonShape3D.new(); shape.points = centered; shape.margin = .008
		var collider := CollisionShape3D.new(); collider.shape = shape
		add_child(collider); moving_collisions.append(collider)
	var faces := mesh.get_faces()
	var surface := ConcavePolygonShape3D.new(); surface.backface_collision = true; surface.set_faces(faces)
	precise_collision = CollisionShape3D.new(); precise_collision.shape = surface
	precise_collision.position = offset; precise_collision.disabled = true; add_child(precise_collision)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Thin adjacent shells can briefly overlap at separation. Bound solver energy
	# so a contact correction cannot fling an entire wall hundreds of metres.
	state.linear_velocity = state.linear_velocity.limit_length(maximum_speed)
	state.angular_velocity = state.angular_velocity.limit_length(2.4)

func _ready() -> void:
	add_to_group("destructible")
	continuous_cd = true; can_sleep = false
	collision_layer = 16; collision_mask = 3 | 16
	contact_monitor = true; max_contacts_reported = 4
	var physics := PhysicsMaterial.new(); physics.friction = .85; physics.bounce = .07
	physics_material_override = physics
	linear_damp = .18; angular_damp = .7

func _physics_process(delta: float) -> void:
	if settled: return
	age += delta; contact_delay -= delta
	last_speed = linear_velocity.length()
	if age > life:
		var t := clampf((age-life)/.8,0,1)
		gravity_scale = 1-t
		linear_damp = lerpf(.18,18,t); angular_damp = lerpf(.7,20,t)
	if age >= life+.8 or global_position.y < -120: lock_in_space()
	if contact_delay <= 0 and last_speed > 8:
		for body in get_colliding_bodies():
			if body is PortalAssetStructure and depth < 2:
				field.queue_contact(self,body); contact_delay = .45; break

func lock_in_space() -> void:
	if settled: return
	settled = true; freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	linear_velocity = Vector3.ZERO; angular_velocity = Vector3.ZERO; freeze = true
	if is_instance_valid(precise_collision):
		for collider in moving_collisions: collider.disabled = true
		precise_collision.disabled = false
	contact_monitor = false; max_contacts_reported = 0
	field.on_lock(self)
	set_physics_process(false)

func receive_damage(event) -> Dictionary:
	if event.energy < 26 or not settled or not field.can_wake(): return {"changed":false}
	if is_instance_valid(precise_collision):
		precise_collision.disabled = true
		for collider in moving_collisions: collider.disabled = false
	age = 0; settled = false; freeze = false; gravity_scale = 1
	collision_layer = 16
	linear_damp = .18; angular_damp = .7; reactivations += 1
	contact_monitor = true; max_contacts_reported = 4; contact_delay = .4
	linear_velocity = event.direction.normalized()*clampf(event.energy*.12,3,12)+Vector3.UP*1.5
	angular_velocity = Vector3(.25,.35,-.2); set_physics_process(true)
	return {"changed":true,"reactivated":true,"removed":0,"bond_broken":false}
