extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ", description)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var world = load("res://scenes/maps/graybox.tscn").instantiate()
	root.add_child(world)
	await frames(3)
	var player: RavagePlayer = world.get_node("Player")
	player.global_position = Vector3(0, 65, 0)
	player.velocity = Vector3.ZERO
	await frames(120)
	check(player.global_position.y < 60 and player.velocity.y < -20, "gravity / stable freefall")
	player.global_position = Vector3(15, 20, -18)
	player.velocity = Vector3(65, 0, 0)
	await frames(30)
	check(player.global_position.x < 21.5 and absf(player.velocity.x) < 1, "wall blocks high speed CharacterBody")
	player.global_position = Vector3(0, 200, 0)
	player.velocity = Vector3(1000, 1000, 1000)
	await frames(3)
	check(player.velocity.length() <= player.profile.max_speed + 0.01, "maximum speed bound")
	player.global_position = Vector3(0, -200, 0)
	await frames(3)
	check(player.global_position.distance_to(player.spawn_position) < 1, "void resets safely")
	check(player is CharacterBody3D, "player uses fake physics")
	print("MOVEMENT RESULT failures=", failures)
	quit(failures)
