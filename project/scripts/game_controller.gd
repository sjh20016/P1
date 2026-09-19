extends Node3D

@export var load_legacy_on_start:bool=true
var started: bool = false
var menu_open: bool = true
var run_time: float = 0.0
var resets: int = 0
var practice_mode: bool = false
var movement_model: int = 2
var course: Node3D
var consequence:Node3D
var open_zone:Node3D
var notice: String=""
var notice_time: float=0.0
@onready var player: RavagePlayer = $Player
@onready var manager: DestructionManager = $DestructionManager

func _enter_tree() -> void:
	preload("res://scripts/debug/input_setup.gd").install()
	add_to_group("session")

func _ready() -> void:
	if load_legacy_on_start: ensure_legacy_world()
	set_movement_model(2)
	for segment: DestructibleSegment in get_tree().get_nodes_in_group("destructible"):
		if segment.name==&"LaunchDeck":
			LivingInkArt.paper_mesh(segment.get_node("IntactVisual"))
		elif not segment is DestructibleBuilding and not str(segment.name).contains("Anchor"):
			LivingInkArt.apply(segment)
	player.reset_performed.connect(on_player_reset)
	player.camera_rig.rotation = Vector3(-0.07, 0, 0)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.get_cmdline_user_args().has("--smoke-test"):
		call_deferred("run_export_smoke")
	elif OS.get_cmdline_user_args().has("--open-smoke"):
		call_deferred("run_open_export_smoke")

func _process(delta: float) -> void:
	notice_time=maxf(0,notice_time-delta)
	run_time += delta
	$SweepSign.visible = not $D13.broken
	$LaunchSign.visible = not $LaunchDeck.broken

func set_movement_model(model: int) -> void:
	movement_model=clampi(model,0,2)
	for hook in player.hooks:
		hook.release()
		hook.profile=load("res://assets/placeholders/grapple_m%02d.tres" % (movement_model+1))
	notice=["M01 / 纯弹簧","M02 / 径向摆锤","M03 / 混合抓钩：爆发与持续拉力"][movement_model]
	notice_time=2.5
	var telemetry:=get_node_or_null("Telemetry")
	if telemetry: telemetry.event("model",{"model":movement_model+1})

func save_telemetry() -> void:
	var path:String=$Telemetry.save_run()
	if is_instance_valid(consequence): path=consequence.save_run()
	if is_instance_valid(open_zone): path=open_zone.save_run()
	notice="本局数据已保存" if not path.is_empty() else "保存失败"
	notice_time=3.0

func start_course() -> void:
	restart_run(load_legacy_on_start)
	course=load("res://scenes/rnd/course003.tscn").instantiate()
	add_child(course)
	course.start()

func start_consequence(which:int=0) -> void:
	restart_run(load_legacy_on_start)
	consequence=load("res://scripts/consequence/consequence_lab.gd").new()
	add_child(consequence)
	consequence.start(which)

func start_open() -> void:
	restart_run(false)
	open_zone=load("res://scripts/open/open_zone.gd").new()
	add_child(open_zone)

func next_consequence() -> void:
	start_consequence(consequence.scenario+1 if is_instance_valid(consequence) else 0)

func restart_active_run() -> void:
	if is_instance_valid(open_zone): start_open()
	elif is_instance_valid(consequence): start_consequence(consequence.scenario)
	elif is_instance_valid(course): start_course()
	else: restart_run()

func on_player_reset() -> void:
	resets += 1
	if $LaunchDeck.broken:
		$LaunchDeck.restore()

