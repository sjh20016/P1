extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(ProjectSettings.globalize_path("res://../build/" + filename + ".png"))
	print("CAPTURE ",filename)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func run() -> void:
	var game = load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	await frames(40)
	await capture("01-menu")
	game.begin()
	await frames(120)
	await capture("02-launch")
	game.sweep_practice()
	await frames(8)
	await capture("03-sweep")
	await frames(50)
	game.get_node("UI/HUD").debug_enabled = true
	await capture("04-debug")
	print("RENDER CHECK events=",game.manager.event_count," sweeps=",game.player.get_node("TentacleSweep").sweep_event_count," fps=",Engine.get_frames_per_second())
	game.player.controls_enabled = false
	for hook in game.player.hooks:
		hook.release()
	await create_timer(6.0).timeout
	print("SETTLED FPS=", Engine.get_frames_per_second(), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.queue_free()
	await frames(10)
	quit()
