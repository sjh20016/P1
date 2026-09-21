extends SceneTree

var game: Node3D
var failures: Array[String] = []
var checks := 0
var rendered := false
const OUT := "res://../docs/portal-fracture/"
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	# Exclude synchronous PNG encoding from the gameplay frame-time sample.
	game.last_frame_us = 0

func run() -> void:
	rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(120); game.impact_vfx.stop_enabled = false
	var tower: PortalAssetStructure = game.canyon.get_node("Tower_00_STRAIGHT_SHAFT")
	check(tower != null,"authored tall tower selected")
	if tower == null: quit(1); return
	print("TOWER ",tower.name," bounds ",tower.local_bounds)
	tower.set_near(true); tower.decode_cells()
	check(tower.grounded.count(1) > 0,"authored tower has base-connected support cells")
	var center := tower.to_global(tower.local_bounds.get_center()); center.y = tower.to_global(tower.local_bounds.end).y-80
	game.player.set_physics_process(false); game.player.global_position = center+Vector3(30,10,45)
	game.canyon.refresh_interest(game.player.global_position)
	var camera := Camera3D.new(); game.add_child(camera)
	var look := center+Vector3.UP*22
	for angle in 24:
		var offset := Vector3(cos(angle*TAU/24)*32,10,sin(angle*TAU/24)*32)
		camera.global_position = look+offset
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position,look,3)
		var seen := game.get_world_3d().direct_space_state.intersect_ray(ray)
		if seen.is_empty() or seen.collider == tower: break
	camera.look_at(look); camera.current = true
	await frames(20); await capture("01-intact")
	game.frame_ms.clear()
	var event := RavageDamageEvent.new(); event.type = RavageDamageEvent.Type.SLASH
	event.position = center; event.normal = Vector3.UP; event.direction = Vector3.RIGHT
	event.energy = 80; event.radius = .4
	event.context = {"asset_disk":true,"asset_center":center,"asset_radius":maxf(tower.local_bounds.size.x,tower.local_bounds.size.z)+2}
	var result: Dictionary = game.manager.apply_damage(tower,event)
	print("DAMAGE ",result)
	check(result.get("changed",false),"cut removes actual authored cells")
	check(result.get("severed",0) > 0,"unsupported upper structure detaches beyond cut slab")
	check(game.fracture_field.pending.size() > 0,"source fragments queue for bounded physics conversion")
	await frames(35)
	check(game.fracture_field.pieces.size() > 0,"authored geometry becomes real rigid bodies")
	if game.fracture_field.pieces.is_empty(): quit(1); return
	var piece: PortalFracturePiece = game.fracture_field.pieces[mini(10,game.fracture_field.pieces.size()-1)]
	check(piece.get_child(0).mesh.get_surface_count() == 2,"fragment contains original outer face and solid dark interior")
	var first := piece.global_transform
	await frames(80)
	check(piece.global_position.distance_to(first.origin)>1,"fragment moves under gravity and impulse")
	check(not piece.global_basis.is_equal_approx(first.basis),"fragment rotates rather than only translating")
	await capture("02-physical-collapse")
	await frames(470)
	for tick in 1200:
		if game.fracture_field.pending.is_empty() and game.fracture_field.active_count()==0: break
		await physics_frame
	check(game.fracture_field.pending.is_empty() and game.fracture_field.active_count()==0,"bodies damp and freeze after a few seconds")
	check(piece.freeze and piece.settled and piece.linear_velocity.is_zero_approx(),"stasis uses a frozen physical body")
	var pose := piece.global_transform; await frames(240)
	check(piece.global_transform.is_equal_approx(pose),"floating ruin remains fixed instead of expiring")
	check(game.fracture_field.pieces.any(func(p): return p.global_position.y>5),"collapse leaves elevated floating wreckage")
	await capture("03-suspended-ruin")
	var frame_times: Array = game.frame_ms.duplicate(); frame_times.sort()
	print("SUPPORT ",tower.grounded.count(1),"/",tower.cells.size()," target ",center," chunks ",game.fracture_field.pieces.map(func(p): return p.global_position))
	if rendered:
		for structure in game.canyon.structures: structure.visible = structure == tower
		camera.global_position = center+Vector3(65,45,80); camera.look_at(center+Vector3.UP*30)
		await frames(5); await capture("04-isolated-geometry-inspection")
		for structure in game.canyon.structures: structure.visible = true
	var shape_query := PhysicsShapeQueryParameters3D.new(); var sphere := SphereShape3D.new(); sphere.radius = .25
	game.player.global_position = piece.global_position+Vector3(0,4,8); await frames(20)
	shape_query.shape = sphere; shape_query.collision_mask = 16
	var faces: PackedVector3Array = piece.precise_collision.shape.get_faces()
	shape_query.transform.origin = piece.precise_collision.to_global((faces[0]+faces[1]+faces[2])/3)
	check(not game.get_world_3d().direct_space_state.intersect_shape(shape_query).is_empty(),"frozen wreckage retains usable collision")
	var hit := RavageDamageEvent.new(); hit.type = RavageDamageEvent.Type.RAM; hit.energy = 65
	hit.position = piece.global_position; hit.direction = Vector3.UP; hit.radius = 2
	check(game.manager.apply_damage(piece,hit).get("reactivated",false),"hitting a suspended piece resumes its physics")
	await frames(30); check(not piece.settled and not piece.freeze,"reactivated piece participates in physics again")
	await frames(550); check(piece.settled,"reactivated debris freezes again")
	var mask := tower.removed.duplicate(); tower.set_near(false); tower.set_near(true)
	check(tower.removed == mask,"interest sleep preserves missing structural cells")
	check(game.fracture_field.peak_active<=PortalFractureField.ACTIVE_LIMIT and game.fracture_field.pending.size()<=PortalFractureField.QUEUE_LIMIT,"physics and conversion budgets are bounded")
	check(Engine.time_scale == 1,"building stasis never freezes player or world time")
	# A real moving collision must cause secondary damage; invoking the queue alone
	# would miss solver/contact reporting regressions.
	var chosen := 0; var nearest := INF
	for i in tower.cells.size():
		if tower.removed[i] != 0: continue
		var distance: float = absf(tower.to_global(tower.cells[i].bounds.get_center()).y-(center.y-30))
		if distance < nearest: nearest = distance; chosen = i
	var start: int = tower.cells[chosen].start
	var vertices: PackedVector3Array = tower.arrays[Mesh.ARRAY_VERTEX]
	var wall := tower.to_global((vertices[start]+vertices[start+1]+vertices[start+2])/3)
	var normal: Vector3 = tower.arrays[Mesh.ARRAY_NORMAL][start]
	var projectile := PortalFracturePiece.new(); projectile.field = game.fracture_field
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3.ONE
	shape.shape = box; projectile.add_child(shape)
	game.fracture_field.add_child(projectile); game.fracture_field.pieces.append(projectile)
	projectile.global_position = wall+normal*10; projectile.linear_velocity = -normal*35
	projectile.gravity_scale = 0; projectile.linear_damp = 0; projectile.contact_delay = 0
	game.player.global_position = wall+normal*20; game.canyon.refresh_interest(game.player.global_position)
	var impacts: int = game.fracture_field.impact_total
	await frames(90)
	check(game.fracture_field.impact_total>impacts,"a real moving chunk collision damages authored walls")
	check(game.manager.deepest_chain<=2,"secondary structural damage respects chain-depth limit")
	var report := {"checks":checks,"failures":failures,"rendered":rendered,"detached":result.get("severed",0),"fragments":game.fracture_field.emitted,"peak_active":game.fracture_field.peak_active,"peak_build_ms":game.fracture_field.build_peak_us/1000.0,"frozen":game.fracture_field.frozen_total,"chain_hits":game.fracture_field.impact_total}
	if rendered:
		report["collapse_p95_ms"] = frame_times[int(frame_times.size()*.95)]; report["collapse_max_ms"] = frame_times.back()
	var file := FileAccess.open(OUT+("rendered-results.json" if rendered else "test-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RESULT portal_fracture ",JSON.stringify(report)); game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
