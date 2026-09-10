extends SceneTree

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:
		failures += 1
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func run() -> void:
	var game = load("res://scenes/maps/main.tscn").instantiate()
	root.add_child(game)
	game.begin()
	var p: RavagePlayer = game.player
	p.controls_enabled = false
	p.global_position = Vector3(0,50,90)
	var ink: InkMarks = game.get_node("InkMarks")
	var wall := StaticBody3D.new()
	wall.position = Vector3(0,50,80)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,24,2)
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	await frames(3)
	var hook: GrappleController = p.hooks[0]
	check(hook.attach_to(Vector3(0,50,81),wall),"grapple attaches to real collision surface")
	check(ink.marks.size()==1,"grapple contact deposits projected ink")
	ink.clock += 0.5
	hook.release()
	check(ink.marks.size()==2,"grapple release leaves a second dab")
	var vertices: PackedVector3Array = ink.marks[0].vertices
	var attached := true
	for v in vertices:
		attached = attached and absf(v.z-81.025)<0.005
	check(attached,"all stamp vertices lie on surface, with small depth offset")
	ink._process(9.0)
	check(ink.marks.size()==2 and ink.clock-ink.marks[0].birth>ink.dry_seconds,"old ink dries without disappearing")
	p.reset_player()
	check(ink.marks.size()==2,"respawn retains existing ink")
	ink.mark_budget=32
	for i in 64:
		ink.clock += 0.3
		ink.deposit(Vector3(-12+(i%12)*2,40+(i/12 as int)*2,81),Vector3.BACK,wall,0.4)
	ink.rebuild()
	check(ink.marks.size()==32 and ink.geometry.get_surface_count()==1,"stamp budget enforced in a single mesh surface")
	check(game.manager.active_debris.is_empty(),"ink adds no rigid bodies")
	ink.clear_marks()
	ink.mark_budget=64
	for i in 80:
		ink.clock += 0.3
		ink.deposit(Vector3(-12+(i%12)*2,40+(i/12 as int)*2,81),Vector3.BACK,wall,0.4)
	ink.rebuild()
	check(ink.marks.size()==64 and ink.render_batch_count()==2,"ring-buffer overwrites retain exactly two 32-stamp render batches")
	wall.collision_layer=0
	ink.prune()
	ink.rebuild()
	check(ink.marks.is_empty() and ink.render_batch_count()==0,"all render batches clear when their collision owner is removed")
	wall.collision_layer=1
	await frames(2)
	ink.deposit(Vector3(0,50,81),Vector3.BACK,wall,0.8)
	p.global_position = Vector3(0,50,90)
	hook.attach_to(Vector3(2,50,81),wall)
	game.restart_run()
	check(ink.marks.is_empty() and ink.pending_impacts.is_empty(),"new run clears ink even when resetting with an active hook")
	print("INK MARKS RESULT failures=",failures)
	game.queue_free()
	await process_frame
	quit(failures)