func run_export_smoke() -> void:
	begin()
	await get_tree().physics_frame
	sweep_practice()
	await get_tree().create_timer(0.9).timeout
	var success: bool = $D13.broken and player.velocity.is_finite() and manager.active_debris.size() <= 48
	print("EXPORT SMOKE fracture=", $D13.broken, " sweeps=", player.get_node("TentacleSweep").sweep_event_count)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_executable_path().get_base_dir().path_join("smoke.png"))
	player.controls_enabled = false
	for hook in player.hooks:
		hook.release()
	var tower: DestructibleBuilding = $StaticTowerForest/B250
	var bounds := tower.section_bounds[24]
	var face := tower.global_position+Vector3(bounds.get_center().x,bounds.get_center().y,bounds.end.z)
	var query := PhysicsRayQueryParameters3D.create(face+Vector3.BACK*4,face+Vector3.FORWARD*4,3,[player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var ink: InkMarks = $InkMarks
	var stamp_ok := false
	if not hit.is_empty():
		stamp_ok = ink.deposit(hit.position,hit.normal,hit.collider,0.8)
	var break_point := tower.global_transform*tower.section_bounds[25].get_center()
	var world_ok := tower.break_segment(break_point,Vector3.BACK,55)
	ink.prune()
	success = success and stamp_ok and world_ok and tower.sections[25].broken and not tower.sections[24].broken and not ink.marks.is_empty()
	print("EXPORT FULL WORLD break=",world_ok," ink=",stamp_ok)
	await get_tree().create_timer(5.5).timeout
	manager.prune()
	success = success and manager.active_debris.is_empty()
	restart_run()
	success = success and ink.marks.is_empty() and not is_instance_valid(tower.detailed)
	start_course()
	player.controls_enabled=false
	player.global_position=Vector3(0,53,-53)
	player.velocity=Vector3(0,0,-50)
	await get_tree().physics_frame
	player.controls_enabled=true
	await get_tree().create_timer(0.65).timeout
	var course_ok:bool=course.get_node("GateA").broken and player.global_position.z < -73 and player.hooks[0].profile.movement_model==2 and player.fall_recovery_enabled
	success=success and course_ok
	print("EXPORT COURSE hybrid=",movement_model==2," route_A=",course_ok)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_executable_path().get_base_dir().path_join("smoke-course.png"))
	success=await run_consequence_smoke() and success
	success=await run_open_smoke() and success
	print("EXPORT SMOKE RESULT ", "PASS" if success else "FAIL")
	get_tree().quit(0 if success else 1)

func run_consequence_smoke() -> bool:
	start_consequence()
	for i in 15: await get_tree().physics_frame
	player.camera_rig.look_at(consequence.towers[0].global_position+Vector3(0,5,8.4))
	Input.action_press("jump");Input.action_press("forward")
	var success:bool=player.hooks[0].shoot()
	var start:float=consequence.elapsed
	while consequence.elapsed-start<4 and not consequence.exit_crossed:
		if consequence.towers[0].damage_count>0 and player.hooks[0].active: player.hooks[0].release()
		await get_tree().physics_frame
	Input.action_release("jump");Input.action_release("forward")
	success=success and consequence.entry_crossed and consequence.exit_crossed
	print("EXPORT CONSEQUENCE breach=",consequence.exit_crossed," panels=",consequence.towers[0].panels.size())
	start_consequence(2);player.controls_enabled=false
	var tower=consequence.towers[1]
	var event:=RavageDamageEvent.new();event.type=RavageDamageEvent.Type.SLASH;event.energy=55;event.direction=Vector3.RIGHT
	event.position=tower.to_global(Vector3(0,0,8.4));manager.apply_damage(tower,event)
	player.global_position=consequence.to_global(Vector3(17,8,-18))
	player.camera_rig.look_at(tower.global_position+Vector3(0,-4,-8))
	while consequence.elapsed<11: await get_tree().physics_frame
	success=success and manager.secondary_events>0 and consequence.macros.active.is_empty() and not consequence.macros.ruins.is_empty()
	print("EXPORT CONSEQUENCE secondary=",manager.secondary_events," ruins=",consequence.macros.ruins.size()," active=",consequence.macros.active.size())
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_executable_path().get_base_dir().path_join("smoke-consequence.png"))
	restart_run()
	for i in 8: await get_tree().physics_frame
	return success

func run_open_export_smoke() -> void:
	var success:bool=await run_open_smoke()
	print("EXPORT OPEN RESULT ","PASS" if success else "FAIL")
	get_tree().quit(0 if success else 1)

func run_open_smoke() -> bool:
	start_open()
	while open_zone.loading: await get_tree().process_frame
	player.controls_enabled=false
	var tower=open_zone.towers[0]
	player.global_position=tower.to_global(Vector3(0,0,14))
	open_zone.update_interest(true)
	for i in 3: await get_tree().physics_frame
	player.velocity=Vector3(0,0,-60);player.controls_enabled=true
	for i in 75: await get_tree().physics_frame
	player.controls_enabled=false
	var breach:bool=tower.state.revision>=2 and tower.to_local(player.global_position).z< -10 and tower.state.boost_used
	var structural=open_zone.towers[7]
	player.global_position=structural.to_global(Vector3(-18,8,12));open_zone.update_interest(true)
	for i in 3: await get_tree().physics_frame
	var event:=RavageDamageEvent.new();event.energy=55;event.type=RavageDamageEvent.Type.SLASH;event.direction=Vector3.RIGHT
	event.position=structural.to_global(Vector3(0,-6,8.4));manager.apply_damage(structural,event)
	var deadline:float=open_zone.elapsed+12
	while open_zone.elapsed<deadline and (not open_zone.active.is_empty() or not open_zone.pending.is_empty()): await get_tree().physics_frame
	var chain:bool=open_zone.chains>0 and open_zone.towers[13].state.revision>0 and open_zone.active.is_empty() and not open_zone.ruins.is_empty()
	var signature:String=tower.state.signature()
	player.global_position=open_zone.to_global(Vector3(340,0,-300));open_zone.update_interest(true)
	for i in 3: await get_tree().physics_frame
	player.global_position=tower.to_global(Vector3(0,0,18));open_zone.update_interest(true)
	for i in 3: await get_tree().physics_frame
	var query:=PhysicsRayQueryParameters3D.create(tower.to_global(Vector3(0,0,12)),tower.to_global(Vector3(0,0,6)),3,[player.get_rid()])
	var revisit:bool=signature==tower.state.signature() and get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	print("EXPORT OPEN buildings=",open_zone.towers.size()," breach_boost=",breach," chain_ruin=",chain," revisit=",revisit)
	if DisplayServer.get_name()!="headless":
		player.global_position=structural.to_global(Vector3(-34,20,28))
		player.camera_rig.look_at(structural.global_position+Vector3(0,-4,-14))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_executable_path().get_base_dir().path_join("smoke-open.png"))
	return breach and chain and revisit

