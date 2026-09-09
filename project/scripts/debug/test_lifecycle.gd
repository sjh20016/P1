extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed = load("res://scenes/maps/main.tscn")
	for i in 3:
		var scene = packed.instantiate()
		root.add_child(scene)
		scene.begin()
		await physics_frame
		scene.sweep_practice()
		for frame in 40:
			await physics_frame
		scene.queue_free()
		await process_frame
		await process_frame
	print("LIFECYCLE RESULT three load/free cycles completed")
	quit()
