class_name GrappleTargeting
extends RefCounted

var reason: String = "NO SURFACE / OUT OF REACH"
var ray_count: int = 0
var rejected: Dictionary = {}

func select(hook) -> Dictionary:
	ray_count = 0
	rejected.clear()
	reason = "NO SURFACE / OUT OF REACH"
	var camera:Camera3D = hook.camera
	var center := camera.get_viewport().get_visible_rect().size*0.5
	var forward := -camera.global_basis.z
	var direct := probe(hook,forward)
	if not direct.is_empty():
		direct["method"] = "CENTER"
		direct["score"] = 0.0
		direct["assist_offset"] = 0.0
		reason = "CENTER / VISIBLE"
		return direct
	if hook.profile.targeting_model==0:
		return {}
	var panic:bool = hook.player.fall_grace or (hook.player.velocity.y < -30 and hook.player.global_position.y < 0)
	var angle := deg_to_rad(hook.profile.emergency_angle if panic else hook.profile.assist_angle)
	var best: Dictionary = {}
	var best_score := INF
	var samples := 12 if hook.profile.targeting_model==2 else 8
	for ring in 2:
		for i in samples:
			var phase := TAU*float(i)/samples + float(ring)*PI/samples
			var fraction := 0.5 if ring==0 else 1.0
			var offset := Vector2(cos(phase),sin(phase))*fraction
			var direction: Vector3
			if hook.profile.targeting_model==1:
				var pixels:float = center.y*2.0*hook.profile.screen_assist_fraction*(1.6 if panic else 1.0)
				direction = camera.project_ray_normal(center+offset*pixels)
			else:
				direction = (forward+(camera.global_basis.x*offset.x+camera.global_basis.y*offset.y)*tan(angle)).normalized()
			var hit := probe(hook,direction)
			if hit.is_empty():
				continue
			var distance: float = hook.player.global_position.distance_to(hit.position)
			var travel:Vector3 = hook.player.velocity.normalized()
			var surface_penalty: float = 1.0-absf(hit.normal.dot(direction))
			var score: float = fraction*0.72+distance/hook.profile.maximum_rope_length*0.18+(1.0-travel.dot(direction))*0.03+surface_penalty*0.04
			if score < best_score:
				best_score = score
				best = hit
				best["score"] = score
				best["assist_offset"] = rad_to_deg(forward.angle_to(direction))
	if not best.is_empty():
		best["method"] = ("PANIC " if panic else "")+("CONE" if hook.profile.targeting_model==2 else "SCREEN")
		reason = str(best.method)+" / VISIBLE"
	return best

func reject(why: String) -> Dictionary:
	rejected[why] = int(rejected.get(why,0))+1
	reason = why
	return {}

func probe(hook, direction: Vector3) -> Dictionary:
	ray_count += 1
	var start:Vector3 = hook.camera.global_position
	# Camera setback must not reduce the player's usable grapple range.
	var reach:float = hook.profile.maximum_rope_length+start.distance_to(hook.player.global_position)
	var query := PhysicsRayQueryParameters3D.create(start,start+direction*reach,3,[hook.player.get_rid()])
	var space:PhysicsDirectSpaceState3D = hook.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty() or not hit.collider is StaticBody3D:
		return {}
	var offset: Vector3 = hit.position-hook.player.global_position
	if offset.length() < 2.0:
		return reject("TOO CLOSE")
	if offset.length() > hook.profile.maximum_rope_length:
		return reject("OUT OF REACH")
	if offset.dot(-hook.camera.global_basis.z) < 0.5:
		return reject("BEHIND YOU")
	var sight := PhysicsRayQueryParameters3D.create(hook.player.global_position,hit.position-hit.normal*0.04,3,[hook.player.get_rid()])
	var obstruction := space.intersect_ray(sight)
	if not obstruction.is_empty() and (obstruction.collider!=hit.collider or obstruction.position.distance_to(hit.position)>0.35):
		return reject("HAND BLOCKED")
	return hit
