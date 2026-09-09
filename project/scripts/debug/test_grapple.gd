extends SceneTree

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func run() -> void:
	var world = load("res://scenes/maps/graybox.tscn").instantiate()
	root.add_child(world)
	await frames(3)
	var p: RavagePlayer = world.get_node("Player")
	var h: GrappleController = p.get_node("LeftHook")
	p.global_position = Vector3(0, 25, -18)
	p.velocity = Vector3(0, -15, -20)
	check(h.attach_to(Vector3(-22, 48, -18), world.get_node("Tower0")), "single hook attaches to StaticBody")
	await frames(100)
	check(p.velocity.is_finite() and p.velocity.x < -3, "spring redirects falling player toward anchor")
	check(h.tension <= h.profile.maximum_hook_force, "spring force stays bounded")
	var before := p.velocity
	h.release()
	await frames(2)
	check(p.velocity.distance_to(before) < 2, "release retains flight momentum")
	p.global_position = Vector3(0, 30, 0)
	check(not h.attach_to(p.global_position, world.get_node("Tower0")), "zero length rejected")
	check(not h.attach_to(Vector3(1000,0,0), world.get_node("Tower0")), "out of range rejected")
	if p.has_node("RightHook"):
		var right: GrappleController = p.get_node("RightHook")
		p.global_position = Vector3(0, 20, -18)
		p.velocity = Vector3(0, -65, 0)
		h.attach_to(Vector3(-22, 48, -18), world.get_node("Tower0"))
		right.attach_to(Vector3(22, 48, -18), world.get_node("Tower1"))
		await frames(600)
		check(p.velocity.is_finite() and p.velocity.length() <= p.profile.max_speed + 0.01, "dual hooks stable for five seconds")
		check(h.active and right.active, "independent anchors remain attached")
		for i in 60:
			h.release()
			h.attach_to(p.global_position + Vector3(0, 5, 0), world.get_node("Tower0"))
			await frames(1)
		check(p.velocity.is_finite(), "rapid reattachment stays finite")
	print("GRAPPLE RESULT failures=", failures)
	quit(failures)