func begin() -> void:
	started = true
	menu_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_pause() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	Engine.time_scale = 1.0
	$ImpactVFX.stop_until = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	if menu_open:
		for hook in player.hooks:
			hook.release()
		if is_instance_valid(open_zone): open_zone.dual_pull.cancel()

func ensure_legacy_world() -> void:
	if $StaticTowerForest.get_child_count()>0: return
	var placeholder:Node3D=$StaticTowerForest
	remove_child(placeholder);placeholder.queue_free()
	var forest=load("res://scenes/maps/destructible_tower_forest.scn").instantiate()
	forest.name="StaticTowerForest";add_child(forest)

func unload_legacy_world() -> void:
	if $StaticTowerForest.get_child_count()==0: return
	for hook in player.hooks: hook.release()
	var forest:Node3D=$StaticTowerForest
	remove_child(forest);forest.queue_free()
	var placeholder:=Node3D.new();placeholder.name="StaticTowerForest";add_child(placeholder)

func restart_run(legacy_world:bool=true) -> void:
	if is_instance_valid(open_zone):
		remove_child(open_zone);open_zone.queue_free();open_zone=null
	if legacy_world: ensure_legacy_world()
	else: unload_legacy_world()
	player.collision_mask=3
	$StaticTowerForest.show()
	if is_instance_valid(consequence):
		consequence.scars.clear()
		consequence.macros.clear()
		remove_child(consequence);consequence.queue_free();consequence=null
	if not is_equal_approx(player.get_node("CollisionShape3D").shape.radius,0.72):
		var collider:SphereShape3D=player.get_node("CollisionShape3D").shape.duplicate()
		collider.radius=0.72;player.get_node("CollisionShape3D").shape=collider
	if is_instance_valid(course):
		remove_child(course)
		course.queue_free()
		course=null
	Engine.time_scale = 1.0
	$ImpactVFX.stop_until = 0
	manager.clear_debris()
	manager.score = 0
	manager.reset_feedback()
	manager.event_count = 0
	manager.damage_events=0;manager.secondary_events=0;manager.deepest_chain=0
	manager.last_hit_age = 100
	for building: DestructibleBuilding in get_tree().get_nodes_in_group("buildings"):
		building.restore()
	for segment: DestructibleSegment in get_tree().get_nodes_in_group("destructible"):
		if not segment.managed_by_building and not segment is DestructibleBuilding:
			segment.restore()
	player.spawn_position = Vector3(0, 48, 12)
	player.reset_player("new_run")
	# Reset releases active hooks, which can stamp their former anchors. Clear afterwards.
	$InkMarks.clear_marks()
	$Telemetry.clear_run()
	player.wall_experiment=false
	player.controls_enabled=true
	player.camera_rig.rotation = Vector3(-0.07, 0, 0)
	player.peak_speed = 0
	player.get_node("TentacleSweep").sweep_event_count = 0
	practice_mode = false
	run_time = 0
	resets = 0
	begin()

func sweep_practice() -> void:
	restart_run()
	practice_mode = true
	player.global_position = Vector3(-10, 28, -45)
	player.velocity = Vector3(35, 0, 0)
	player.camera_rig.rotation = Vector3(0.45, -0.65, 0)
	var hook: GrappleController = player.get_node("RightHook")
	hook.attach_to($PracticeAnchor.global_position, $PracticeAnchor)

func reset_position() -> void:
	player.reset_player()
	player.camera_rig.rotation = Vector3(-0.07, 0, 0)

func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
