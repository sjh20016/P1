extends Node

@onready var player: RavagePlayer = get_parent()
var last_impact_speed: float = 0.0
@export var momentum_response: bool = false
@export var body_threshold: float = 26.0

func _ready() -> void:
	player.motion_requested.connect(check_motion)

func check_motion(motion: Vector3, incoming_velocity: Vector3) -> void:
	if motion.length_squared() < 0.000001:
		return
	var manager: DestructionManager = get_tree().get_first_node_in_group("destruction_manager")
	var delta:=motion.length()/maxf(incoming_velocity.length(),0.01)
	var velocity:=incoming_velocity
	# Bounded multi-contact test also catches close successive thin walls at 60 Hz.
	for attempt in 4:
		var collision:=KinematicCollision3D.new()
		if not player.test_move(player.global_transform,velocity*delta,collision): return
		var target:=collision.get_collider()
		if not target is DestructibleSegment: return
		var normal:=collision.get_normal()
		last_impact_speed=maxf(0.0,-velocity.dot(normal))
		if momentum_response and last_impact_speed<maxf(body_threshold,target.destruction_threshold): return
		var after:=ImpactResponse.penetrate(velocity,normal,target.structure_weight) if momentum_response else velocity
		var context:Dictionary={"kind":"BODY","normal":normal,"before":velocity.length(),"after":after.length(),"normal_speed":last_impact_speed,"structure":target.structure_weight}
		if not manager.break_with_context(target,collision.get_position(),velocity.normalized(),last_impact_speed,context): return
		if manager.last_context.get("boost",false):
			after=(after+velocity.normalized()*14+Vector3.UP*5).limit_length(player.profile.max_speed)
		player.velocity=after
		velocity=after
