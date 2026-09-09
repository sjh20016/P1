extends Node

@onready var player: RavagePlayer = get_parent()
var last_impact_speed: float = 0.0

func _ready() -> void:
	player.motion_requested.connect(check_motion)

func check_motion(motion: Vector3, incoming_velocity: Vector3) -> void:
	if motion.length_squared() < 0.000001:
		return
	var collision := KinematicCollision3D.new()
	if not player.test_move(player.global_transform, motion, collision):
		return
	var target := collision.get_collider()
	if target is DestructibleSegment:
		# Static target: relative impact is the incident normal component.
		last_impact_speed = maxf(0.0, -incoming_velocity.dot(collision.get_normal()))
		target.break_segment(collision.get_position(), incoming_velocity.normalized(), last_impact_speed)
