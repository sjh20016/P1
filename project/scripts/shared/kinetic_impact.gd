class_name KineticImpact
extends Node

signal impact_event(event: Dictionary)
var manager: DestructionManager
var threshold: float = 26.0
var last_energy: float = 0.0

# Existing destruction energy is a gameplay strength (26..120), not joules.
# Retain physical energy in context while adapting the velocity-squared curve.
func apply(target, point: Vector3, normal: Vector3, velocity: Vector3, mass: float, source: Node) -> bool:
	var normal_speed := maxf(0, -velocity.dot(normal))
	if normal_speed < threshold or not is_instance_valid(target): return false
	var joules := 0.5 * mass * normal_speed * normal_speed
	var strength := clampf(joules / 13.0, 0, 100)
	last_energy = joules
	var data := {"position": point, "direction": velocity.normalized(), "velocity": velocity,
		"mass": mass, "energy": joules, "source": source.get_instance_id(), "strength": strength}
	impact_event.emit(data)
	return manager.break_with_context(target, point, velocity.normalized(), strength,
		{"kind": "BODY", "normal": normal, "before": velocity.length(), "physical_energy": joules,
		"source_id": source.get_instance_id(), "radius": 2.6, "portal": true})

func check_player(player: RavagePlayer, delta: float) -> void:
	for attempt in 4:
		var collision := KinematicCollision3D.new()
		if not player.test_move(player.global_transform, player.velocity * delta, collision): return
		if not apply(collision.get_collider(), collision.get_position(), collision.get_normal(), player.velocity, 1.0, player): return
		player.velocity *= 0.88
