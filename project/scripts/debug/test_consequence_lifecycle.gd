extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/maps/main.tscn").instantiate();root.add_child(game)
	for cycle in 3:
		game.start_consequence(2)
		game.player.controls_enabled=false
		for i in 4: await physics_frame
		if not OS.get_cmdline_user_args().has("--intact-only"):
			var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.SLASH;event.energy=55;event.direction=Vector3.RIGHT
			var tower=game.consequence.towers[1];event.position=tower.to_global(Vector3(0,0,8.4))
			if OS.get_cmdline_user_args().has("--ram"): event.type=RavageDamageEvent.Type.RAM
			if OS.get_cmdline_user_args().has("--local-slash"): tower.structural=false
			if OS.get_cmdline_user_args().has("--no-scars"): game.consequence.scars.remove_from_group("damage_scars")
			game.manager.apply_damage(tower,event)
			if OS.get_cmdline_user_args().has("--remove-exceptions"):
				for macro in game.consequence.macros.active:
					for body in macro.get_collision_exceptions(): macro.remove_collision_exception_with(body)
			while game.consequence.elapsed<1.5: await physics_frame
		game.restart_run()
		for i in 10: await physics_frame
		print("CONSEQUENCE LIFECYCLE cycle=",cycle)
	game.queue_free()
	for i in 12: await physics_frame
	print("CONSEQUENCE LIFECYCLE RESULT PASS");quit()
