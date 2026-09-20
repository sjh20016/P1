extends SceneTree

var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var pictures: Array[String] = []
var metrics: Dictionary = {}
var rendered: bool = false

func _initialize() -> void:
	Input.use_accumulated_input = false
	rendered = DisplayServer.get_name() != "headless"
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	if rendered: Input.parse_input_event(event)
	elif code == KEY_F7 and pressed: game.link_trial()
	elif code == KEY_SHIFT and pressed: game.magic.queue_command("boost")
	elif code == KEY_F and pressed: game.magic.queue_command("dive")
	elif code == KEY_R and pressed: game.player.reset_player("test")
	elif code == KEY_T and pressed: game.spawn_projectile()
	elif code == KEY_L and pressed:
		game.select_station(4); game.spawn_projectile(true)
	else: game.links.handle_input(event)
	await frames(1)

func tap(code: int) -> void:
	await key(code); await key(code,false)

func mouse(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = pressed
	if rendered: Input.parse_input_event(event)
	elif not game.links.handle_input(event) and button == MOUSE_BUTTON_LEFT:
		game.magic.queue_command("aim" if pressed else "fire")
	await frames(1)

func aim(point: Vector3) -> void:
	var direction: Vector3 = (point - game.player.camera_rig.global_position).normalized()
	game.player.camera_rig.rotation = Vector3(asin(direction.y),atan2(-direction.x,-direction.z),0)

func capture(name: String) -> void:
	if not rendered: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../docs/portal-hybrid/" + name + ".png")
	pictures.append(name)

func has_cue(action: String, kind: String = "") -> bool:
	for cue in game.presentation.history:
		if cue.action == action and (kind.is_empty() or cue.data.get("kind","") == kind): return true
	return false

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/portal-hybrid").simplify_path())
	game = load("res://scenes/portal/Portal_Playground.tscn").instantiate(); game.forest_enabled = false; root.add_child(game); current_scene = game
	await frames(150)
	if not rendered: game.impact_vfx.stop_enabled = false
	await tap(KEY_F7); await frames(3)
	check(game.profile.magic_enabled and game.portals.gates[0] != null and game.portals.gates[1] != null,"F7 supplies physical A/B without leaving action controls")
	check(not game.portals.gates[0].temporary and not game.portals.gates[1].temporary,"physical links persist on static surfaces")
	# Stabilize the observer while checking camera geometry and live world content.
	game.player.controls_enabled = false
	game.player.global_position = Vector3(65,5,-4); aim(game.portals.gates[0].global_position)
	await frames(25)
	var entry: Transform3D = game.portals.gates[0].global_transform
	var exit: Transform3D = game.portals.gates[1].global_transform
	var eye: Vector3 = game.player.camera_rig.camera.global_position
	var view := PortalWindowRenderer.projection(entry,exit,eye,3.2)
	check(not view.is_empty(),"front side provides off-axis window projection")
	check(view.pose.origin.is_finite(),"projection returns a finite mapped eye")
	var expected: Vector3 = exit.origin + PortalPhysics.rotation_between(entry.basis,exit.basis) * (eye-entry.origin)
	check(view.pose.origin.is_equal_approx(expected),"render eye uses exactly the traveller frame transform")
	check(view.near > (entry.affine_inverse()*eye).z,"window near plane is just beyond the exit surface")
	check(PortalWindowRenderer.projection(entry,exit,entry.origin-entry.basis.z,3.2).is_empty(),"back face does not expose the destination scene")
	if rendered:
		check(game.windows.views.size() == 2 and game.windows.active_views >= 1,"only two pooled live views serve the physical pair")
		var camera: Camera3D = game.windows.cameras[0]
		var r: float = game.portals.gates[0].radius
		var top_right: Vector2 = camera.unproject_position(exit * Vector3(-r,r,0))
		var bottom_left: Vector2 = camera.unproject_position(exit * Vector3(r,-r,0))
		var size: float = game.profile.portal_view_resolution
		check(top_right.distance_to(Vector2(size,0)) < 2 and bottom_left.distance_to(Vector2(0,size)) < 2,"mapped aperture corners match texture corners without camera-feed stretching")
		check(camera.is_position_in_frustum(exit.origin + exit.basis.z * 0.2) and not camera.is_position_in_frustum(exit.origin-exit.basis.z*0.2),"exit wall is clipped while destination geometry remains visible")
		check(camera.cull_mask & PortalComponent.VIEW_LAYER == 0,"remote views exclude portal surfaces to prevent recursion")
		await capture("01-live-window")
		var marker := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = Vector3(2,4,2)
		var material := StandardMaterial3D.new(); material.albedo_color = Color(0.02,0.02,0.02); cube.material = material
		marker.mesh = cube; game.add_child(marker); marker.global_position = exit.origin + exit.basis.z * 8
		await frames(20); await RenderingServer.frame_post_draw
		var first_hash: int = hash(game.windows.views[0].get_texture().get_image().get_data())
		marker.position.x += 3; await frames(20); await RenderingServer.frame_post_draw
		check(first_hash != hash(game.windows.views[0].get_texture().get_image().get_data()),"moving destination object changes the live portal image")
		marker.queue_free()
		game.player.position.x += 2; aim(entry.origin); await frames(20)
		check(absf(game.windows.cameras[0].frustum_offset.x) > 1,"observer lateral motion produces parallax")
		await capture("02-parallax")
		game.profile.portal_view_enabled = false; await frames(20)
		var updates: int = game.windows.rendered_updates; await frames(20)
		check(game.windows.active_views == 0 and game.windows.rendered_updates == updates,"view switch stops render updates without closing portals")
		game.profile.portal_view_enabled = true
	else:
		check(game.windows.views.is_empty(),"headless tests allocate no render targets")
	game.player.controls_enabled = true
	await tap(KEY_F7); aim(game.portals.gates[0].global_position); await frames(3)
	var a_id: int = game.portals.gates[0].get_instance_id()
	var b_id: int = game.portals.gates[1].get_instance_id()
	var magic_count: int = game.portals.magic_casts
	await key(KEY_Q); await mouse(MOUSE_BUTTON_LEFT,true)
	await key(KEY_Q,false); await mouse(MOUSE_BUTTON_LEFT,false)
	check(game.portals.gates[0].get_instance_id() != a_id and game.portals.gates[1].get_instance_id() == b_id,"Q plus left places A while preserving B")
	check(game.portals.magic_casts == magic_count and game.magic.mode == PortalMagic.Mode.FREE,"Q release before mouse release cannot accidentally cast a dash")
	check(has_cue("link_place"),"placement exposes an animation cue")
	a_id = game.portals.gates[0].get_instance_id()
	aim(Vector3(65,7,12)); await frames(3)
	await key(KEY_Q); await mouse(MOUSE_BUTTON_RIGHT,true); await mouse(MOUSE_BUTTON_RIGHT,false); await key(KEY_Q,false)
	check(game.portals.gates[0].get_instance_id() == a_id and game.portals.gates[1].get_instance_id() != b_id,"Q plus right places B without entering cut charge")
	await tap(KEY_F7); a_id = game.portals.gates[0].get_instance_id(); b_id = game.portals.gates[1].get_instance_id()
	aim(Vector3(65,7,12)); await frames(3); await tap(KEY_G)
	check(game.portals.gates[0].get_instance_id() == a_id and game.portals.gates[1].get_instance_id() != b_id,"G redirects B while leaving the physical entrance untouched")
	b_id = game.portals.gates[1].get_instance_id(); aim(Vector3(65,200,0)); await frames(3); await tap(KEY_G)
	check(game.portals.gates[1].get_instance_id() == b_id,"invalid redirect keeps the working route")
	game.player.global_position = Vector3(100,35,10); game.player.velocity = Vector3.ZERO; aim(Vector3(100,35,-60)); await frames(2)
	await mouse(MOUSE_BUTTON_LEFT,true); await mouse(MOUSE_BUTTON_LEFT,false)
	await frames(109)
	check(game.portals.gates[0].get_instance_id() == a_id and game.portals.gates[1].get_instance_id() == b_id,"instant dash no longer replaces physical A/B")
	check(game.portals.dash_gates.size() == 2 and has_cue("passage","dash"),"dash visuals and passage animation data remain independent")
	await frames(65)
	check(game.portals.dash_gates.size() == 2 and game.portals.dash_gates[0].traversal_enabled and game.portals.gates[0] != null,"spell route persists alongside physical A/B")
	await tap(KEY_F7); aim(game.portals.gates[0].global_position); await frames(2)
	var objects: int = game.portals.object_traversals
	var projectile_damage: int = game.manager.damage_events
	await tap(KEY_T); await frames(110)
	check(game.portals.object_traversals > objects,"T throws a real rigid body through the persistent route")
	check(game.manager.damage_events > projectile_damage,"transported small projectile physically damages the destination tower")
	await capture("03-object-route")
	await tap(KEY_F7); aim(game.portals.gates[0].global_position); await frames(2)
	await tap(KEY_SHIFT); await frames(150)
	var source: Vector3 = game.player.global_position
	var traversals: int = game.portals.traversal_count
	var damage: int = game.manager.damage_events
	await tap(KEY_F)
	check(game.links.dives == 1 and game.player.global_position.distance_to(source) < 3,"F starts a physical lunge instead of teleporting to the gate")
	check(game.magic.mode == PortalMagic.Mode.FREE and game.magic.boost_speed == 0,"charged speed can be committed to a physical route")
	await frames(90)
	check(game.portals.traversal_count > traversals and has_cue("passage","physical"),"charged lunge crosses actual aperture and exposes paired animation poses")
	check(game.manager.damage_events > damage,"physical route turns charged lunge into tower impact")
	check(has_cue("dive") and has_cue("impact"),"lunge and kinetic impact feed the same presentation adapter")
	await capture("04-physical-impact")
	await tap(KEY_L); await frames(500)
	check(game.portals.gates[0].global_position.y < game.portals.gates[1].global_position.y,"action gravity loop consistently uses A as entrance and B as output")
	var loop_body: RigidBody3D = game.projectiles.back()
	metrics["loop_speed"] = loop_body.linear_velocity.length()
	check(game.portals.object_traversals >= objects + 4 and loop_body.linear_velocity.length() <= game.profile.max_portal_velocity + 0.1,"physical debris repeatedly accelerates through gravity loop under speed cap")
	var loop_a: int = game.portals.gates[0].get_instance_id()
	projectile_damage = game.manager.damage_events
	aim(Vector3(0,15,83.5)); await frames(3); await tap(KEY_G)
	metrics["loop_redirect_status"] = game.portals.status
	await frames(140)
	check(game.portals.gates[0].get_instance_id() == loop_a and game.portals.gates[1].global_position.z < 90,"G turns the existing gravity loop into an aimed exit")
	check(game.manager.damage_events > projectile_damage,"released loop projectile strikes and damages another tower")
	await capture("05-loop-release")
	await tap(KEY_F7); aim(game.portals.gates[0].global_position); await frames(2)
	var wall: StaticBody3D = game.box(Vector3(65,6,-7),Vector3(8,12,1)); await frames(2)
	traversals = game.portals.traversal_count; await tap(KEY_F); await frames(50)
	check(game.portals.traversal_count == traversals and game.player.global_position.z > -7,"ordinary blocker stops F before entry instead of being teleported through")
	wall.queue_free()
	await tap(KEY_R)
	check(not game.links.editing and game.portals.gates[0] != null,"player reset cancels editing while preserving permanent links")
	game.portals.gates[0].host.get_ref().position.x += 1; await frames(24)
	check(game.portals.gates[0] == null,"moving a supporting surface invalidates its physical gate")
	if rendered: check(game.windows.active_views == 0,"losing one physical gate stops both live windows")
	for i in 5:
		await tap(KEY_F7); await frames(8); await tap(KEY_C); await frames(8)
	check(game.portals.gates[0] == null and game.portals.gates[1] == null,"C recalls both physical portals")
	if rendered: check(game.windows.views.size() == 2 and game.windows.active_views == 0 and game.windows.windows == [null,null],"repeated rebuild/close reuses two views and leaves no window meshes")
	check(game.presentation.history.size() <= 24,"presentation telemetry is bounded")
	check(game.manager.active_debris.size() <= 48 and game.zone.active.size() <= 3,"hybrid combos keep destruction budgets")
	metrics.merge({"checks":checks,"failures":failures,"screenshots":pictures,"engine":Engine.get_version_info().string,
		"mode":"rendered_input" if rendered else "command_physics","dives":game.links.dives,"objects":game.portals.object_traversals})
	if rendered:
		var sorted: Array = game.frame_ms.duplicate(); sorted.sort()
		metrics["frames"] = sorted.size(); metrics["p95_ms"] = sorted[int(sorted.size()*0.95)]; metrics["max_ms"] = sorted.back()
		var raw := FileAccess.open("res://../docs/portal-hybrid/rendered-frames-ms.json",FileAccess.WRITE); raw.store_string(JSON.stringify(game.frame_ms)); raw.close()
	var file := FileAccess.open("res://../docs/portal-hybrid/" + ("rendered-results.json" if rendered else "headless-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("RESULT portal_hybrid ",JSON.stringify(metrics))
	game.queue_free(); await frames(8); quit(0 if failures.is_empty() else 1)
