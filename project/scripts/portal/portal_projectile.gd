extends RigidBody3D

var portals: PortalManager
var age: float = 0

func _ready() -> void:
	continuous_cd = true; collision_layer = 8; collision_mask = 3 | 16
	linear_damp = 0; angular_damp = 0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	gravity_scale = 25.0 / 9.8; mass = 3.0
	add_to_group("portal_projectile")

func _physics_process(delta: float) -> void:
	age += delta
	if age > 90 or global_position.y < -100: queue_free()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_instance_valid(portals): portals.integrate_body(self, state)
