extends SceneTree

var game: Node3D
var checks := 0
var failures: Array[String] = []
const OUT := "res://../docs/portal-fracture/"
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func check(ok: bool, message: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func ray(a: Vector3, b: Vector3) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,16))
func capture(name: String, point: Vector3, offset: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	var camera := Camera3D.new(); game.add_child(camera); camera.global_position = point+offset; camera.look_at(point); camera.current = true
	await frames(5); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	camera.queue_free(); game.player.camera_rig.camera.make_current(); await frames(2)

func run() -> void:
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); root.add_child(game); current_scene = game
	await frames(120); game.impact_vfx.stop_enabled = false
	var field: PortalFractureField = game.fracture_field
	# An L shaped mesh intentionally has a large empty quadrant inside its AABB.
	# Build it through the production fracture path, not a special test collider.
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var colors := PackedColorArray()
	for data in [[Vector3(1,4,1),Vector3(-2,0,0)],[Vector3(4,1,1),Vector3(-.5,-1.5,0)]]:
		var box := BoxMesh.new(); box.size = data[0]; var arrays := box.get_mesh_arrays()
		for index in arrays[Mesh.ARRAY_INDEX]:
			vertices.append(arrays[Mesh.ARRAY_VERTEX][index]+data[1]); normals.append(arrays[Mesh.ARRAY_NORMAL][index]); colors.append(Color.WHITE)
	var source := PortalAssetStructure.new(); source.original_arrays.resize(Mesh.ARRAY_MAX)
	source.original_arrays[Mesh.ARRAY_VERTEX] = vertices; source.original_arrays[Mesh.ARRAY_NORMAL] = normals; source.original_arrays[Mesh.ARRAY_COLOR] = colors
	source.material = game.canyon.towers[0].material; game.add_child(source)
	source.position = Vector3(700,100,700); source.visual.hide(); source.collision_layer = 0
	source.arrays = source.original_arrays
	source.cells.append({"bounds":source.local_bounds,"start":0,"count":vertices.size()})
	var event := RavageDamageEvent.new(); event.energy = 80; event.position = source.position; event.direction = Vector3.RIGHT
	field.enqueue(source,[0],event,false)
	game.player.set_physics_process(false); game.player.global_position = source.position+Vector3(0,3,12)
	await frames(1)
	var piece: PortalFracturePiece = field.pieces.back()
	piece.gravity_scale = 0; piece.linear_velocity = Vector3.ZERO; piece.angular_velocity = Vector3.ZERO
	await frames(3)
	var a := piece.global_transform*(Vector3(1,1,3)-source.local_bounds.get_center())
	var b := piece.global_transform*(Vector3(1,1,-3)-source.local_bounds.get_center())
	check(ray(a,b).is_empty(),"moving chunk leaves empty AABB quadrant collision-free")
	check(piece.moving_collisions.all(func(c): return c.shape is ConvexPolygonShape3D),"moving collision uses wall prisms instead of cell boxes")
	piece.lock_in_space(); await frames(3)
	check(ray(a,b).is_empty(),"frozen exact mesh preserves the empty quadrant")
	check(piece.precise_collision.shape is ConcavePolygonShape3D and not piece.precise_collision.disabled,"stasis enables exact visible mesh collision")
	var visible_a := piece.global_transform*(Vector3(-2,1,3)-source.local_bounds.get_center())
	var visible_b := piece.global_transform*(Vector3(-2,1,-3)-source.local_bounds.get_center())
	check(not ray(visible_a,visible_b).is_empty(),"visible frozen wall still collides")
	var old_a := visible_a; var old_b := visible_b; piece.global_position += Vector3.RIGHT*12; await frames(3)
	check(ray(old_a,old_b).is_empty(),"moving a ruin leaves no collision at its old position")
	check(piece.receive_damage(event).get("reactivated",false),"exact frozen collider can wake")
	check(piece.precise_collision.disabled and piece.moving_collisions.all(func(c): return not c.disabled),"wake restores dynamic prisms without an active concave shape")
	piece.lock_in_space()
	field.spawn_landings({"point":Vector3(700,100,725),"normal":Vector3.BACK,"seed":3})
	await frames(3)
	check(field.landings.size()==3,"free space receives three varied standing islands")
	var shapes: Array = field.landings.map(func(p): return p.get_child(1).shape.points.size())
	check(shapes[0]!=shapes[1] and shapes[1]!=shapes[2],"landing islands have different polygon counts")
	var landing: StaticBody3D = field.landings[0]
	var top := ray(landing.global_position+Vector3.UP*4,landing.global_position+Vector3.DOWN*2)
	check(not top.is_empty() and top.normal.y>.95 and absf(top.position.y-landing.global_position.y)<.04,"standing collision matches the visible flat top")
	check(landing.get_child(0).mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_TRIANGLES,"pseudo debris has filled visible geometry, not a debug wireframe")
	# Actual CharacterBody grounding proves the islands are usable standing points.
	game.player.global_position = landing.global_position+Vector3.UP*2; game.player.velocity = Vector3.ZERO; game.player.set_physics_process(true)
	await frames(60); check(game.player.is_on_floor(),"player can land and stand on an island")
	await capture("05-standing-islands",landing.global_position+Vector3(0,0,3),Vector3(12,10,14))
	game.player.set_physics_process(false)
	# Aim a real charged Shift cast at a surviving authored facade. The player's
	# own movement loop stays enabled throughout formation, exit and wall impact.
	var tower: PortalAssetStructure = game.canyon.get_node("Tower_00_STRAIGHT_SHAFT")
	tower.set_near(true); tower.decode_cells()
	var nearest := INF; var chosen := 0
	for i in tower.cells.size():
		var d: float = absf(tower.to_global(tower.cells[i].bounds.get_center()).y-120)
		if d<nearest: chosen = i; nearest = d
	var start: int = tower.cells[chosen].start; var v: PackedVector3Array = tower.arrays[Mesh.ARRAY_VERTEX]
	var wall := tower.to_global((v[start]+v[start+1]+v[start+2])/3)
	var normal: Vector3 = tower.arrays[Mesh.ARRAY_NORMAL][start]
	game.player.global_position = wall+normal*18; game.player.velocity = Vector3.ZERO
	game.player.camera_rig.rotation = Vector3(asin(-normal.y),atan2(normal.x,normal.z),0)
	game.canyon.refresh_interest(game.player.global_position); game.player.set_physics_process(true)
	await frames(2); game.magic.queue_command("boost"); await frames(200)
	check(game.magic.boost_speed>70,"real Shift loop stores high launch speed")
	game.magic.queue_command("boost")
	var peak := 0.0
	for i in 160:
		await physics_frame; peak = maxf(peak,game.player.velocity.length())
	check(peak>60,"charged transit releases velocity through the live player motion filter")
	check(tower.damage_revision>0,"charged ram breaks the aimed authored tower")
	check(game.manager.last_context.get("kind","")=="BODY" or game.manager.last_context.get("kind","")=="COLLAPSE","ram produces impact damage rather than slash damage")
	check(field.fracture_audio.voices.size()==8 and field.fracture_audio.played>0,"spatial destruction sound uses the bounded eight-voice pool")
	check(field.peak_active<=48 and field.landings.size()<=48,"larger physics and landing budgets remain bounded")
	game.player.set_physics_process(false)
	await capture("06-charged-ram-break",wall,normal*26+Vector3.UP*12)
	var report := {"checks":checks,"failures":failures,"launch_peak":peak,"ram_revision":tower.damage_revision,"landings":field.landings.size(),"rendered":DisplayServer.get_name()!="headless"}
	var file := FileAccess.open(OUT+("integrity-rendered.json" if report.rendered else "integrity-results.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RESULT portal_fracture_integrity ",JSON.stringify(report)); game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
